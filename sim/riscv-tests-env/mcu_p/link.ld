/* Linker script for riscv-tests (env mcu_p, original environment) on the ch6 MCU
   Memory regions come from fw/common/memmap.ld (generated from fw/common/memmap.txt):
     IMEM 0x0000_0000 16 KB : .text.init, .text, .rodata, and the load image of .data
     DMEM 0x1000_0000 16 KB : .data (copied at start by COPY_DATA in riscv_test.h), .bss
     TOHOST (last 16 bytes of DMEM) : .tohost (tohost, fromhost) - not loaded, watched by the testbench */
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
  .tohost TOHOST_BASE (NOLOAD) : { *(.tohost) }
  ASSERT(_end <= TOHOST_BASE, "data reaches the TOHOST words at the end of DMEM")
  ASSERT(SIZEOF(.tohost) <= TOHOST_SIZE, ".tohost does not fit in the TOHOST area")
}
