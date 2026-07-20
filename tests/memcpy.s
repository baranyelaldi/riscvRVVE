# =============================================================
# memcpy.s — RVV-vectorized memcpy
# Copies n bytes from src to dst using vsetvli + vle8/vse8 loop.
#
# Test: copy 20 bytes from 0x2000 to 0x4000.
#   - VLMAX at e8/m1 with VLEN=128 = 16 bytes per chunk
#   - 20 = 16 (full chunk) + 4 (partial chunk)
#   - Last chunk uses vl=4 with byte enables on the partial last beat
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup source pattern at 0x2000 — bytes 0x10..0x23
    # As 32-bit words (little-endian):
    #   0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120
    # -----------------------------------------------------------
    li      t0, 0x2000
    li      t1, 0x13121110; sw t1, 0(t0)
    li      t1, 0x17161514; sw t1, 4(t0)
    li      t1, 0x1B1A1918; sw t1, 8(t0)
    li      t1, 0x1F1E1D1C; sw t1, 12(t0)
    li      t1, 0x23222120; sw t1, 16(t0)

    # -----------------------------------------------------------
    # Pre-seed destination at 0x4000..0x401F with 0xFF sentinel
    # Bytes 0..19 should get overwritten; bytes 20..31 should remain
    # -----------------------------------------------------------
    li      t2, 0x4000
    li      t1, 0xFFFFFFFF
    sw      t1, 0(t2)
    sw      t1, 4(t2)
    sw      t1, 8(t2)
    sw      t1, 12(t2)
    sw      t1, 16(t2)
    sw      t1, 20(t2)
    sw      t1, 24(t2)
    sw      t1, 28(t2)

    # -----------------------------------------------------------
    # Set up memcpy arguments
    # -----------------------------------------------------------
    li      a0, 0x2000          # src
    li      a1, 0x4000          # dst
    li      a2, 20              # n = 20 bytes to copy

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle           # s0 = start cycle

# ===============================================================
# CHUNK LOOP — copy up to VLMAX bytes per iteration
# ===============================================================
memcpy_loop:
    # vl = min(remaining, VLMAX_e8)
    # For VLEN=128, VLMAX_e8 = 16.
    # First iteration: a2=20 → vl=16 (saturates)
    # Second iteration: a2=4 → vl=4 (partial chunk)
    vsetvli a3, a2, e8, m1

    # Load vl bytes from src
    vle8.v  v1, (a0)

    # Store vl bytes to dst
    # On the partial-vl iteration, V-LSU's last_beat_enables
    # masks out the upper bytes of the final word so the dst
    # tail (bytes 20..31) stays untouched.
    vse8.v  v1, (a1)

    # Advance pointers and counter
    add     a0, a0, a3          # src += vl
    add     a1, a1, a3          # dst += vl
    sub     a2, a2, a3          # remaining -= vl

    # Continue if more bytes remain
    bnez    a2, memcpy_loop

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot after kernel, store delta at 0x9000
    # -----------------------------------------------------------
    csrr    s1, cycle           # s1 = end cycle
    sub     s2, s1, s0          # s2 = elapsed cycles
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[0x9000] = cycle count  (= ram[9216])

    # -----------------------------------------------------------
    # Done — clean exit
    # -----------------------------------------------------------
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
