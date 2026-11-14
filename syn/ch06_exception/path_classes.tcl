# Path classes of rv32i_mcu for report_path_groups (syn/common/path_groups.tcl)
# Writes ./report/21_rv32i_mcu_path_classes.rpt (run from the run folder, after syn_opt or read_db)
#   1 instruction in -> register file     : imem_rdata -> decode/regfile/ALU -> ... -> regs
#   2 memory data in -> register file     : ram_rdata / irom_rdata -> decoder mux -> lsu -> regs
#   3 instruction in -> memory address out: imem_rdata -> ... -> ram_addr / irom_addr
#   4 flop -> flop (inside the MCU)       : includes the internal APB peripherals
#   5 flop -> instruction address out     : pc -> imem_addr
#   6 flop -> memory address / data out   : flops -> ram_addr / irom_addr / ram_wdata
#   7 to the DMEM write strobe / data      : -> ram_wstrb / ram_wdata
file mkdir report
report_path_groups report/21_rv32i_mcu_path_classes.rpt \
    {in_imem_to_reg   {[get_ports {imem_rdata[*]}]}                         {[all_registers]}} \
    {in_mem_to_reg    {[get_ports {ram_rdata[*] irom_rdata[*]}]}            {[all_registers]}} \
    {in_imem_to_addr  {[get_ports {imem_rdata[*]}]}                         {[get_ports {ram_addr[*] irom_addr[*]}]}} \
    {reg_to_reg       {[all_registers]}                                     {[all_registers]}} \
    {reg_to_imem_addr {[all_registers]}                                     {[get_ports {imem_addr[*]}]}} \
    {reg_to_mem_out   {[all_registers]}                                     {[get_ports {ram_addr[*] irom_addr[*] ram_wdata[*]}]}} \
    {to_mem_write     -                                                     {[get_ports {ram_wstrb[*] ram_wdata[*]}]}}
