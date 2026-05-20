.text
.global _start
_start:
    # Set up v1 = {5, 5, 5, 5}
    li      t0, 5
    vmv.v.x v1, t0

    # ── Test 1: vl=2 should mask vmul output ──
    li      t1, 2
    vsetvli zero, t1, e32, m1       # vl = 2

    vmul.vv v2, v1, v1              # v2 should be {25, 25, 0, 0}

    # ── Test 2: vl=4 (full) should produce all lanes ──
    li      t1, 4
    vsetvli zero, t1, e32, m1       # vl = 4

    vmul.vv v3, v1, v1              # v3 should be {25, 25, 25, 25}

    # ── Test 3: vl=0 should produce all zeros ──
    vsetvli zero, x0, e32, m1       # Actually rs1=x0 → VLMAX=4, not 0!
    # Use vsetivli with imm=0 to actually get vl=0
    vsetivli zero, 0, e32, m1       # vl = 0

    vmul.vv v4, v1, v1              # v4 should be {0, 0, 0, 0}

    # ── Test 4: vl=3 partial mask ──
    li      t1, 3
    vsetvli zero, t1, e32, m1       # vl = 3
    vmul.vv v5, v1, v1              # v5 should be {25, 25, 25, 0}

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
