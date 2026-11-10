#####################################################################
# rv32i_core 타이밍 제약 (ch05 단일 사이클)
#  - CLK_PERIOD는 genus.tcl에서 정한다 (run_syn.sh 인자, 기본 10 ns)
#  - 메모리는 코어 바깥에 있어서, 메모리 접근 시간을 입출력 지연으로 나눠 준다 (README 2절 그림)
#
#   한 사이클에 일어나는 일 (단일 사이클):
#   pc(플롭) ─▶ imem_addr ─[imem 읽기 T_MEM]─▶ imem_rdata ─▶ 해독·레지스터·ALU ─▶ dmem_addr
#            ─[dmem 읽기 T_MEM]─▶ dmem_rdata ─▶ lsu 확장·WB MUX ─▶ 레지스터 파일(플롭)
#
#   T_ADDR : pc 플롭 → imem_addr 포트에 허용하는 시간
#   T_MEM  : 메모리 읽기 시간 (가정값, 45nm 8 KB SRAM 수준)
#   T_WB   : dmem_rdata 포트 → 레지스터 파일 입력에 허용하는 시간
#####################################################################

set T_ADDR 0.5
set T_MEM  1.0
set T_WB   1.0
set T_WSU  0.3     ;# dmem 쓰기 셋업 (쓰기는 다음 클럭 에지에 일어남)

create_clock -name clk -period $CLK_PERIOD [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_clock_transition  0.05 [get_clocks clk]

# 명령어 메모리: pc는 T_ADDR 안에 포트에 나가고, 명령어는 T_ADDR + T_MEM 뒤에 들어온다
set_output_delay [expr {$CLK_PERIOD - $T_ADDR}]  -clock clk [get_ports {imem_addr[*]}]
set_input_delay  [expr {$T_ADDR + $T_MEM}]       -clock clk [get_ports {imem_rdata[*]}]

# 데이터 메모리 읽기: dmem_addr 뒤에 T_MEM(읽기) + T_WB(WB 경로)가 남아 있어야 한다
set_output_delay [expr {$T_MEM + $T_WB}]         -clock clk [get_ports {dmem_addr[*] dmem_re}]
set_input_delay  [expr {$CLK_PERIOD - $T_WB}]    -clock clk [get_ports {dmem_rdata[*]}]

# 데이터 메모리 쓰기: 다음 에지 T_WSU 전까지
set_output_delay $T_WSU                          -clock clk [get_ports {dmem_wstrb[*] dmem_wdata[*]}]

# 관찰용 출력
set_output_delay 0.0                             -clock clk [get_ports {dbg_pc[*] trap}]

# 비동기 리셋은 타이밍 분석에서 뺀다
set_false_path -from [get_ports rst_n]

# 입력 신호 전이 시간·출력 부하
set_input_transition 0.1 [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.01 [all_outputs]
