# Path classes of rv32i_chip for report_path_groups (syn/common/path_groups.tcl)
# Writes ./report/21_rv32i_chip_path_classes.rpt (run from the run folder, after syn_opt or read_db)
#   1 instruction pins -> register file     : IMEM_DATA -> in pad -> decode/regfile/ALU -> ... -> regs
#   2 memory data pins -> register file     : RAM_RDATA / IROM_DATA -> in pad -> decoder mux -> lsu -> regs
#   3 instruction pins -> data address pins : IMEM_DATA -> in pad -> ... -> out pad -> DADDR
#   4 flop -> flop (inside the chip)
#   5 flop -> instruction address pins      : pc -> out pad -> IMEM_ADDR
#   6 flop -> data address / write pins     : flops -> out pad -> DADDR / RAM_WDATA
#   7 to the DMEM write pins                 : -> RAM_WSTRB / RAM_WDATA
file mkdir report
report_path_groups report/21_rv32i_chip_path_classes.rpt \
    {in_imem_to_reg   {[get_ports {IMEM_DATA[*]}]}                  {[all_registers]}} \
    {in_mem_to_reg    {[get_ports {RAM_RDATA[*] IROM_DATA[*]}]}     {[all_registers]}} \
    {in_imem_to_addr  {[get_ports {IMEM_DATA[*]}]}                  {[get_ports {DADDR[*]}]}} \
    {reg_to_reg       {[all_registers]}                             {[all_registers]}} \
    {reg_to_imem_addr {[all_registers]}                             {[get_ports {IMEM_ADDR[*]}]}} \
    {reg_to_mem_out   {[all_registers]}                             {[get_ports {DADDR[*] RAM_WDATA[*]}]}} \
    {to_mem_write     -                                             {[get_ports {RAM_WSTRB[*] RAM_WDATA[*]}]}}
