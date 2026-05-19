.text
.global _start
_start:
    # Setup memory pattern at strided addresses:
    # mem[0x2000] = 0x11111111, mem[0x2010] = 0x22222222,
    # mem[0x2020] = 0x33333333, mem[0x2030] = 0x44444444
    # Intermediate addresses filled with 0xDEADBEEF (to catch "load wrong address")

    li      t0, 0x2000
    li      t1, 0x11111111;  sw t1, 0(t0)
    li      t1, 0xDEADBEEF;  sw t1, 4(t0)    # filler
    li      t1, 0xDEADBEEF;  sw t1, 8(t0)
    li      t1, 0xDEADBEEF;  sw t1, 12(t0)
    li      t1, 0x22222222;  sw t1, 16(t0)
    li      t1, 0xDEADBEEF;  sw t1, 20(t0)
    li      t1, 0xDEADBEEF;  sw t1, 24(t0)
    li      t1, 0xDEADBEEF;  sw t1, 28(t0)
    li      t1, 0x33333333;  sw t1, 32(t0)
    li      t1, 0xDEADBEEF;  sw t1, 36(t0)
    li      t1, 0xDEADBEEF;  sw t1, 40(t0)
    li      t1, 0xDEADBEEF;  sw t1, 44(t0)
    li      t1, 0x44444444;  sw t1, 48(t0)

    # Strided load
    li      t2, 16                    # stride = 16 bytes
    vlse32.v v1, (t0), t2             # v1 = {0x11111111, 0x22222222, 0x33333333, 0x44444444}

    # Write back to a clean memory region for inspection
    li      t3, 0x4000
    vse32.v v1, (t3)                  # ram[0x4000..0x400F] should be the 4 values

    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
