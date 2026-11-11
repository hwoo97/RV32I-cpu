# Path classes of rv32i_mcu for report_path_groups (syn/common/path_groups.tcl)
# Writes ./report/21_rv32i_mcu_path_classes.rpt (run from the run folder, after syn_opt or read_db)
#   1 instruction in -> register file     : imem_rdata -> decode/regfile/ALU -> ... -> regs
#   2 memory data in -> register file     : ram_rdata / irom_rdata -> decoder mux -> lsu -> regs
#   3 external APB in -> register file    : apbx_prdata / pready / pslverr -> bridge -> decoder -> core
#   4 instruction in -> memory address out: imem_rdata -> ... -> ram_addr / irom_addr / apbx_*
#   5 flop -> flop (inside the MCU)       : includes the internal APB peripherals
#   6 flop -> instruction address out     : pc -> imem_addr
#   7 flop -> memory address / data out   : flops -> ram_* / irom_addr / apbx_*
#   8 to the DMEM write strobe / data      : -> ram_wstrb / ram_wdata
file mkdir report
report_path_groups report/21_rv32i_mcu_path_classes.rpt \
    {in_imem_to_reg   {[get_ports {imem_rdata[*]}]}                         {[all_registers]}} \
    {in_mem_to_reg    {[get_ports {ram_rdata[*] irom_rdata[*]}]}            {[all_registers]}} \
    {in_apbx_to_reg   {[get_ports {apbx_prdata[*] apbx_pready apbx_pslverr}]} {[all_registers]}} \
    {in_imem_to_addr  {[get_ports {imem_rdata[*]}]}                         {[get_ports {ram_addr[*] irom_addr[*] apbx_psel apbx_paddr[*]}]}} \
    {reg_to_reg       {[all_registers]}                                     {[all_registers]}} \
    {reg_to_imem_addr {[all_registers]}                                     {[get_ports {imem_addr[*]}]}} \
    {reg_to_mem_out   {[all_registers]}                                     {[get_ports {ram_addr[*] irom_addr[*] ram_wdata[*] apbx_*}]}} \
    {to_mem_write     -                                                     {[get_ports {ram_wstrb[*] ram_wdata[*]}]}}
