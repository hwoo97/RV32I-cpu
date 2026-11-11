/* Linker script for riscv-tests on the stage 4 MCU
   Memory regions come from fw/common/memmap.ld (generated from fw/common/memmap.txt):
     IMEM 0x0000_0000 16 KB : .text.init, .text, and the load image of .data
     DMEM 0x1000_0000 16 KB : .data (copied at start by COPY_DATA in riscv_test.h), .bss
                              (the TOHOST words at the end of DMEM stay free) */
INCLUDE memmap.ld
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  .text.init : { *(.text.init) } > IMEM
  .text      : { *(.text) *(.text.*) } > IMEM
  .rodata    : { *(.rodata) *(.rodata.*) } > IMEM
  .data      : ALIGN(4) { _data_start = .; *(.data) *(.data.*) *(.sdata) *(.sdata.*) . = ALIGN(4); _data_end = .; } > DMEM AT > IMEM
  _data_lma = LOADADDR(.data);
  .bss       : ALIGN(4) { *(.bss) *(.bss.*) *(.sbss) *(.sbss.*) } > DMEM
  _end = .;
  ASSERT(_end <= TOHOST_BASE, "data reaches the TOHOST words at the end of DMEM")
}
