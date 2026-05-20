.text
.global _start
_start:
    # Read vl before vsetvli to confirm baseline
    csrr    t0, vl                  # t0 = 4 (reset value from B.1)

    # Execute vsetvli — should NOT trap, should NOT hang
    # AVL=8, vtypei=e32/m1/ta/ma (= 0x0D8 — but doesn't matter, we don't honor it yet)
    li      t1, 8
    vsetvli zero, t1, e32, m1       # rd=zero (= x0, so no writeback expected)

    # Read vl again — should STILL be 4 (no execution = no CSR write)
    csrr    t2, vl                  # t2 = 4 (unchanged)

    # Try vsetivli too
    vsetivli zero, 3, e32, m1       # immediate AVL
    csrr    t3, vl                  # t3 = 4 (still unchanged)

    # Confirm a normal V-ALU op after vsetvli still works
    li      t4, 5
    vmv.v.x v1, t4                  # v1 = {5, 5, 5, 5}

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
