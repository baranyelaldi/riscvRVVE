# tests/scalar — RV32IM scalar baselines for the vector benchmarks.
#
# Baseline policy (state this in the paper):
#   * Same input data, output location, and self-check as the vector test.
#   * Natural scalar algorithm for the same result, written in freestanding C
#     and compiled by GCC -O2 for rv32im (the core has a hardware multiplier).
#     A compiler-generated baseline avoids "hand-written slow baseline" doubts.
#   * Measured with the same instret/cycle wrapper as the vector tests
#     (bench.h), reported by the testbench as [CYCLES] / [INSTRET].
#
# Usage (from this directory):
#   make                      # build every *_scalar.elf + its .gen.s listing
#   make run NAME=memcpy      # run NAME_scalar.elf through the testbench
#   make clean

CC      := riscv64-unknown-elf-gcc
# zicsr: GCC 13 lists the CSR instructions (cycle/instret reads) separately;
# the vector tests get it implicitly from V. Same RV32IM core ISA.
ARCH    := rv32im_zicsr
ABI     := ilp32
# -fno-builtin / -fno-tree-loop-distribute-patterns: stop GCC from turning
#   copy loops into calls to memcpy (there is no libc with -nostdlib).
# -msmall-data-limit=0: no .sdata, so no gp register setup is needed.
CFLAGS  := -O2 -march=$(ARCH) -mabi=$(ABI) -ffreestanding -fno-builtin \
           -fno-tree-loop-distribute-patterns -msmall-data-limit=0 -Wall
LDFLAGS := -nostdlib -nostartfiles -T link.ld

TB_DIR  := ../../top_tcm_axi/tb

SRCS    := $(wildcard *_scalar.c)
ELFS    := $(SRCS:.c=.elf)
GENS    := $(SRCS:.c=.gen.s)

all: $(ELFS) $(GENS)

%_scalar.elf: %_scalar.c %_scalar_data.s crt0.s bench.h link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ crt0.s $*_scalar.c $*_scalar_data.s

# Compiler-generated assembly of the kernel, for review and for the record
%_scalar.gen.s: %_scalar.c bench.h
	$(CC) $(CFLAGS) -S -o $@ $<

run: $(NAME)_scalar.elf
	cd $(TB_DIR) && ENABLE_WAVES=no ./build/test.x -f $(abspath $<)

clean:
	rm -f *.elf

.PHONY: all run clean
