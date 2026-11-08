# crt0.s — minimal startup for the freestanding C scalar baselines.
# Boot vector is 0x2000 (link.ld puts .text.start first). No .bss/.data
# initialisation is needed: the baselines use no zero-initialised globals,
# and the ELF loader preloads every initialised section into the TCM.

.section .text.start
.global _start
_start:
    li      sp, 0x10000         # top of the 64 KB TCM; stack grows down
    call    main

    # Clean exit via the sim_exit backdoor (same as the assembly tests)
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
