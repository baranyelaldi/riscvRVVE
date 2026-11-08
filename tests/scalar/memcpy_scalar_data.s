# Input data for memcpy_scalar.c — same 20-byte pattern as tests/memcpy.s.
# Kept in assembly so the compiler cannot see the values and constant-fold
# the copy; the length is data too, so the loop is a real runtime-n memcpy.
.section .rodata
.balign 4
.global memcpy_src
.global memcpy_len
memcpy_src:
    .word 0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120
memcpy_len:
    .word 20
