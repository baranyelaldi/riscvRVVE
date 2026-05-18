.text
.global _start
_start:
    la      t0, data_A              # A base (row-major)
    la      t1, data_B              # B base (column-major)
    li      t2, 0x4000              # C base in TCM

    # Zero accumulator for vredsum
    vmv.v.x v0, x0                  # v0 = {0, 0, 0, 0}

    li      a2, 0                   # i = 0  (row counter)
    li      a3, 4                   # row/col limit

row_loop:
    vle32.v v1, (t0)                # v1 = A[i][*]
    mv      a4, t1                  # a4 = B base (reset each row)
    li      a5, 0                   # j = 0

col_loop:
    vle32.v v2, (a4)                # v2 = B[*][j] (contiguous in column-major)
    vmul.vv     v3, v1, v2          # v3[k] = A[i][k] * B[k][j]
    vredsum.vs  v4, v3, v0          # v4[0] = sum of v3
    vmv.x.s     a1, v4              # vmv.x.s a1, v4
    sw      a1, 0(t2)               # C[i][j] = a1

    addi    a4, a4, 16              # next B column
    addi    t2, t2, 4               # next C element
    addi    a5, a5, 1
    blt     a5, a3, col_loop

    addi    t0, t0, 16              # next A row
    addi    a2, a2, 1
    blt     a2, a3, row_loop

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

.balign 4
data_A:                             # row-major 4×4
    .word 1, 2, 3, 4
    .word 5, 6, 7, 8
    .word 9, 10, 11, 12
    .word 13, 14, 15, 16

.balign 4
data_B:                             # column-major 4×4 (= A^T for this test)
    .word 1, 5,  9, 13              # B col 0
    .word 2, 6, 10, 14              # B col 1
    .word 3, 7, 11, 15              # B col 2
    .word 4, 8, 12, 16              # B col 3
