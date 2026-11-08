# Input for sobel_scalar.c — same 3x6 zero-padded image rows as
# tests/sobel_selfcheck.s (4 output columns, zero border on both sides).
.section .rodata
.balign 4
.global sob_rowA
.global sob_rowB
.global sob_rowC
.global sob_cols
sob_rowA:
    .word 0, 10, 20, 30, 40, 0
sob_rowB:
    .word 0, 50, 60, 70, 80, 0
sob_rowC:
    .word 0, 90, 100, 110, 120, 0
sob_cols:
    .word 4
