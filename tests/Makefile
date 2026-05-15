# RVVE test programs (RV32IV target).
# Each test is a .s file directly in this directory.
#
# Usage:
#   make NAME.elf           # assemble + auto-disassemble
#   make run NAME.elf       # build (if stale) + run via testbench; opens GTKWave if not running
#   make dump NAME.elf      # disassemble a previously built elf
#   make clean NAME.{s,elf} # remove only this test's elf
#   make build              # force rebuild of test.x after Verilog/tb edits
#
# Examples:
#   make vadd.elf
#   make run vadd.elf
#   make dump addi.elf
#   make clean vadd.s
#   make build              # after editing anything under core/ or top_tcm_axi/

ARCH    := rv32iv
ABI     := ilp32
TEXT    := 0x2000

TB_DIR  := ../top_tcm_axi/tb
TB_BIN  := $(TB_DIR)/build/test.x
GTKW    := $(TB_DIR)/verilator.gtkw

GCC     := riscv64-unknown-elf-gcc
OBJDUMP := riscv64-unknown-elf-objdump

# --- Two-arg target handling (run/dump/clean take a filename) -------
# `make run X.elf` is parsed by make as two goals. The second one is
# turned into a no-op so make doesn't complain that there's no rule.
TWOARG := run dump clean
ifneq (,$(filter $(TWOARG),$(firstword $(MAKECMDGOALS))))
  ARGFILE := $(word 2,$(MAKECMDGOALS))
  $(eval $(ARGFILE):;@:)
endif

# Normalize the argument to .elf (accept either .s or .elf input)
ELF := $(patsubst %.s,%.elf,$(ARGFILE))

# --- Rules ----------------------------------------------------------
%.elf: %.s
	$(GCC) -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -Ttext=$(TEXT) -o $@ $<
	@echo "--- $@ disassembly ---"
	@$(OBJDUMP) -d $@

# Build (if needed) then run through the testbench. test.x is invoked
# from $(TB_DIR) so its VCD output lands next to verilator.gtkw.
# GTKWave is launched only if no instance is already running.
run: $(ELF)
	cd $(TB_DIR) && ./build/test.x -f $(abspath $(ELF))
	@pgrep -x gtkwave >/dev/null 2>&1 || gtkwave $(GTKW) >/dev/null 2>&1 &

dump: $(ELF)
	$(OBJDUMP) -d $(ELF)

clean:
	rm -f $(ELF)

# Force a full Verilator + tb rebuild. Use after editing any .v file or any
# tb source under top_tcm_axi/tb/. The upstream tb makefile's "build" target
# collides with its own build/ directory, so we always use `make -B`.
build:
	cd $(TB_DIR) && env -u NAME SYSTEMC_HOME=/usr LIB_OPT= \
	    EXTRA_CFLAGS="-Wno-error -L/usr/lib/x86_64-linux-gnu" \
	    make -B

.PHONY: run dump clean build
