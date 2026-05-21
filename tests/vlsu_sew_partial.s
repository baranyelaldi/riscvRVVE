.text
.global _start
_start:
    # Setup source memory at 0x2000 with byte pattern A0..AF
    # (4 words: little-endian 0xA3A2A1A0, 0xA7A6A5A4, 0xABAAA9A8, 0xAFAEADAC)
    li      t0, 0x2000
    li      t1, 0xA3A2A1A0; sw t1, 0(t0)
    li      t1, 0xA7A6A5A4; sw t1, 4(t0)
    li      t1, 0xABAAA9A8; sw t1, 8(t0)
    li      t1, 0xAFAEADAC; sw t1, 12(t0)

    # Pre-seed destination at 0x4000..0x401F with 0xFF sentinel.
    # Untouched bytes will stay 0xFF, proving byte enables worked.
    li      t2, 0x4000
    li      t1, 0xFFFFFFFF; sw t1, 0(t2)
    li      t1, 0xFFFFFFFF; sw t1, 4(t2)
    li      t1, 0xFFFFFFFF; sw t1, 8(t2)
    li      t1, 0xFFFFFFFF; sw t1, 12(t2)
    li      t1, 0xFFFFFFFF; sw t1, 16(t2)
    li      t1, 0xFFFFFFFF; sw t1, 20(t2)
    li      t1, 0xFFFFFFFF; sw t1, 24(t2)
    li      t1, 0xFFFFFFFF; sw t1, 28(t2)

    # Test 1: vle8.v with vl=3 — load 3 bytes
    # Expected v1 = {A0, A1, A2, 0, 0, ..., 0} (16 byte lanes total)
    li      t3, 3
    vsetvli zero, t3, e8, m1
    vle8.v  v1, (t0)

    # Test 2: vse8.v with vl=3 — store 3 bytes to pre-seeded ram[0x4000]
    # Expected ram[0x4000] word = 0xFFA2A1A0 (byte 3 stays FF!)
    # Expected ram[0x4001..0x4003] words = 0xFFFFFFFF (untouched)
    vse8.v  v1, (t2)

    # Test 3: vle16.v with vl=5 — load 10 bytes (3 beats, last beat 2 bytes)
    # v2 lanes (halfwords): {0xA1A0, 0xA3A2, 0xA5A4, 0xA7A6, 0xA9A8, 0, 0, 0}
    li      t3, 5
    vsetvli zero, t3, e16, m1
    vle16.v v2, (t0)

    # Test 4: vse16.v with vl=5 — store 10 bytes to ram[0x4010]
    # Expected:
    #   ram[0x4010] = 0xA3A2A1A0   (full word: bytes A0,A1,A2,A3)
    #   ram[0x4011] = 0xA7A6A5A4   (full word: bytes A4,A5,A6,A7)
    #   ram[0x4012] = 0xFFFFA9A8   (PARTIAL word: bytes A8,A9 + FF,FF preserved)
    #   ram[0x4013] = 0xFFFFFFFF   (untouched)
    li      t4, 0x4010
    vse16.v v2, (t4)

    # Test 5: regression — vle32/vse32 at vl=4 should match old behavior
    li      t3, 4
    vsetvli zero, t3, e32, m1
    vle32.v v3, (t0)
    li      t5, 0x4020
    vse32.v v3, (t5)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
