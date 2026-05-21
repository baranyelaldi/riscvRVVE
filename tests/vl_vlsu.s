.text
.global _start
_start:
    # Setup mem at 0x2000 with pattern: {0xAA, 0xBB, 0xCC, 0xDD}
    li      t0, 0x2000
    li      t1, 0xAAAAAAAA; sw t1, 0(t0)
    li      t1, 0xBBBBBBBB; sw t1, 4(t0)
    li      t1, 0xCCCCCCCC; sw t1, 8(t0)
    li      t1, 0xDDDDDDDD; sw t1, 12(t0)

    # ── Test 1: vl=2 load — should fill only lanes 0,1 ──
    vsetivli zero, 2, e32, m1       # vl = 2
    vle32.v v1, (t0)                 # v1 = {0xAA, 0xBB, 0, 0}
    li      t2, 0x4000
    vsetivli zero, 4, e32, m1       # vl = 4 for the store (so we see all lanes)
    vse32.v v1, (t2)                # ram[0x4000..0x4003] = {0xAA, 0xBB, 0, 0}

    # ── Test 2: vl=2 store — only first 2 elements written ──
    # First seed dst with 0xEE pattern to detect "untouched"
    li      t3, 0x4010
    li      t1, 0xEEEEEEEE; sw t1, 0(t3)
    li      t1, 0xEEEEEEEE; sw t1, 4(t3)
    li      t1, 0xEEEEEEEE; sw t1, 8(t3)
    li      t1, 0xEEEEEEEE; sw t1, 12(t3)

    # Load full data into v2
    vsetivli zero, 4, e32, m1       # vl = 4
    vle32.v v2, (t0)                # v2 = {0xAA, 0xBB, 0xCC, 0xDD}

    # Store only 2 elements
    vsetivli zero, 2, e32, m1       # vl = 2
    vse32.v v2, (t3)                 # ram[0x4010..0x4011] = {0xAA, 0xBB}
                                     # ram[0x4012..0x4013] should STAY 0xEEEEEEEE

    # ── Test 3: vl=0 load — does nothing, v3 stays 0 ──
    vsetivli zero, 0, e32, m1       # vl = 0
    vle32.v v3, (t0)                 # v3 should stay all zeros

    # ── Test 4: vl=3 load — fills lanes 0,1,2 only ──
    vsetivli zero, 3, e32, m1       # vl = 3
    vle32.v v4, (t0)                 # v4 = {0xAA, 0xBB, 0xCC, 0}

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
