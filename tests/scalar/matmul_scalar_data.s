# Input for matmul_scalar.c — same matrices as tests/matmul_selfcheck.s
# (N=4): A = 1..16 row-major; B = A^T stored column-major (same pattern).
.section .rodata
.balign 4
.global mm4_A
.global mm4_B
.global mm4_n
mm4_A:
    .word  1,  2,  3,  4,  5,  6,  7,  8
    .word  9, 10, 11, 12, 13, 14, 15, 16
mm4_B:
    .word  1,  2,  3,  4,  5,  6,  7,  8
    .word  9, 10, 11, 12, 13, 14, 15, 16
mm4_n:
    .word 4
