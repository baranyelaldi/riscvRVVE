# =============================================================
# strlen.s — RVV-vectorized strlen
# Finds the length of a null-terminated string.
#
# Strategy: process VLMAX bytes per chunk. In each chunk, compare
# every byte against 0 (vmseq.vx). vfirst.m returns the index of
# the first null byte, or -1 if the chunk has no null.
#   - no null  -> add VLMAX to length, advance, repeat
#   - null     -> length += (index of null in this chunk); done
#
# Test string: "Hello RVVE vectors!" = 19 chars -> strlen = 19 (0x13)
#   Chunk 1: bytes 0..15  ("Hello RVVE vecto") -> no null, vfirst=-1
#   Chunk 2: bytes 16..31 ("rs!\0...")         -> null at index 3
#   length = 16 + 3 = 19
# =============================================================

.text
.global _start
_start:
    # -----------------------------------------------------------
    # Setup
    # -----------------------------------------------------------
    la      a0, str             # a0 = string pointer
    li      a1, 0               # a1 = length accumulator

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot before kernel
    # -----------------------------------------------------------
    csrr    s0, cycle           # s0 = start cycle

# ===============================================================
# STRLEN LOOP — scan VLMAX bytes per iteration
# ===============================================================
strlen_loop:
    # vl = VLMAX (request max via rs1 = x0). For VLEN=128, e8 -> vl=16.
    vsetvli t0, x0, e8, m1

    # Load up to 16 bytes of the string
    vle8.v  v1, (a0)

    # Mask: v2[i] = (byte[i] == 0). Scalar operand is x0 (= 0).
    vmseq.vx v2, v1, x0

    # t1 = index of first null byte in this chunk, or -1 if none
    vfirst.m t1, v2

    # If t1 >= 0, a null was found in this chunk -> exit loop
    bgez    t1, found

    # No null this chunk: add full VLMAX to length, advance pointer
    add     a1, a1, t0          # length += vl
    add     a0, a0, t0          # ptr    += vl
    j       strlen_loop

found:
    # Null is at index t1 within the current chunk
    add     a1, a1, t1          # length += index

    # -----------------------------------------------------------
    # CYCLE MEASUREMENT — snapshot after kernel
    # -----------------------------------------------------------
    csrr    s1, cycle           # s1 = end cycle
    sub     s2, s1, s0          # s2 = elapsed cycles

    # -----------------------------------------------------------
    # Store results
    #   ram[0x4000] = string length
    #   ram[0x9000] = cycle count
    # -----------------------------------------------------------
    li      t0, 0x4000
    sw      a1, 0(t0)           # ram[4096] = length = 19 (0x13)
    li      t0, 0x9000
    sw      s2, 0(t0)           # ram[9216] = cycle count

    # Clean exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b

# =============================================================
# Data
# .asciz appends the null terminator automatically.
# .zero pads with extra nulls so the second chunk's 16-byte read
# always lands in valid memory.
# =============================================================
.balign 4
str:
    .asciz "Hello RVVE vectors!"
    .zero  16
