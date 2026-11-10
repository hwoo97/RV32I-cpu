/* 최소 테스트 환경 링커 스크립트 — 3단계 RV32I 단일 사이클 CPU 메모리 맵
   imem·dmem 각각 8 KB, 리셋 PC = 0. 같은 이미지를 두 메모리에 모두 읽어 들인다.
   0x0000  .text.init  (테스트 코드)
   0x1000  .tohost     (판정 주소)
   0x1040~ .data .bss  (테스트 데이터) — 모두 0x2000(8 KB) 안에 들어가야 한다 */
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  .text      : { *(.text) }
  . = ALIGN(0x1000);
  .tohost    : { *(.tohost) }
  . = ALIGN(0x40);
  .data      : { *(.data) }
  .bss       : { *(.bss) }
  _end = .;
  ASSERT(tohost == 0x1000, "tohost must be at 0x1000 (code larger than 4 KB?)")
  ASSERT(_end <= 0x2000, "image larger than 8 KB")
}
