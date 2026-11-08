// histogram_scalar.c — RV32IM scalar baseline for tests/histogram_selfcheck.s
//
// Same 16 input bytes, same output (4 bin counts at 0x4000), same expected
// counts {2, 4, 6, 4}. Uses the natural scalar algorithm — one pass with
// hist[x]++ (clearing the bins is part of the kernel) — not a transliteration
// of the vector version's one-compare-per-bin structure.
#include "bench.h"

extern const uint8_t  hist_data[];
extern const uint32_t hist_len;
extern const uint32_t hist_bins;

static const uint32_t expected[4] = {2, 4, 6, 4};

int main(void)
{
    const uint8_t *in   = hist_data;
    uint32_t      *hist = (uint32_t *)0x4000;
    uint32_t       n    = *(volatile const uint32_t *)&hist_len;
    uint32_t       bins = *(volatile const uint32_t *)&hist_bins;
    __asm__ volatile("" : "+r"(in), "+r"(hist), "+r"(n), "+r"(bins));

    BENCH_START();
    for (uint32_t b = 0; b < bins; b++)
        hist[b] = 0;
    for (uint32_t i = 0; i < n; i++)
        hist[in[i]]++;
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int b = 0; b < 4; b++) {
        if (hist[b] != expected[b]) {
            result = CHECK_FAIL(b);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
