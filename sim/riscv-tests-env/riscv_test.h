// riscv-tests용 최소 테스트 환경 — CSR·트랩이 없는 3단계 RV32I 단일 사이클 CPU 전용
// riscv-tests 기본 환경(env/p/riscv_test.h)은 시작할 때 CSR(mtvec·mstatus 등)과 mret을 쓰고,
// PASS 때 ecall을 쓴다. 이 CPU는 아직 이것들이 없어서, 같은 매크로 이름으로 단순한 동작만 정의한다.
//  - 시작: 레지스터 x1~x31을 0으로 채우고 바로 테스트로 들어간다
//  - 판정: tohost 주소에 값을 쓰고 제자리 루프 (1 = PASS, (실패한 테스트 번호 << 1) | 1 = FAIL)
//  - 테스트벤치가 tohost 쓰기를 감시해 판정한다
// 6장(CSR·트랩)을 구현하면 riscv-tests 기본 환경(env/p)으로 다시 확인한다.
#ifndef _ENV_RV32I_MINIMAL_H
#define _ENV_RV32I_MINIMAL_H

#define TESTNUM gp

#define RVTEST_RV32U  .macro init; .endm
#define RVTEST_RV64U  RVTEST_RV32U

#define INIT_XREG                                               \
  li x1, 0;  li x2, 0;  li x3, 0;  li x4, 0;  li x5, 0;         \
  li x6, 0;  li x7, 0;  li x8, 0;  li x9, 0;  li x10, 0;        \
  li x11, 0; li x12, 0; li x13, 0; li x14, 0; li x15, 0;        \
  li x16, 0; li x17, 0; li x18, 0; li x19, 0; li x20, 0;        \
  li x21, 0; li x22, 0; li x23, 0; li x24, 0; li x25, 0;        \
  li x26, 0; li x27, 0; li x28, 0; li x29, 0; li x30, 0;        \
  li x31, 0;

#define RVTEST_CODE_BEGIN                                       \
        .section .text.init;                                    \
        .align  6;                                              \
        .globl _start;                                          \
_start:                                                         \
        INIT_XREG;                                              \
        init;

#define RVTEST_CODE_END                                         \
1:      j 1b;

#define RVTEST_PASS                                             \
        fence;                                                  \
        li TESTNUM, 1;                                          \
        la t5, tohost;                                          \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define RVTEST_FAIL                                             \
        fence;                                                  \
1:      beqz TESTNUM, 1b;                                       \
        sll TESTNUM, TESTNUM, 1;                                \
        or TESTNUM, TESTNUM, 1;                                 \
        la t5, tohost;                                          \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                       \
        EXTRA_DATA                                              \
        .pushsection .tohost,"aw",@progbits;                    \
        .align 6; .global tohost; tohost: .word 0; .word 0;     \
        .align 6; .global fromhost; fromhost: .word 0; .word 0; \
        .popsection;                                            \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
