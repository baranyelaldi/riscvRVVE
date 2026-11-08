# Input for jacobi_1d_scalar.c — same 16 elements as tests/jacobi_1d_selfcheck.s.
.section .rodata
.balign 4
.global jac_A
.global jac_n
jac_A:
    .word  10,  20,  30,  40,  50,  60,  70,  80
    .word  90, 100, 110, 120, 130, 140, 150, 160
jac_n:
    .word 16
