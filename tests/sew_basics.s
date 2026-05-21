.text
.global _start
_start:
    li      t0, 0x80808080         # use a value that DOES carry across byte boundaries
    vmv.v.x v1, t0
    vmv.v.x v2, t0

    li      t1, 16                  # AVL = 16 (covers VLMAX at all SEWs)

    # e32 vadd — vl saturates to 4
    vsetvli zero, t1, e32, m1
    vadd.vv v3, v1, v2              # each 32-bit lane: 0x80808080 + 0x80808080 = 0x01010100

    # e16 vadd — vl saturates to 8
    vsetvli zero, t1, e16, m1
    vadd.vv v4, v1, v2              # each 16-bit lane: 0x8080 + 0x8080 = 0x0100 → packed 0x01000100 per word

    # e8 vadd — vl saturates to 16
    vsetvli zero, t1, e8, m1
    vadd.vv v5, v1, v2              # each byte: 0x80 + 0x80 = 0x00 → all zeros

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
