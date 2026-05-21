.text
.global _start
_start:
    # ===========================================================
    # Setup
    # ===========================================================
    la      a0, data_A          # A base (row-major)
    la      a1, data_B          # B base (column-major)
    li      a2, 0x4000          # C base in TCM (row-major output)
    li      a3, 8               # N = matrix size

    li      t0, 0               # i = 0 (outer row counter)

# ===========================================================
# OUTER LOOP — iterate rows of A and C
# ===========================================================
row_loop:
    li      t1, 0               # j = 0 (outer col counter)

# ===========================================================
# MIDDLE LOOP — iterate columns of B (= cells of C row)
# ===========================================================
col_loop:
    # -----------------------------------------------------------
    # Compute starting pointers for this dot product:
    #   A row i starts at  a0 + (i*N*4)
    #   B col j starts at  a1 + (j*N*4)
    # For N=8: i*N*4 = i*32 = i<<5
    # -----------------------------------------------------------
    slli    a5, t0, 5           # a5 = i * 32  (= i * N * 4 for N=8)
    add     t4, a0, a5          # t4 = A + i*32 = pointer to A row i, col 0

    slli    a5, t1, 5           # a5 = j * 32
    add     t5, a1, a5          # t5 = B + j*32 = pointer to B col j, row 0

    # -----------------------------------------------------------
    # Initialize vector accumulator v3 = {0, 0, 0, 0}
    # First set vl=VLMAX (=4 for e32) so vmv.v.x fills all lanes
    # -----------------------------------------------------------
    li      a5, 4               # AVL = 4 (= VLMAX for e32/m1)
    vsetvli zero, a5, e32, m1   # vl = 4
    vmv.v.x v3, x0              # v3 = {0, 0, 0, 0}

    # -----------------------------------------------------------
    # Inner loop: chunk through N elements of dot product
    # -----------------------------------------------------------
    mv      t6, a3              # t6 = remaining = N

inner_loop:
    vsetvli a4, t6, e32, m1     # a4 = vl = min(remaining, VLMAX)
    vle32.v v1, (t4)            # v1 = A[i][k..k+vl-1]
    vle32.v v2, (t5)            # v2 = B[k..k+vl-1][j]
    vmacc.vv v3, v1, v2         # v3[lane] += v1[lane] * v2[lane]

    slli    a5, a4, 2           # a5 = vl * 4 (byte count)
    add     t4, t4, a5          # advance A pointer
    add     t5, t5, a5          # advance B pointer
    sub     t6, t6, a4          # remaining -= vl
    bnez    t6, inner_loop      # loop until all N elements processed

    # -----------------------------------------------------------
    # Reduce v3 (4 partial sums) to one scalar
    # -----------------------------------------------------------
    li      a5, 4
    vsetvli zero, a5, e32, m1   # vl = 4 for the reduction
    vmv.v.x v0, x0              # v0 = {0,0,0,0} (seed for vredsum)
    vredsum.vs v4, v3, v0       # v4[0] = sum of v3 lanes 0..3
    vmv.x.s a6, v4              # a6 = scalar sum (extract lane 0)

    # -----------------------------------------------------------
    # Store C[i][j] = a6, advance C pointer
    # -----------------------------------------------------------
    sw      a6, 0(a2)
    addi    a2, a2, 4           # next C cell

    # -----------------------------------------------------------
    # j++; loop if j < N
    # -----------------------------------------------------------
    addi    t1, t1, 1
    blt     t1, a3, col_loop

    # -----------------------------------------------------------
    # End of row: i++; loop if i < N
    # -----------------------------------------------------------
    addi    t0, t0, 1
    blt     t0, a3, row_loop

    # ===========================================================
    # Done — clean exit
    # ===========================================================
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# ===========================================================
# Data — 8x8 matrices with elements 1..64
# A is row-major; B = same byte pattern (= A^T in column-major)
# So C = A × A^T (symmetric output, easy to verify)
# ===========================================================
.balign 4
data_A:
    .word  1,  2,  3,  4,  5,  6,  7,  8         # A row 0
    .word  9, 10, 11, 12, 13, 14, 15, 16         # A row 1
    .word 17, 18, 19, 20, 21, 22, 23, 24         # A row 2
    .word 25, 26, 27, 28, 29, 30, 31, 32         # A row 3
    .word 33, 34, 35, 36, 37, 38, 39, 40         # A row 4
    .word 41, 42, 43, 44, 45, 46, 47, 48         # A row 5
    .word 49, 50, 51, 52, 53, 54, 55, 56         # A row 6
    .word 57, 58, 59, 60, 61, 62, 63, 64         # A row 7

.balign 4
data_B:                                          # column-major: B col j = A row j
    .word  1,  2,  3,  4,  5,  6,  7,  8         # B col 0
    .word  9, 10, 11, 12, 13, 14, 15, 16         # B col 1
    .word 17, 18, 19, 20, 21, 22, 23, 24         # B col 2
    .word 25, 26, 27, 28, 29, 30, 31, 32         # B col 3
    .word 33, 34, 35, 36, 37, 38, 39, 40         # B col 4
    .word 41, 42, 43, 44, 45, 46, 47, 48         # B col 5
    .word 49, 50, 51, 52, 53, 54, 55, 56         # B col 6
    .word 57, 58, 59, 60, 61, 62, 63, 64         # B col 7
