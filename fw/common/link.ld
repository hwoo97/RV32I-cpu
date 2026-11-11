/* Linker script for C firmware on the stage 4 MCU (03_chapters/ch14a_mcu/design.md sec. 6)
   Memory regions come from memmap.ld (generated from memmap.txt by tools/gen_memmap.py):
     IMEM : .text.init (crt0), .text, .rodata, and the load image of .data
     DMEM : .data (copied by crt0), .bss (cleared by crt0), stack (grows down from TOHOST,
            the result words at the end of DMEM watched by the simulation testbench)
   Constants in .rodata stay in IMEM and are read through the data-side IMEM port (irom_*). */
INCLUDE memmap.ld
OUTPUT_ARCH( "riscv" )
ENTRY(_start)

STACK_MIN = 1024;   /* bytes that must stay free for the stack (link-time check only) */

SECTIONS
{
  .text : ALIGN(4)
  {
    KEEP(*(.text.init))
    *(.text .text.*)
    . = ALIGN(4);
  } > IMEM

  .rodata : ALIGN(4)
  {
    *(.rodata .rodata.*)
    *(.srodata .srodata.*)
    . = ALIGN(4);
  } > IMEM

  .data : ALIGN(4)
  {
    _data_start = .;
    *(.data .data.*)
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
    . = ALIGN(4);
    _data_end = .;
  } > DMEM AT > IMEM
  _data_lma = LOADADDR(.data);

  .bss (NOLOAD) : ALIGN(4)
  {
    _bss_start = .;
    *(.sbss .sbss.*)
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > DMEM

  _end = .;
  _stack_top = TOHOST_BASE;

  ASSERT(_end + STACK_MIN <= _stack_top, "DMEM full: .data + .bss leave less than STACK_MIN for the stack")

  /DISCARD/ : { *(.comment) *(.note .note.*) *(.eh_frame) }
}
