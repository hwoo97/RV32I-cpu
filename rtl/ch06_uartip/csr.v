`timescale 1ns/1ps

// CSR file and trap control - Machine mode only (03_chapters/ch06_exception/design.md sec. 3, 4)
//  - Holds the M-mode CSRs, executes CSR instructions (csrrw/s/c and the immediate forms),
//    decides whether a trap is taken this cycle, and updates mepc/mcause/mtval/mstatus on a trap or mret
//  - The core only reports what happened in this cycle (exception flags, addresses, retire);
//    the same module is meant to be reused by the multi-cycle and pipelined cores (ch7, ch8)
//  - Trap rules (single cycle):
//      * stall = 1 (data access waiting): nothing happens, nothing is written
//      * interrupt: taken before the current instruction, only if it has no data access
//        (an APB access that has started must complete; the instruction is not executed, mepc = pc)
//      * exception: the instruction does not complete (the core blocks rd / memory writes using trap)
//      * priority (design.md 4.1): fetch fault > illegal > ebreak/ecall > jump target misaligned
//        > load/store misaligned > load/store access fault; interrupts: external > timer
//  - CSR access that does not exist, or a write to a read-only CSR, is an illegal instruction
//  - tselect/tdata1/tdata2 exist as read-only-zero (no debug triggers); PMP CSRs do not exist (ch12)
//  - Counters: mcycle counts every clock, minstret counts completed instructions; a CSR write wins
//    over the increment in the same cycle
module csr (
    input             clk,
    input             rst_n,
    // instruction of this cycle
    input      [31:0] pc,
    input      [31:0] inst,
    input             stall,            // data port wait: no state change this cycle
    input             mem_op,           // this instruction accesses the data port (interrupts wait)
    // CSR instruction
    input             csr_en,           // decoded csrrw/s/c(i)
    input      [31:0] csr_src,          // rs1 value, or zero-extended uimm for the immediate forms
    output reg [31:0] csr_rdata,        // old CSR value -> rd
    // exceptions found by the core in this cycle
    input             exc_fetch_fault,  // fetch address outside IMEM
    input             exc_illegal,      // illegal instruction from the decoder
    input             exc_ecall,
    input             exc_ebreak,
    input             exc_jmp_misalign, // taken jump/branch target not 4-byte aligned
    input      [31:0] jmp_target,
    input             exc_ld_misalign,
    input             exc_st_misalign,
    input             exc_ld_fault,     // load access fault (decoder data_err)
    input             exc_st_fault,     // store access fault
    input      [31:0] mem_addr,
    input             is_mret,
    // interrupt requests (already synchronized)
    input             irq_timer,        // -> mip.MTIP
    input             irq_ext,          // -> mip.MEIP
    // results
    output            trap,             // 1 = take a trap this cycle: next pc = trap_pc
    output            trap_is_irq,      // the trap is an interrupt
    output            exc_taken,        // the trap is an exception
    output     [31:0] trap_pc,          // mtvec
    output            mret_take,        // 1 = mret completes this cycle: next pc = mepc
    output     [31:0] mepc_pc,
    output            retire            // instruction completes this cycle (counts minstret)
);
    // -- CSR addresses --
    localparam [11:0] A_MSTATUS  = 12'h300, A_MISA     = 12'h301, A_MIE      = 12'h304,
                      A_MTVEC    = 12'h305, A_MCOUNTIN = 12'h320, A_MSCRATCH = 12'h340,
                      A_MEPC     = 12'h341, A_MCAUSE   = 12'h342, A_MTVAL    = 12'h343,
                      A_MIP      = 12'h344,
                      A_MCYCLE   = 12'hB00, A_MINSTRET = 12'hB02,
                      A_MCYCLEH  = 12'hB80, A_MINSTRETH= 12'hB82,
                      A_CYCLE    = 12'hC00, A_INSTRET  = 12'hC02,
                      A_CYCLEH   = 12'hC80, A_INSTRETH = 12'hC82,
                      A_MVENDOR  = 12'hF11, A_MARCHID  = 12'hF12, A_MIMPID   = 12'hF13,
                      A_MHARTID  = 12'hF14,
                      A_TSELECT  = 12'h7A0, A_TDATA1   = 12'h7A1, A_TDATA2   = 12'h7A2;

    // -- State --
    reg        mstatus_mie, mstatus_mpie;
    reg        mie_meie, mie_mtie, mie_msie;
    reg [31:2] mtvec_base;
    reg [31:0] mscratch, mtval;
    reg [31:2] mepc;
    reg        mcause_int;
    reg [4:0]  mcause_code;
    reg [63:0] mcycle, minstret;

    wire [31:0] mstatus = {19'd0, 2'b11, 3'd0, mstatus_mpie, 3'd0, mstatus_mie, 3'd0};   // MPP = M
    wire [31:0] mip     = {20'd0, irq_ext, 3'd0, irq_timer, 3'd0, 1'b0, 3'd0};          // MEIP, MTIP
    wire [31:0] mie     = {20'd0, mie_meie, 3'd0, mie_mtie, 3'd0, mie_msie, 3'd0};
    localparam [31:0] MISA = 32'h4000_0100;                                            // RV32, I

    // -- CSR instruction fields --
    wire [11:0] addr  = inst[31:20];
    wire [1:0]  op    = inst[13:12];      // 01 RW, 10 RS, 11 RC
    wire        src0  = (inst[19:15] == 5'd0);   // rs1 = x0 / uimm = 0
    wire        wr_intent = csr_en & ((op == 2'b01) | !src0);   // csrrs/c with x0 do not write
    wire        read_only = (addr[11:10] == 2'b11);

    // -- Read --
    reg exists;
    always @(*) begin
        exists    = 1'b1;
        csr_rdata = 32'd0;
        case (addr)
            A_MSTATUS:               csr_rdata = mstatus;
            A_MISA:                  csr_rdata = MISA;
            A_MIE:                   csr_rdata = mie;
            A_MTVEC:                 csr_rdata = {mtvec_base, 2'b00};   // MODE 0 = direct
            A_MCOUNTIN:              csr_rdata = 32'd0;                  // counters never inhibited
            A_MSCRATCH:              csr_rdata = mscratch;
            A_MEPC:                  csr_rdata = {mepc, 2'b00};
            A_MCAUSE:                csr_rdata = {mcause_int, 26'd0, mcause_code};
            A_MTVAL:                 csr_rdata = mtval;
            A_MIP:                   csr_rdata = mip;
            A_MCYCLE,   A_CYCLE:     csr_rdata = mcycle[31:0];
            A_MCYCLEH,  A_CYCLEH:    csr_rdata = mcycle[63:32];
            A_MINSTRET, A_INSTRET:   csr_rdata = minstret[31:0];
            A_MINSTRETH,A_INSTRETH:  csr_rdata = minstret[63:32];
            A_MVENDOR, A_MARCHID, A_MIMPID, A_MHARTID: csr_rdata = 32'd0;
            // no debug triggers: tselect/tdata read 0, writes ignored (software sees that no trigger exists)
            A_TSELECT, A_TDATA1, A_TDATA2:             csr_rdata = 32'd0;
            default:                 exists = 1'b0;
        endcase
    end

    // new value for read-modify-write
    reg [31:0] wval;
    always @(*) begin
        case (op)
            2'b10:   wval = csr_rdata | csr_src;     // set
            2'b11:   wval = csr_rdata & ~csr_src;    // clear
            default: wval = csr_src;                 // write
        endcase
    end

    wire exc_csr = csr_en & (!exists | (wr_intent & read_only));

    // -- Trap decision --
    wire irq_e      = mstatus_mie & mie_meie & irq_ext;
    wire irq_t      = mstatus_mie & mie_mtie & irq_timer;
    assign trap_is_irq = (irq_e | irq_t) & ~stall & ~mem_op;

    wire any_exc = exc_fetch_fault | exc_illegal | exc_csr | exc_ecall | exc_ebreak | exc_jmp_misalign |
                   exc_ld_misalign | exc_st_misalign | exc_ld_fault | exc_st_fault;
    assign exc_taken = any_exc & ~stall & ~trap_is_irq;
    assign trap      = trap_is_irq | exc_taken;
    assign trap_pc   = {mtvec_base, 2'b00};

    reg [4:0]  cause;
    reg [31:0] tval;
    always @(*) begin
        tval = 32'd0;
        if      (irq_e)                    cause = 5'd11;
        else if (irq_t)                    cause = 5'd7;
        else if (exc_fetch_fault)  begin   cause = 5'd1;  tval = pc;   end
        else if (exc_illegal | exc_csr) begin cause = 5'd2; tval = inst; end
        else if (exc_ebreak)               cause = 5'd3;
        else if (exc_ecall)                cause = 5'd11;
        else if (exc_jmp_misalign) begin   cause = 5'd0;  tval = jmp_target; end
        else if (exc_ld_misalign)  begin   cause = 5'd4;  tval = mem_addr; end
        else if (exc_st_misalign)  begin   cause = 5'd6;  tval = mem_addr; end
        else if (exc_ld_fault)     begin   cause = 5'd5;  tval = mem_addr; end
        else                       begin   cause = 5'd7;  tval = mem_addr; end   // store access fault
    end

    assign mret_take = is_mret & ~stall & ~trap;
    assign mepc_pc   = {mepc, 2'b00};
    assign retire    = ~stall & ~trap;            // the instruction of this cycle completes
    wire   csr_write = wr_intent & retire;        // retire already excludes illegal CSR accesses

    // -- State update --
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mie_meie <= 1'b0; mie_mtie <= 1'b0; mie_msie <= 1'b0;
            mtvec_base   <= 30'd0;
            mscratch     <= 32'd0;
            mepc         <= 30'd0;
            mcause_int   <= 1'b0;
            mcause_code  <= 5'd0;
            mtval        <= 32'd0;
            mcycle       <= 64'd0;
            minstret     <= 64'd0;
        end else begin
            // counters: a CSR write to either half replaces the increment of the whole counter
            if (csr_write && (addr == A_MCYCLE || addr == A_MCYCLEH))
                mcycle <= {(addr == A_MCYCLEH) ? wval : mcycle[63:32],
                           (addr == A_MCYCLE)  ? wval : mcycle[31:0]};
            else
                mcycle <= mcycle + 64'd1;
            if (csr_write && (addr == A_MINSTRET || addr == A_MINSTRETH))
                minstret <= {(addr == A_MINSTRETH) ? wval : minstret[63:32],
                             (addr == A_MINSTRET)  ? wval : minstret[31:0]};
            else if (retire)
                minstret <= minstret + 64'd1;

            if (trap) begin
                mepc         <= pc[31:2];
                mcause_int   <= trap_is_irq;
                mcause_code  <= cause;
                mtval        <= tval;
                mstatus_mpie <= mstatus_mie;
                mstatus_mie  <= 1'b0;
            end else if (mret_take) begin
                mstatus_mie  <= mstatus_mpie;
                mstatus_mpie <= 1'b1;
            end else if (csr_write) begin
                case (addr)
                    A_MSTATUS:   begin mstatus_mie <= wval[3]; mstatus_mpie <= wval[7]; end
                    A_MIE:       begin mie_meie <= wval[11]; mie_mtie <= wval[7]; mie_msie <= wval[3]; end
                    A_MTVEC:     mtvec_base <= wval[31:2];
                    A_MSCRATCH:  mscratch   <= wval;
                    A_MEPC:      mepc       <= wval[31:2];
                    A_MCAUSE:    begin mcause_int <= wval[31]; mcause_code <= wval[4:0]; end
                    A_MTVAL:     mtval      <= wval;
                    default: ;   // counters: above; misa, mip, mcountinhibit, tselect/tdata: writes ignored
                endcase
            end
        end
    end
endmodule
