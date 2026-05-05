###############################################################################
## Tool paths
###############################################################################
VERILATOR_SRC ?= /opt/homebrew/opt/verilator/share/verilator/include
SYSTEMC_HOME  ?= /opt/homebrew/opt/systemc
SYSTEMC_INCLUDE ?= $(SYSTEMC_HOME)/include
SYSTEMC_LIBDIR  ?= $(SYSTEMC_HOME)/lib

TEST_IMAGE ?= ../../isa_sim/images/basic.elf

CORE       ?= riscv

export VERILATOR_SRC
export SYSTEMC_HOME
export SYSTEMC_INCLUDE
export SYSTEMC_LIBDIR

###############################################################################
## Makefile
###############################################################################
.PHONY: all build clean run

all: build

build:
	make -C ../../isa_sim lib
	make -f makefile.generate_verilated CORE=$(CORE)
	make -f makefile.build_verilated
	make -f makefile.build_sysc_tb

clean:
	make -f makefile.generate_verilated  CORE=$(CORE) $@
	make -f makefile.build_verilated $@
	make -f makefile.build_sysc_tb $@
	-rm *.vcd

run: build
	./build/test.x -f $(TEST_IMAGE)
