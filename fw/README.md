# fw — MCU 펌웨어 (4단계부터)

C 펌웨어와 그 빌드 환경. 시뮬레이션·FPGA·이후 장(6~13장)에서 같이 쓴다. 설계는 [03_chapters/ch14a_mcu/design.md](../03_chapters/ch14a_mcu/design.md) 6절.

| 위치 | 내용 |
|------|------|
| `common/memmap.txt` | **주소 표 (모든 주소의 원본)** — 고친 뒤 `python tools/gen_memmap.py` |
| `common/memmap.h`, `common/memmap.ld` | 주소 표에서 만든 파일 (직접 고치지 않음) |
| `common/` (예정) | crt0, 링커 스크립트, `mcu.h`, uart, printf |
| `<프로그램>/` (예정) | hello, gpio_blink … |

## 주소를 바꿀 때
1. `common/memmap.txt` 수정
2. 이 PC에서 `python tools/gen_memmap.py` → 아래 세 파일이 함께 바뀐다
   - `rtl/ch14a_mcu/mcu_memmap.vh` (주소 디코더용 Verilog `` `define``)
   - `fw/common/memmap.h` (C·어셈블리 `#define`)
   - `fw/common/memmap.ld` (링커 `MEMORY`)
3. 세 파일을 같이 커밋 (학교 서버에는 Python 실행이 필요 없음)
- 커밋 전에 `python tools/gen_memmap.py --check`로 생성 파일이 표와 맞는지 확인할 수 있다
- 스크립트가 표를 점검한다: 이름 중복, 크기(2의 거듭제곱), 정렬(시작 주소 = 크기의 배수), 영역 겹침, APB 창 밖 주변장치, APB 슬롯 중복
