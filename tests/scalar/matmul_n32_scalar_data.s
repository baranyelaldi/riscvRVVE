# Input data for matmul_n32_scalar.c — same matrices as tests/matmul_n32.s:
#   A[i][j] = i+1 (row-major); B = A^T stored column-major, which has the
#   same byte pattern, so column j of B is contiguous like row j of A.
# Kept in assembly so the compiler cannot see the values and constant-fold.
.section .rodata
.balign 4
.global mm_A
.global mm_B
mm_A:
    .set row, 1
    .rept 32
    .fill 32, 4, row
    .set row, row + 1
    .endr
mm_B:
    .set row, 1
    .rept 32
    .fill 32, 4, row
    .set row, row + 1
    .endr
