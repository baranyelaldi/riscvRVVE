.text
.global _start
_start:
    csrr    t0, vl                  # t0 = 4 (= VLEN/32 for VLEN=128 SEW=32 LMUL=1)
    csrr    t1, vtype               # t1 = 0x000000C2 (vill=0, vma=1, vta=1, vsew=010, vlmul=000)
    csrr    t2, vlenb               # t2 = 16 (= VLEN/8 for VLEN=128)

    # Try to write vl — should be silently ignored
    li      t3, 0x99
    csrw    vl, t3
    csrr    t4, vl                  # t4 should still = 4 (write ignored)

    # Exit
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
