// Startup code for C firmware on the stage 4 MCU (03_chapters/ch14a_mcu/design.md sec. 6)
//  1. gp = __global_pointer$, sp = end of DMEM
//  2. copy .data from its load image in IMEM to DMEM (word loads through the data-side IMEM port)
//  3. clear .bss
//  4. call main(); its return value goes to fw_exit() (sys.c), which never returns
// No interrupts or traps yet (stage 5, ch6).

    .section .text.init, "ax"
    .globl _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, _stack_top

    // copy .data: t0 = source (IMEM), t1 = destination (DMEM), t2 = end
    la      t0, _data_lma
    la      t1, _data_start
    la      t2, _data_end
1:  bgeu    t1, t2, 2f
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       1b
2:
    // clear .bss
    la      t1, _bss_start
    la      t2, _bss_end
3:  bgeu    t1, t2, 4f
    sw      zero, 0(t1)
    addi    t1, t1, 4
    j       3b
4:
    li      a0, 0           // argc = 0
    li      a1, 0           // argv = NULL
    call    main
    call    fw_exit         // a0 = return value of main
5:  j       5b
