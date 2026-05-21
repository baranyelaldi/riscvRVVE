.text
.global _start
_start:
    # ===========================================================
    # Setup
    # ===========================================================
    la      a0, data_A          # A base (16-element input)
    li      a1, 0x4000          # B base (output in TCM)
    li      a2, 16              # N = 16

    # -----------------------------------------------------------
    # Zero out B[0] so it's a clean sentinel
    # (we won't write B[0]; pre-clearing makes inspection obvious)
    # -----------------------------------------------------------
    sw      zero, 0(a1)         # B[0] = 0
    addi    t5, a2, -1          # t5 = N-1
    slli    t5, t5, 2           # t5 = (N-1) * 4
    add     t5, a1, t5          # t5 = &B[N-1]
    sw      zero, 0(t5)         # B[N-1] = 0

    # -----------------------------------------------------------
    # Set up the three sliding input pointers
    # The stencil B[i] = A[i-1] + A[i] + A[i+1] for i = 1..N-2
    # First i we compute is i=1, so:
    #   a_left   = &A[0]
    #   a_center = &A[1]
    #   a_right  = &A[2]
    # Output starts at &B[1]
    # -----------------------------------------------------------
    mv      t0, a0              # t0 = &A[0]    (a_left)
    addi    t1, a0, 4           # t1 = &A[1]    (a_center)
    addi    t2, a0, 8           # t2 = &A[2]    (a_right)
    addi    t3, a1, 4           # t3 = &B[1]    (output)

    # Number of B cells to write = N - 2 (we skip B[0] and B[N-1])
    addi    t4, a2, -2          # t4 = remaining = N-2 = 14

# ===========================================================
# CHUNK LOOP — process vl cells per iteration
# ===========================================================
chunk_loop:
    # -----------------------------------------------------------
    # vsetvli: vl = min(remaining, VLMAX_e32) = min(t4, 4)
    # -----------------------------------------------------------
    vsetvli a3, t4, e32, m1

    # -----------------------------------------------------------
    # Three overlapping loads — sliding window
    # -----------------------------------------------------------
    vle32.v v1, (t0)            # v1 = A[i-1 .. i+vl-2]
    vle32.v v2, (t1)            # v2 = A[i   .. i+vl-1]
    vle32.v v3, (t2)            # v3 = A[i+1 .. i+vl  ]

    # -----------------------------------------------------------
    # Sum the three vectors elementwise (no /3 — see note above)
    # -----------------------------------------------------------
    vadd.vv v4, v1, v2          # v4 = v1 + v2
    vadd.vv v4, v4, v3          # v4 += v3 → v4 = v1 + v2 + v3

    # -----------------------------------------------------------
    # Store result at B[i..i+vl-1]
    # -----------------------------------------------------------
    vse32.v v4, (t3)

    # -----------------------------------------------------------
    # Advance all four pointers by vl*4 bytes
    # -----------------------------------------------------------
    slli    a4, a3, 2           # a4 = vl * 4
    add     t0, t0, a4
    add     t1, t1, a4
    add     t2, t2, a4
    add     t3, t3, a4

    # -----------------------------------------------------------
    # remaining -= vl; loop if more cells remain
    # -----------------------------------------------------------
    sub     t4, t4, a3
    bnez    t4, chunk_loop

    # ===========================================================
    # Done — clean exit
    # ===========================================================
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# ===========================================================
# Data — 16-element input array
# Use a smooth ramp so stencil sums are easy to verify:
#   A[i] = (i+1) * 10
# Values: 10, 20, 30, 40, 50, 60, ..., 160
# ===========================================================
.balign 4
data_A:
    .word  10,  20,  30,  40
    .word  50,  60,  70,  80
    .word  90, 100, 110, 120
    .word 130, 140, 150, 160
