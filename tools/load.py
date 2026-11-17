#!/usr/bin/env python3
"""Load a program into the Nexys A7 RISC-V core over the UART, then show its output.

Usage (Windows):
    py tools\\load.py COM7 tests\\uart\\memcpy_selfcheck_uart.mem
    py tools\\load.py COM7 tests\\uart\\memcpy_selfcheck_uart.mem --baud 115200

The .mem file is the one written by `make mem X.elf` (objcopy -O verilog
--verilog-data-width=4): '@' lines are WORD addresses, data tokens are 32-bit
word values. The script turns it into a full 64KB TCM image (unused words = 0),
sends it after the "RVLD" sync marker, and then keeps the port open and prints
everything the board sends until Ctrl+C. The board's uart_loader (see
top_nexys_test/uart_loader.v) holds the CPU in reset during the transfer and
releases it afterwards, so the program starts from 0x2000 straight away.

Needs pyserial on the Windows side:  py -m pip install pyserial
Only one program can open the COM port at a time - close PuTTY first.
"""

import argparse
import sys
import time

TCM_WORDS = 16384           # 64KB
SYNC = b"RVLD"              # must match SYNC_WORD in uart_loader.v
BOOT_WORD = 0x2000 // 4     # reset vector as a word address


def read_mem(path):
    """Parse an objcopy verilog .mem file into a list of TCM_WORDS words."""
    image = [0] * TCM_WORDS
    addr = None
    first_addr = None
    with open(path) as f:
        for line_no, line in enumerate(f, 1):
            for tok in line.split():
                if tok.startswith("//"):
                    break
                if tok.startswith("@"):
                    addr = int(tok[1:], 16)
                    if first_addr is None:
                        first_addr = addr
                    continue
                if addr is None:
                    sys.exit(f"{path}:{line_no}: data before the first '@' address")
                if len(tok) > 8 or len(tok) % 2:
                    sys.exit(f"{path}:{line_no}: unexpected token '{tok}' "
                             "(expected 32-bit words: make mem uses --verilog-data-width=4)")
                if addr >= TCM_WORDS:
                    sys.exit(f"{path}:{line_no}: word address 0x{addr:X} "
                             f"(byte 0x{addr * 4:X}) is outside the 64KB TCM")
                image[addr] = int(tok, 16)
                addr += 1
    if first_addr is None:
        sys.exit(f"{path}: no data found")
    if first_addr == BOOT_WORD * 4:
        print(f"warning: first address is @{first_addr:08X}; this looks like a BYTE "
              f"address (expected word address @{BOOT_WORD:08X} for 0x2000)")
    return image


def build_stream(image):
    """Sync marker followed by the image, each word little-endian."""
    return SYNC + b"".join(w.to_bytes(4, "little") for w in image)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("port", nargs="?", help="serial port, e.g. COM7")
    ap.add_argument("mem", help=".mem file from `make mem X.elf`")
    ap.add_argument("--baud", type=int, default=115200,
                    help="must match UART_BAUD_RATE in nexys_top.v (default 115200)")
    ap.add_argument("--dump", metavar="FILE",
                    help="write the byte stream to FILE instead of sending it (for simulation)")
    args = ap.parse_args()

    stream = build_stream(read_mem(args.mem))

    if args.dump:
        with open(args.dump, "wb") as f:
            f.write(stream)
        print(f"wrote {len(stream)} bytes to {args.dump}")
        return
    if not args.port:
        ap.error("a serial port is required unless --dump is used")

    try:
        import serial
    except ImportError:
        sys.exit("pyserial is not installed - run:  py -m pip install pyserial")

    try:
        ser = serial.Serial(args.port, args.baud, timeout=0.1)
    except serial.SerialException as e:
        sys.exit(f"cannot open {args.port}: {e}\n(is PuTTY or another terminal still using it?)")

    with ser:
        ser.reset_input_buffer()
        secs = len(stream) * 10 / args.baud
        print(f"Loading {args.mem} to {args.port} @ {args.baud} baud (~{secs:.1f} s)...",
              end="", flush=True)
        t0 = time.time()
        chunk = 4096
        for i in range(0, len(stream), chunk):
            ser.write(stream[i:i + chunk])
        ser.flush()                       # wait until everything is on the wire
        print(f" done in {time.time() - t0:.1f} s")
        print("---- board output (Ctrl+C to quit) ----")

        try:
            while True:
                data = ser.read(256)
                if data:
                    sys.stdout.write(data.decode("ascii", errors="replace"))
                    sys.stdout.flush()
        except KeyboardInterrupt:
            print("\n---- closed ----")


if __name__ == "__main__":
    main()
