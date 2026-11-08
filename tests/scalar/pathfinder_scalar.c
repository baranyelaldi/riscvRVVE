// pathfinder_scalar.c — RV32IM scalar baseline for tests/pathfinder_selfcheck.s
//
// Same padded previous row, same grid weights, same output (4 costs at 0x4000),
// same expected {6, 7, 6, 7}. One Rodinia pathfinder DP step:
//   dst[j] = grid[j] + min_u(src[j-1], src[j], src[j+1])   (unsigned, INF halo)
// RV32IM has no minu instruction, so the compiler uses compares/branches.
#include "bench.h"

extern const uint32_t pf_src[];   // padded: pf_src[j..j+2] = left, center, right
extern const uint32_t pf_grid[];
extern const uint32_t pf_cols;

static const uint32_t expected[4] = {6, 7, 6, 7};

static inline uint32_t minu(uint32_t a, uint32_t b) { return a < b ? a : b; }

int main(void)
{
    const uint32_t *src  = pf_src;
    const uint32_t *grid = pf_grid;
    uint32_t       *dst  = (uint32_t *)0x4000;
    uint32_t        cols = *(volatile const uint32_t *)&pf_cols;
    __asm__ volatile("" : "+r"(src), "+r"(grid), "+r"(dst), "+r"(cols));

    BENCH_START();
    for (uint32_t j = 0; j < cols; j++)
        dst[j] = grid[j] + minu(minu(src[j + 1], src[j + 2]), src[j]);
    BENCH_STOP();

    uint32_t result = CHECK_PASS;
    for (int j = 0; j < 4; j++) {
        if (dst[j] != expected[j]) {
            result = CHECK_FAIL(j);
            break;
        }
    }
    RESULT_CHECK = result;
    return 0;
}
