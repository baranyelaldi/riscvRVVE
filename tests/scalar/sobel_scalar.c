// sobel_scalar.c — RV32IM scalar baseline for tests/sobel_selfcheck.s
//
// Same 3 padded rows, same output (4 Gx values at 0x4000), same expected
// {240, 80, 80, -280}. Sobel-Gx for output column c (padded index c+1):
//   Gx[c] = (A + 2B + C)[c+2] - (A + 2B + C)[c]
#include "bench.h"

extern const int32_t  sob_rowA[];
extern const int32_t  sob_rowB[];
extern const int32_t  sob_rowC[];
extern const uint32_t sob_cols;

static const int32_t expected[4] = {240, 80, 80, -280};

int main(void)
{
    const int32_t *a    = sob_rowA;
    const int32_t *b    = sob_rowB;
    const int32_t *c    = sob_rowC;
    int32_t       *gx   = (int32_t *)0x4000;
    uint32_t       cols = *(volatile const uint32_t *)&sob_cols;
    __asm__ volatile("" : "+r"(a), "+r"(b), "+r"(c), "+r"(gx), "+r"(cols));

    BENCH_START();
    for (uint32_t x = 0; x < cols; x++) {
        int32_t left  = a[x]     + 2 * b[x]     + c[x];
        int32_t right = a[x + 2] + 2 * b[x + 2] + c[x + 2];
        gx[x] = right - left;
    }
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int x = 0; x < 4; x++) {
        if (gx[x] != expected[x]) {
            result = CHECK_FAIL(x);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
