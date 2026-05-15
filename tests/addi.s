.section .text
.globl _start
_start:
    # ---- your test instructions go here ----
    addi    t0, zero, 0x123      # t0 ← 0x123
    addi    t1, zero, 0x456      # t1 ← 0x456
    add     t2, t0, t1           # t2 ← 0x579
