.text
.global _start
_start:
    # ── Test 1: simple AVL within VLMAX ──
    li      t1, 3
    vsetvli t0, t1, e32, m1         # AVL=3, VLMAX=4 → vl=3, rd=t0=3
    csrr    t2, vl                   # t2 = 3
    csrr    t3, vtype                # t3 = vtype encoding for e32/m1/ta/ma

    # ── Test 2: AVL saturates to VLMAX ──
    li      t1, 99
    vsetvli t4, t1, e32, m1         # AVL=99, VLMAX=4 → vl=4, t4=4
    csrr    t5, vl                   # t5 = 4

    # ── Test 3: vsetivli with immediate AVL ──
    vsetivli a0, 2, e32, m1         # AVL=2 → vl=2, a0=2
    csrr    a1, vl                   # a1 = 2

    # ── Test 4: rs1=x0 → vl=VLMAX ──
    vsetvli a2, x0, e32, m1         # AVL=VLMAX → vl=4, a2=4
    csrr    a3, vl                   # a3 = 4

    # ── Test 5: invalid SEW (e64) → vill=1, vl=0 ──
    li      t1, 5
    vsetvli zero, t1, e64, m1       # e64 invalid in our scope → vl=0, vtype.vill=1
    csrr    t6, vl                   # t6 = 0
    # (can also check vtype bit 31)

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
