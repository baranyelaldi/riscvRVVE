.text
.global _start
_start:
    # mem[0x2000..0x200F] = {5, 3, 2, 1}
    li      t0, 0x2000
    li      t1, 5;  sw t1, 0(t0)
    li      t1, 3;  sw t1, 4(t0)
    li      t1, 2;  sw t1, 8(t0)
    li      t1, 1;  sw t1, 12(t0)

    # Load v1 = v2 = {5, 3, 2, 1}; zero v3
    vle32.v v1, (t0)
    vle32.v v2, (t0)
    vmv.v.x v3, x0                    # v3 = {0, 0, 0, 0}

    # v3 = v3 + v1 * v2 = {25, 9, 4, 1}
    vmacc.vv v3, v1, v2

    # Store v3 to 0x4000
    li      t2, 0x4000
    vse32.v v3, (t2)

    # Second accumulate — proves it ACCUMULATES, not just multiply-and-overwrite
    # v3 = v3 + v1 * v2 = {50, 18, 8, 2}
    vmacc.vv v3, v1, v2
    li      t3, 0x4010
    vse32.v v3, (t3)

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
