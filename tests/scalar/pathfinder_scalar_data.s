# Input for pathfinder_scalar.c — same rows as tests/pathfinder_selfcheck.s.
# src_padded = previous-row costs with an INF halo on both sides.
.section .rodata
.balign 4
.global pf_src
.global pf_grid
.global pf_cols
pf_src:
    .word 0xFFFFFFFF, 10, 5, 8, 3, 0xFFFFFFFF
pf_grid:
    .word 1, 2, 3, 4
pf_cols:
    .word 4
