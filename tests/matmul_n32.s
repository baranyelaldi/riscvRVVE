# =============================================================
# matmul_n32.s — 32x32 integer matmul with cycle counting
# Comparable to Vicuna's N=32 evaluation (Luffca: 5.865 OP/cycle).
#
# Algorithm: same incremental-pointer pattern as matmul_var_anyN.s,
# just N=32 hardcoded and with cycle measurement.
#
# Data pattern: A[i][j] = i+1 (constant per row).
# With B = A^T stored column-major (same byte pattern), this gives
# C[i][j] = N * (i+1) * (j+1) = 32 * (i+1) * (j+1)
#
# Memory layout:
#   Code:    0x2000..~0x2200
#   data_A:  follows code (4 KB)
#   data_B:  follows data_A (4 KB)
#   Output C: 0x8000..0x9000 (4 KB) — moved here to avoid collision
#   Cycle count delta: stored at 0x9000
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Sample cycle counter at the START
    # -----------------------------------------------------------
    csrr    s0, cycle               # s0 = start cycle count

    # -----------------------------------------------------------
    # Setup pointers + N
    # -----------------------------------------------------------
    la      a0, data_A
    la      a1, data_B
    li      a2, 0x8000              # C base — clear of data
    li      a3, 32                  # N = 32

    slli    a7, a3, 2               # stride = N * 4 = 128

    mv      t0, a0                  # A_row_ptr = A base
    li      t6, 0                   # i = 0

row_loop:
    mv      t1, a1                  # B_col_ptr = B base (reset each row)
    li      t2, 0                   # j = 0

col_loop:
    # Initialize accumulator v3 = {0, 0, 0, 0}
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v3, x0

    # Inner-loop setup
    mv      t4, t0                  # inner A ptr
    mv      t5, t1                  # inner B ptr
    mv      t3, a3                  # remaining = N = 32

inner_loop:
    vsetvli a4, t3, e32, m1         # vl = min(remaining, 4)
    vle32.v v1, (t4)
    vle32.v v2, (t5)
    vmacc.vv v3, v1, v2

    slli    a5, a4, 2
    add     t4, t4, a5
    add     t5, t5, a5
    sub     t3, t3, a4
    bnez    t3, inner_loop

    # Reduce v3 to scalar
    li      a5, 4
    vsetvli zero, a5, e32, m1
    vmv.v.x v0, x0
    vredsum.vs v4, v3, v0
    vmv.x.s a6, v4

    # Store C[i][j]
    sw      a6, 0(a2)
    addi    a2, a2, 4

    # Advance B for next column
    add     t1, t1, a7
    addi    t2, t2, 1
    blt     t2, a3, col_loop

    # Advance A for next row
    add     t0, t0, a7
    addi    t6, t6, 1
    blt     t6, a3, row_loop

    # -----------------------------------------------------------
    # Sample cycle counter at the END and compute delta
    # -----------------------------------------------------------
    csrr    s1, cycle               # s1 = end cycle count
    sub     s2, s1, s0              # s2 = total cycles
    li      t0, 0x9000
    sw      s2, 0(t0)               # ram[0x9000] = cycle count

    # Optional: also store start and end for sanity
    sw      s0, 4(t0)               # ram[0x9004] = start
    sw      s1, 8(t0)               # ram[0x9008] = end

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# =============================================================
# Data — 32x32 matrices
# A[i][j] = i+1 (each row is a constant value, 1..32)
# B = A^T in column-major (each column of B = each row of A)
#   ⇒ data_B has same byte pattern as data_A
# =============================================================
.balign 4
data_A:
    .fill 32, 4, 1
    .fill 32, 4, 2
    .fill 32, 4, 3
    .fill 32, 4, 4
    .fill 32, 4, 5
    .fill 32, 4, 6
    .fill 32, 4, 7
    .fill 32, 4, 8
    .fill 32, 4, 9
    .fill 32, 4, 10
    .fill 32, 4, 11
    .fill 32, 4, 12
    .fill 32, 4, 13
    .fill 32, 4, 14
    .fill 32, 4, 15
    .fill 32, 4, 16
    .fill 32, 4, 17
    .fill 32, 4, 18
    .fill 32, 4, 19
    .fill 32, 4, 20
    .fill 32, 4, 21
    .fill 32, 4, 22
    .fill 32, 4, 23
    .fill 32, 4, 24
    .fill 32, 4, 25
    .fill 32, 4, 26
    .fill 32, 4, 27
    .fill 32, 4, 28
    .fill 32, 4, 29
    .fill 32, 4, 30
    .fill 32, 4, 31
    .fill 32, 4, 32

.balign 4
data_B:
    .fill 32, 4, 1
    .fill 32, 4, 2
    .fill 32, 4, 3
    .fill 32, 4, 4
    .fill 32, 4, 5
    .fill 32, 4, 6
    .fill 32, 4, 7
    .fill 32, 4, 8
    .fill 32, 4, 9
    .fill 32, 4, 10
    .fill 32, 4, 11
    .fill 32, 4, 12
    .fill 32, 4, 13
    .fill 32, 4, 14
    .fill 32, 4, 15
    .fill 32, 4, 16
    .fill 32, 4, 17
    .fill 32, 4, 18
    .fill 32, 4, 19
    .fill 32, 4, 20
    .fill 32, 4, 21
    .fill 32, 4, 22
    .fill 32, 4, 23
    .fill 32, 4, 24
    .fill 32, 4, 25
    .fill 32, 4, 26
    .fill 32, 4, 27
    .fill 32, 4, 28
    .fill 32, 4, 29
    .fill 32, 4, 30
    .fill 32, 4, 31
    .fill 32, 4, 32
