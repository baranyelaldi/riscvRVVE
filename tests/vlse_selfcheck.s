# =============================================================
# vlse_selfcheck.s
# Self-checking strided / partial-beat V-LSU regression.
#
# Covers the V-LSU behaviors no other selfcheck exercises:
#   S1: vlse32 stride=16   — strided address generation (load)
#   S2: vlse32 stride=0    — broadcast corner
#   S3: vsse32 stride=16   — strided store + gap words untouched
#   S4: vle8/vse8 vl=6     — partial last beat, byte enables (tail bytes untouched)
#
# Result marker (same convention as the other selfchecks):
#   ram[0xA000] = 0x600D600D         -> PASS
#               = 0xBAD00000 | idx   -> FAIL at check index `idx`
# =============================================================

.macro CHECKW addr, expect, idx
    li      t0, \addr
    lw      t1, 0(t0)
    li      t2, \expect
    li      t3, \idx
    bne     t1, t2, check_fail
.endm

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Source patterns
    # -----------------------------------------------------------
    # Strided source at 0x3000: payload every 16 bytes, DEADBEEF fillers
    li      t0, 0x3000
    li      t1, 0x11111111;  sw t1,  0(t0)
    li      t1, 0xDEADBEEF;  sw t1,  4(t0)
    sw      t1,  8(t0)
    sw      t1, 12(t0)
    li      t1, 0x22222222;  sw t1, 16(t0)
    li      t1, 0xDEADBEEF;  sw t1, 20(t0)
    sw      t1, 24(t0)
    sw      t1, 28(t0)
    li      t1, 0x33333333;  sw t1, 32(t0)
    li      t1, 0xDEADBEEF;  sw t1, 36(t0)
    sw      t1, 40(t0)
    sw      t1, 44(t0)
    li      t1, 0x44444444;  sw t1, 48(t0)

    # Byte source at 0x3040: A0..A5 then FF fillers
    li      t1, 0xA3A2A1A0;  sw t1, 64(t0)
    li      t1, 0xFFFFA5A4;  sw t1, 68(t0)

    # Pre-fill destination regions with 0xEEEEEEEE sentinels
    li      t0, 0x4100
    li      t1, 0xEEEEEEEE
    sw      t1,  0(t0)
    sw      t1,  4(t0)
    sw      t1,  8(t0)
    sw      t1, 12(t0)
    sw      t1, 16(t0)
    sw      t1, 20(t0)
    sw      t1, 24(t0)
    sw      t1, 28(t0)
    sw      t1, 32(t0)
    sw      t1, 40(t0)
    li      t0, 0x4200
    sw      t1,  0(t0)
    sw      t1,  4(t0)

    # -----------------------------------------------------------
    # S1: strided load, stride = 16
    # -----------------------------------------------------------
    li      a5, 4
    vsetvli zero, a5, e32, m1
    li      t0, 0x3000
    li      t2, 16
    vlse32.v v1, (t0), t2           # v1 = {11111111,22222222,33333333,44444444}
    li      t3, 0x4000
    vse32.v v1, (t3)

    # -----------------------------------------------------------
    # S2: stride = 0 broadcast
    # -----------------------------------------------------------
    li      t0, 0x3010
    li      t2, 0
    vlse32.v v2, (t0), t2           # v2 = {22222222 x4}
    li      t3, 0x4010
    vse32.v v2, (t3)

    # -----------------------------------------------------------
    # S3: strided store, stride = 16 (into EE-filled region)
    # -----------------------------------------------------------
    li      t3, 0x4100
    li      t2, 16
    vsse32.v v1, (t3), t2           # words at 0x4100/0x4110/0x4120/0x4130

    # -----------------------------------------------------------
    # S4: e8 partial transfer, vl = 6 (into EE-filled region)
    # -----------------------------------------------------------
    li      a5, 6
    vsetvli zero, a5, e8, m1
    li      t0, 0x3040
    vle8.v  v3, (t0)                # lanes 0..5 = A0..A5, tail lanes 0
    li      t3, 0x4200
    vse8.v  v3, (t3)                # bytes 0..5 written, bytes 6..7 untouched

    # ===========================================================
    # Checks
    # ===========================================================
    CHECKW 0x4000, 0x11111111, 0    # S1 strided load lanes
    CHECKW 0x4004, 0x22222222, 1
    CHECKW 0x4008, 0x33333333, 2
    CHECKW 0x400C, 0x44444444, 3

    CHECKW 0x4010, 0x22222222, 4    # S2 broadcast lanes
    CHECKW 0x4014, 0x22222222, 5
    CHECKW 0x4018, 0x22222222, 6
    CHECKW 0x401C, 0x22222222, 7

    CHECKW 0x4100, 0x11111111, 8    # S3 strided store payloads
    CHECKW 0x4110, 0x22222222, 9
    CHECKW 0x4120, 0x33333333, 10
    CHECKW 0x4130, 0x44444444, 11
    CHECKW 0x4104, 0xEEEEEEEE, 12   # S3 gap words untouched
    CHECKW 0x4114, 0xEEEEEEEE, 13

    CHECKW 0x4200, 0xA3A2A1A0, 14   # S4 full first beat
    CHECKW 0x4204, 0xEEEEA5A4, 15   # S4 partial beat: bytes 4-5 data, 6-7 sentinel

check_pass:
    li      t6, 0x600D600D
    j       check_report
check_fail:
    li      t5, 0xBAD00000
    or      t6, t5, t3
check_report:
    li      t0, 0xA000
    sw      t6, 0(t0)

    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
