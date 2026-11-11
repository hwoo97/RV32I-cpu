/* Linker script for the minimal test environment - stage 3 RV32I single-cycle CPU memory map
   imem and dmem 8 KB each, reset PC = 0. The same image is loaded into both memories.
   0x0000  .text.init  (test code)
   0x1000  .tohost     (result address)
   0x1040~ .data .bss  (test data) - everything must fit below 0x2000 (8 KB) */
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
