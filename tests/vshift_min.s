.text
.global _start
_start:
    # v1 = {0x80, 0x80, 0x80, 0x80}; v2 = {2, 2, 2, 2}
    li      t0, 0x80
    vmv.v.x v1, t0
    li      t0, 2
    vmv.v.x v2, t0

    # Shift left: 0x80 << 2 = 0x200
    vsll.vv v3, v1, v2          # v3 = {0x200, 0x200, 0x200, 0x200}

    # Shift right logical: 0x80 >> 1 = 0x40
    vsrl.vi v4, v1, 1           # v4 = {0x40, 0x40, 0x40, 0x40}

    # Shift right arithmetic with negative value: 0xFFFFFF80 >>> 2 = 0xFFFFFFE0
    li      t0, -128            # 0xFFFFFF80
    vmv.v.x v5, t0
    vsra.vi v6, v5, 2           # v6 = {0xFFFFFFE0, ...}  (sign-extended fill)

    # Shift-by-scalar variant
    li      t0, 3
    vsll.vx v7, v1, t0          # v7 = 0x80 << 3 = {0x400, 0x400, 0x400, 0x400}

    # Exit — inspect vregs_q[3,4,6,7] in GTKWave
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
