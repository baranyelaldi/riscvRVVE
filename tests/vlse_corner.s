.text
.global _start
_start:
    li      t0, 0x2000
    li      t1, 0xAAAAAAAA; sw t1, 0(t0)
    li      t1, 0xBBBBBBBB; sw t1, 4(t0)
    li      t1, 0xCCCCCCCC; sw t1, 8(t0)
    li      t1, 0xDDDDDDDD; sw t1, 12(t0)

    # Corner 1: stride = 4 (should behave like unit-stride)
    li      t2, 4
    vlse32.v v1, (t0), t2             # v1 = {0xAA, 0xBB, 0xCC, 0xDD}
    li      t3, 0x4000
    vse32.v v1, (t3)                  # ram[0x4000..0x4003] = {AA, BB, CC, DD}

    # Corner 2: stride = 0 (broadcast — all lanes load from base addr)
    li      t2, 0
    vlse32.v v2, (t0), t2             # v2 = {0xAA, 0xAA, 0xAA, 0xAA}
    li      t3, 0x4010
    vse32.v v2, (t3)                  # ram[0x4004..0x4007] = {AA, AA, AA, AA}

    # Corner 3: strided STORE — store one value to strided addresses
    li      t2, 16
    li      t3, 0x4020
    vsse32.v v1, (t3), t2             # ram[0x4020]=AA, ram[0x4024..]=junk, ram[0x4030]=BB, etc.

    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
