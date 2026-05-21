.text
.global _start
_start:
    li      t0, 5                # addi t0, x0, 5  (no lui — value fits in 12 bits)
    vmv.v.x v1, t0               # v1 = {5, 5, 5, 5}
    vmv.v.x v3, x0               # v3 = {0, 0, 0, 0}

    vmacc.vv v3, v1, v1          # v3 = 0 + 5*5 = {25, 25, 25, 25}

    # Clean exit — no need to store, just inspect vregs_q[3] in GTKWave
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
