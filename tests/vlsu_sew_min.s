.text
.global _start
_start:
    # Initialize source memory at 0x2000 with byte pattern {1..16}
    li      t0, 0x2000
    li      t1, 0x04030201; sw t1, 0(t0)
    li      t1, 0x08070605; sw t1, 4(t0)
    li      t1, 0x0C0B0A09; sw t1, 8(t0)
    li      t1, 0x100F0E0D; sw t1, 12(t0)

    # Round-trip 1: e8 load → e8 store
    vle8.v  v1, (t0)
    li      t2, 0x4000
    vse8.v  v1, (t2)              # ram[0x4000..0x400F] = {1..16}

    # Round-trip 2: e16 load → e16 store
    vle16.v v2, (t0)
    li      t3, 0x4010
    vse16.v v2, (t3)              # ram[0x4010..0x401F] identical bytes

    # Round-trip 3: e32 load → e8 store (proves byte-level equivalence)
    vle32.v v3, (t0)
    li      t4, 0x4020
    vse8.v  v3, (t4)              # ram[0x4020..0x402F] identical bytes

    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
