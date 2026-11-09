# 테스트벤치 규칙
> 목적: 모든 장의 테스트를 같은 방식으로 실행하고, 사람이 파형을 보지 않아도 PASS/FAIL이 나오게 한다.

## 1. 파일 위치·이름
| 구분 | 위치 | 이름 |
|------|------|------|
| 설계 | `rtl/chNN_<주제>/` | `<모듈>.v` |
| 테스트벤치 | `sim/chNN_<주제>/` | `<모듈>_tb.v`, 최상위 모듈 이름도 `<모듈>_tb` |
| 메모리 초기화 | `sim/chNN_<주제>/` | `<프로그램>.hex` (GCC·RARS로 생성), 어셈블리 원본 `<프로그램>.S` |

## 2. 작성 규칙
1. 설계·테스트벤치 모두 첫 줄에 `` `timescale 1ns/1ps ``
2. **기댓값을 코드로 비교**한다. 틀리면 `$display("FAIL: ...")`로 무엇이 틀렸는지(신호, 기댓값, 실제값) 출력
3. 모든 비교가 끝나면 오류가 없을 때만 `$display("PASS")`, 그 뒤 `$finish`
4. **타임아웃**: 일정 시간 안에 끝나지 않으면 `FAIL: timeout`을 출력하고 끝낸다 (CPU 무한 루프 대비)
5. 조합 회로는 가능한 입력을 전부 또는 무작위로 많이 넣고, 기준 모델(예: `a + b`)과 비교
6. CPU는 riscv-tests처럼 프로그램이 스스로 결과를 판정하게 한다 (`tohost` 주소에 1이면 PASS, 그 밖의 값이면 실패한 테스트 번호). 직접 만든 프로그램은 RARS로 실행해 레지스터·메모리 최종 값을 기댓값으로 삼는다

## 3. 기본 틀 (직접 입력할 때 참고)
```verilog
`timescale 1ns/1ps
module xxx_tb;
    reg clk = 0;
    always #5 clk = ~clk;          // 100 MHz

    integer errors = 0;
    task check(input [31:0] actual, input [31:0] expected, input [8*16:1] name);
        if (actual !== expected) begin
            $display("FAIL: %0s = %h (expected %h) at %0t", name, actual, expected, $time);
            errors = errors + 1;
        end
    endtask

    // dut 연결

    initial begin
        // 자극 넣기 + check(...) 호출
        if (errors == 0) $display("PASS");
        $finish;
    end

    initial begin
        #100000 $display("FAIL: timeout");
        $finish;
    end
endmodule
```

## 4. 실행
- 주 시뮬레이터 (Linux 서버, Xcelium) — 판정 스크립트는 [xcelium](../xcelium/README.md)에서 만든다
```bash
xrun -64bit rtl/chNN_<주제>/xxx.v sim/chNN_<주제>/xxx_tb.v
```
- 보조 (이 PC, xsim)
```bash
python sim/run_sim.py xxx_tb rtl/chNN_<주제>/xxx.v sim/chNN_<주제>/xxx_tb.v
```
- 테스트벤치는 두 시뮬레이터에서 모두 돌도록 Verilog-2005 범위로 작성한다
- 결과 파일은 `sim/build/`에 생기며 커밋하지 않는다.
