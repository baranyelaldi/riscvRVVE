// bench.h — measurement wrapper for the C scalar baselines.
//
// Mirrors the assembly benchmark wrapper exactly, so scalar and vector
// numbers are measured the same way:
//   csrr zero, instret   drain: CSR ops are serialized, so every older
//                        instruction has retired before the next CSR issues
//   csrr i0, instret     exact start of the instret window
//   csrr c0, cycle       start of the cycle window
//   ... kernel ...
//   csrr c1, cycle       end of the cycle window
//   csrr i1, instret     exact end (follows a CSR op -> kernel fully retired)
// instret(kernel) = i1 - i0 - 3   (start read + two cycle reads)
//
// Results go to the same fixed words the testbench reports:
//   0x9000 cycles -> [CYCLES]   0x9010 instret -> [INSTRET]
//   0xA000 0x600D600D / 0xBAD00000|idx -> [SELF-CHECK] PASS / FAIL at idx
#ifndef BENCH_H
#define BENCH_H

#include <stdint.h>

#define RESULT_CYCLES   (*(volatile uint32_t *)0x9000)
#define RESULT_INSTRET  (*(volatile uint32_t *)0x9010)
#define RESULT_CHECK    (*(volatile uint32_t *)0xA000)

#define CHECK_PASS      0x600D600Du
#define CHECK_FAIL(idx) (0xBAD00000u | (uint32_t)(idx))

// Both asm blocks are volatile with a memory clobber, so the compiler cannot
// move the kernel's loads/stores outside the measured window.
#define BENCH_START()                                                      \
    uint32_t bench_i0_, bench_c0_;                                         \
    __asm__ volatile("csrr zero, instret\n\t"                              \
                     "csrr %0, instret\n\t"                                \
                     "csrr %1, cycle"                                      \
                     : "=r"(bench_i0_), "=r"(bench_c0_) : : "memory")

#define BENCH_STOP()                                                       \
    do {                                                                   \
        uint32_t bench_c1_, bench_i1_;                                     \
        __asm__ volatile("csrr %0, cycle\n\t"                              \
                         "csrr %1, instret"                                \
                         : "=r"(bench_c1_), "=r"(bench_i1_) : : "memory"); \
        RESULT_CYCLES  = bench_c1_ - bench_c0_;                            \
        RESULT_INSTRET = bench_i1_ - bench_i0_ - 3;                        \
    } while (0)

#endif
