.text
.global _start
_start:
    # vmv.s.x: write scalar to lane 0 only
    li      t0, 0xDEAD
    vmv.s.x v1, t0                  # v1 = {0xDEAD, 0, 0, 0}

    # Confirm lane 0 distinct from other lanes (i.e., not a broadcast)
    li      t0, 0xBEEF
    vmv.s.x v2, t0                  # v2 = {0xBEEF, 0, 0, 0}

    # vid.v: generate lane indices
    vid.v   v3                      # v3 = {0, 1, 2, 3}

    # Combine: use vid + arithmetic to build {10, 11, 12, 13}
    li      t0, 10
    vadd.vx v4, v3, t0              # v4 = vid + 10 = {10, 11, 12, 13}

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
