# Loading RVVE Core onto Nexys A7 100T (Vivado)

## Board Overview

| Item | Detail |
|------|--------|
| FPGA | Artix-7 XC7A100T-1CSG324C |
| Vivado part string | `xc7a100tcsg324-1` |
| On-board clock | 100 MHz, pin E3 |
| CPU reset button | Active-low, pin C2 |
| USB-UART TX (FPGA→PC) | Pin D4 |
| USB-UART RX (PC→FPGA) | Pin C4 |

---

## 1. RTL Files to Add

Add every `.v` under these two directories **except** `riscv_trace_sim.v` (simulation-only, uses `$display`/`$fwrite`):

```
core/riscv/*.v              (exclude riscv_trace_sim.v)
top_tcm_axi/src_v/*.v       (riscv_tcm_top.v + tcm_mem*.v + dport*.v)
```

**Important parameter:** set `SUPPORT_REGFILE_XILINX = 1` on the core instance. This maps the scalar register file to Xilinx RAMB primitives via `riscv_xilinx_2r1w.v`, which is critical for synthesis quality.

---

## 2. Board-Level Wrapper (`nexys_top.v`)

`riscv_tcm_top` has two external AXI ports that need decisions:

| Port | What it is | Action on bare FPGA |
|------|-----------|---------------------|
| `axi_t_*` (AXI4 slave) | Loads data into TCM | Tie to idle, or wire a UART bootloader |
| `axi_i_*` (AXI4-Lite master) | CPU peripheral access (0x8000_0000+) | Map to UART TX + optional LED register |

Create a `nexys_top.v` wrapper that:

1. Instantiates `riscv_tcm_top`
2. Ties `axi_t_*` slave inputs to idle:
   - `awvalid = 0`, `wvalid = 0`, `arvalid = 0`
   - `bready = 1`, `rready = 1`
3. Decodes `axi_i_*` master writes to a simple UART transmitter
   - Writing to `0x8000_0000` → send byte (matches `sim_putc` convention)
4. Drives `intr_i = 32'b0` (no external interrupts)
5. Inverts the active-low reset button for the active-high `rst_i` / `rst_cpu_i`

---

## 3. Getting Your Program into BRAM

The TCM is a 64 KB BRAM. Two options:

### Option A — Pre-initialise at synthesis (recommended to start)

Convert your ELF to a hex file:

```bash
riscv64-unknown-elf-objcopy -O verilog program.elf program.mem
```

Then edit `tcm_mem_ram.v` to load it:

```verilog
initial $readmemh("program.mem", mem);
```

Vivado bakes the contents into the BRAM init attributes — the program is in the bitstream and runs immediately on power-up.

### Option B — UART bootloader

Wire the `axi_t_*` slave to a UART receiver that accepts raw binary and writes it to TCM. Hold `rst_cpu_i` high until the load is complete, then release. More flexible but significantly more work.

---

## 4. XDC Constraints

Minimum viable constraints file:

```tcl
# 100 MHz system clock
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# CPU reset button (active-low — invert in wrapper)
set_property PACKAGE_PIN C2 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# UART
set_property PACKAGE_PIN D4 [get_ports uart_tx]
set_property PACKAGE_PIN C4 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx uart_rx}]
```

---

## 5. Timing

With the RVVE vector extension the design is larger than the upstream scalar-only core. The upstream core meets 100 MHz comfortably on Artix-7; with the vector ALU/LSU added, timing may be tighter.

**Recommended approach:**

- Start at **50 MHz** — add a Vivado Clock Wizard IP (MMCM) to divide 100 MHz by 2. Confirm correctness before pushing frequency.
- After a passing implementation, check the timing report's critical path. It is typically through the vector ALU or multiplier chain.
- To push toward 100 MHz, add retiming (`RETIMING` synthesis strategy) or pipeline the vector ALU.

---

## 6. Vivado Project Steps

1. **New Project** → RTL Project → add the source files listed in §1
2. **Part:** `xc7a100tcsg324-1`
3. **Set Top:** your `nexys_top` wrapper module
4. **Add XDC** constraints file from §4
5. **Synthesis settings:** Flatten Hierarchy = `rebuilt` (helps timing analysis visibility)
6. Run **Synthesis → Implementation → Generate Bitstream**
7. **Program** via Vivado Hardware Manager over USB-JTAG

---

## 7. Debug Strategy

- The `axi_i_*` UART path lets tests output characters via the `sim_putc` CSR convention (`csrw dscratch` with high byte `0x01`) — the same tests that pass in simulation will produce serial output on hardware.
- Add a Vivado **ILA (Integrated Logic Analyzer)** probe on:
  - `ifetch_pc` — confirms the CPU is fetching correctly
  - Vector instruction decode signals — confirms RVVE decode
  - `axi_i_*` master channel — confirms peripheral writes reach UART
- Start by running a minimal scalar test (no vector instructions) to confirm boot and UART before testing RVVE.

---

## 8. Work Summary

| Task | Estimated effort |
|------|-----------------|
| `nexys_top.v` wrapper (tie-offs + AXI-to-UART decode) | 1–2 hours |
| UART TX module (if you don't already have one) | ~1 hour |
| BRAM init flow (`elf → mem → $readmemh`) | ~30 min |
| XDC constraints file | ~30 min |
| Clock Wizard IP for 50 MHz start | ~15 min (Vivado GUI) |
| Synthesis + implementation run | ~10–20 min compute |

The biggest single piece of work is `nexys_top.v` with the AXI-Lite-to-UART peripheral decode.
