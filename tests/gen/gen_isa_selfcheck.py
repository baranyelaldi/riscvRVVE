#!/usr/bin/env python3
"""Generate self-checking ISA tests covering every RVVE encoding.

Writes tests/isa_{alu,mask,misc,mem}_selfcheck.s. Expected values come from
an independent Python reference model of RVV 1.0 semantics (written from the
spec, not from the RTL), so each test checks the RTL against the spec.

Design rules:
  * VLEN-agnostic: every case uses vl <= VLMAX at VLEN=128 and checks only
    body elements (0..vl-1), so the tests also pass at larger VLEN and do not
    depend on the tail policy.
  * Every stored result is followed by a sentinel word that must survive, so
    over-writes past vl are caught.
  * Memory instructions are cross-checked across element widths (e.g. load
    with vle8, store with vse32), so a load bug cannot be masked by a
    matching store bug.
  * Result convention (same as the other selfchecks): ram[0xA000] =
    0x600D600D on PASS, 0xBAD00000 | case_index on the first failing case.

Usage:  python3 tests/gen/gen_isa_selfcheck.py      (from the repo root)
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.dirname(HERE)          # tests/
RESBUF = 0x8000                          # scratch result buffer (free region)
SENTINEL = 0xDEADBEEF

# --------------------------------------------------------------------------
# Reference model helpers
# --------------------------------------------------------------------------
def m(w):
    return (1 << w) - 1

def sx(v, w):
    """Interpret the low w bits of v as a signed integer."""
    v &= m(w)
    return v - (1 << w) if v >> (w - 1) else v

def scalar_to_sew(x, w):
    """RVV: the x-register operand is truncated to SEW (SEW <= XLEN)."""
    return x & m(w)

def simm5_to_sew(imm, w):
    """RVV: 5-bit immediates are sign-extended to SEW."""
    return imm & m(w)

def pack(elems, w):
    """Pack SEW-wide elements little-endian into 32-bit words."""
    data = b"".join((e & m(w)).to_bytes(w // 8, "little") for e in elems)
    assert len(data) % 4 == 0, "case must cover whole words"
    return [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]

ALU = {
    "vadd":  lambda a, b, w: a + b,
    "vsub":  lambda a, b, w: a - b,              # vs2 - op
    "vrsub": lambda a, b, w: b - a,              # op - vs2
    "vmul":  lambda a, b, w: a * b,
    "vminu": lambda a, b, w: min(a & m(w), b & m(w)),
    "vmaxu": lambda a, b, w: max(a & m(w), b & m(w)),
    "vsll":  lambda a, b, w: a << (b & (w - 1)),
    "vsrl":  lambda a, b, w: (a & m(w)) >> (b & (w - 1)),
    "vsra":  lambda a, b, w: sx(a, w) >> (b & (w - 1)),
    "vand":  lambda a, b, w: a & b,
    "vor":   lambda a, b, w: a | b,
    "vxor":  lambda a, b, w: a ^ b,
}
CMP = {
    "vmseq":  lambda a, b, w: (a & m(w)) == (b & m(w)),
    "vmsne":  lambda a, b, w: (a & m(w)) != (b & m(w)),
    "vmsltu": lambda a, b, w: (a & m(w)) < (b & m(w)),
    "vmslt":  lambda a, b, w: sx(a, w) < sx(b, w),
    "vmsleu": lambda a, b, w: (a & m(w)) <= (b & m(w)),
    "vmsle":  lambda a, b, w: sx(a, w) <= sx(b, w),
    "vmsgtu": lambda a, b, w: (a & m(w)) > (b & m(w)),
    "vmsgt":  lambda a, b, w: sx(a, w) > sx(b, w),
}
ALU_FORMS = {
    "vadd": "vv vx vi", "vsub": "vv vx", "vrsub": "vx vi", "vmul": "vv",
    "vmacc": "vv vx", "vminu": "vv vx", "vmaxu": "vv vx",
    "vsll": "vv vx vi", "vsrl": "vv vx vi", "vsra": "vv vx vi",
    "vand": "vv vx vi", "vor": "vv vx vi", "vxor": "vv vx vi",
}
CMP_FORMS = {
    "vmseq": "vv vx vi", "vmsne": "vv vx vi", "vmsltu": "vv vx", "vmslt": "vv vx",
    "vmsleu": "vv vx vi", "vmsle": "vv vx vi", "vmsgtu": "vx vi", "vmsgt": "vx vi",
}
SHIFTS = {"vsll", "vsrl", "vsra"}

# Operand data per SEW: edge values (sign boundary, all-ones, overflow).
DATA = {
    32: dict(vl=4,
             A=[5, 0xFFFFFFFE, 0x7FFFFFFF, 0x80000000],
             B=[3, 7, 1, 0xFFFFFFFF],
             C=[100, 0x80000000, 0xFFFFFFFF, 2],
             x=0xFFFFFFFD, x_sh=33, x_cmp=5),
    16: dict(vl=8,
             A=[5, 0xFFFE, 0x7FFF, 0x8000, 0x1234, 0x00FF, 0xFFFF, 0],
             B=[3, 7, 1, 0xFFFF, 0x0F0F, 0x0100, 15, 0x8000],
             C=[100, 0x8000, 0xFFFF, 2, 0x4321, 1, 0x7FFF, 9],
             x=0x12345, x_sh=19, x_cmp=0x10005),
    8: dict(vl=16,
            A=[5, 0xFE, 0x7F, 0x80, 0x12, 0xF0, 0xFF, 0, 1, 2, 3, 0x40, 0x81, 0xC3, 0x3C, 0x99],
            B=[3, 7, 1, 0xFF, 0x0F, 0x10, 7, 0x80, 0xFE, 2, 0x7F, 0x40, 0x01, 0x5A, 0xA5, 0x66],
            C=[100, 0x80, 0xFF, 2, 9, 0x7F, 0x55, 0xAA, 1, 0, 0xFE, 3, 0x10, 0x20, 0x30, 0x40],
            x=0x1F3, x_sh=0x0B, x_cmp=0x105),
}
IMM_ARITH = -3       # simm5, sign-extended
IMM_SHIFT = 9        # uimm5 (low log2(SEW) bits used)
IMM_CMP = {"vmseq": 5, "vmsne": 5, "vmsleu": -2, "vmsle": -2, "vmsgtu": -2, "vmsgt": -2}

# --------------------------------------------------------------------------
# Assembly emitter
# --------------------------------------------------------------------------
class TestFile:
    def __init__(self, name, title):
        self.name, self.title = name, title
        self.code, self.data, self.cases = [], [], []

    def label(self, kind):
        return f"c{len(self.cases) - 1}_{kind}"

    def words(self, label, ws):
        self.data.append("    .balign 4")
        self.data.append(f"{label}:")
        for i in range(0, len(ws), 4):
            self.data.append("    .word " + ", ".join(f"0x{v & 0xFFFFFFFF:08X}" for v in ws[i:i + 4]))

    def begin(self, desc):
        idx = len(self.cases)
        self.cases.append(desc)
        self.code += ["", f"    # ---- case {idx}: {desc}", f"    li      t3, {idx}"]
        return idx

    def setvl(self, sew, vl):
        self.code += [f"    li      t0, {vl}", f"    vsetvli t1, t0, e{sew}, m1"]

    def load(self, vreg, label, sew):
        self.code += [f"    la      t2, {label}", f"    vle{sew}.v {vreg}, (t2)"]

    def check_vreg(self, vreg, sew, nwords, exp_label):
        """Store vreg (vl elements at SEW) to RESBUF and compare nwords."""
        self.code += [f"    li      a0, {RESBUF}", f"    li      a2, {nwords}", "    jal     ra, prefill",
                      f"    li      a0, {RESBUF}", f"    vse{sew}.v {vreg}, (a0)",
                      f"    la      a1, {exp_label}", f"    li      a2, {nwords}", "    jal     ra, check"]

    def check_scalars(self, regs, exp_label):
        """Store scalar registers to RESBUF and compare."""
        n = len(regs)
        self.code += [f"    li      a0, {RESBUF}", f"    li      a2, {n}", "    jal     ra, prefill",
                      f"    li      a0, {RESBUF}"]
        self.code += [f"    sw      {r}, {4 * i}(a0)" for i, r in enumerate(regs)]
        self.code += [f"    la      a1, {exp_label}", f"    li      a2, {n}", "    jal     ra, check"]

    def write(self):
        lines = [
            "# =============================================================",
            f"# {self.name}.s — GENERATED by tests/gen/gen_isa_selfcheck.py; do not edit.",
            f"# {self.title}",
            "# Expected values come from an independent Python model of RVV 1.0.",
            f"# {len(self.cases)} cases. ram[0xA000] = 0x600D600D (PASS) / 0xBAD00000|case (FAIL).",
            "# =============================================================",
            ".text", ".global _start", "_start:",
        ]
        lines += self.code
        lines += [
            "", "    # ---- all cases passed",
            "    li      t6, 0x600D600D", "    j       report",
            "check_fail:", "    li      t5, 0xBAD00000", "    or      t6, t5, t3",
            "report:", "    li      t0, 0xA000", "    sw      t6, 0(t0)",
            "    li      a0, 0", "    csrw    dscratch, a0", "1:  j       1b",
            "",
            "# prefill: a0 = buffer, a2 = n -> writes n+1 sentinel words",
            "prefill:", f"    li      t5, 0x{SENTINEL:08X}", "    mv      t4, a0", "    addi    t6, a2, 1",
            "2:  sw      t5, 0(t4)", "    addi    t4, t4, 4", "    addi    t6, t6, -1", "    bnez    t6, 2b",
            "    ret",
            "",
            "# check: a0 = buffer, a1 = expected, a2 = n; then buffer[n] must still be the sentinel",
            "check:",
            "3:  beqz    a2, 4f", "    lw      t4, 0(a0)", "    lw      t5, 0(a1)", "    bne     t4, t5, check_fail",
            "    addi    a0, a0, 4", "    addi    a1, a1, 4", "    addi    a2, a2, -1", "    j       3b",
            f"4:  lw      t4, 0(a0)", f"    li      t5, 0x{SENTINEL:08X}", "    bne     t4, t5, check_fail",
            "    ret",
            "",
            "# ---- data",
        ]
        lines += self.data
        path = os.path.join(OUT_DIR, self.name + ".s")
        with open(path, "w") as f:
            f.write("\n".join(lines) + "\n")
        print(f"wrote {path}: {len(self.cases)} cases")

# --------------------------------------------------------------------------
# Case builders
# --------------------------------------------------------------------------
def alu_case(t, op, form, sew):
    d = DATA[sew]; vl, w = d["vl"], sew
    A, B, C = d["A"][:vl], d["B"][:vl], d["C"][:vl]
    t.begin(f"{op}.{form} e{sew} vl={vl}")
    la, lb, lc, le = t.label("a"), t.label("b"), t.label("c"), t.label("exp")
    t.words(la, pack(A, w))
    t.setvl(sew, vl)
    t.load("v2", la, sew)
    if form == "vv":
        t.words(lb, pack(B, w)); t.load("v1", lb, sew)
        ops = B
    elif form == "vx":
        x = d["x_sh"] if op in SHIFTS else d["x"]
        t.code.append(f"    li      a3, 0x{x:X}")
        ops = [scalar_to_sew(x, w)] * vl
    else:  # vi
        imm = IMM_SHIFT if op in SHIFTS else IMM_ARITH
        ops = [(imm if op in SHIFTS else simm5_to_sew(imm, w))] * vl
    src = {"vv": "v1", "vx": "a3"}.get(form, str(IMM_SHIFT if op in SHIFTS else IMM_ARITH))
    if op == "vmacc":
        t.words(lc, pack(C, w)); t.load("v3", lc, sew)
        exp = [(c + o * a) for a, o, c in zip(A, ops, C)]
        t.code.append(f"    vmacc.{form} v3, {src}, v2")       # vd += op * vs2
    else:
        exp = [ALU[op](a, o, w) for a, o in zip(A, ops)]
        t.code.append(f"    {op}.{form} v3, v2, {src}")
    t.words(le, pack(exp, w))
    t.check_vreg("v3", sew, vl * sew // 32, le)

def cmp_case(t, op, form, sew):
    d = DATA[sew]; vl, w = d["vl"], sew
    A, B = d["A"][:vl], d["B"][:vl]
    t.begin(f"{op}.{form} e{sew} vl={vl}")
    la, lb, le = t.label("a"), t.label("b"), t.label("exp")
    t.words(la, pack(A, w))
    t.setvl(sew, vl)
    t.load("v2", la, sew)
    if form == "vv":
        t.words(lb, pack(B, w)); t.load("v1", lb, sew); ops, src = B, "v1"
    elif form == "vx":
        t.code.append(f"    li      a3, 0x{d['x_cmp']:X}")
        ops, src = [scalar_to_sew(d["x_cmp"], w)] * vl, "a3"
    else:
        imm = IMM_CMP[op]; ops, src = [simm5_to_sew(imm, w)] * vl, str(imm)
    t.code.append(f"    {op}.{form} v3, v2, {src}")
    bits = sum(1 << i for i, (a, o) in enumerate(zip(A, ops)) if CMP[op](a, o, w))
    read_mask_bits(t, "v3", vl)
    t.words(le, [bits]); t.check_scalars(["a4"], le)

def read_mask_bits(t, vreg, nbits):
    """a4 = low nbits of a mask register (via vmv.x.s at e32, vl=1)."""
    t.code += ["    li      t0, 1", "    vsetvli t1, t0, e32, m1", f"    vmv.x.s a4, {vreg}",
               f"    li      a5, 0x{(1 << nbits) - 1:X}", "    and     a4, a4, a5"]

def load_mask(t, vreg, value):
    lbl = t.label(vreg)
    t.words(lbl, [value])
    t.code += ["    li      t0, 1", "    vsetvli t1, t0, e32, m1", f"    la      t2, {lbl}", f"    vle32.v {vreg}, (t2)"]

# --------------------------------------------------------------------------
def build_alu():
    t = TestFile("isa_alu_selfcheck",
                 "Integer arithmetic, shifts, logical: all 32 encodings at e32 and e8; .vv at e16.")
    for sew in (32, 8):
        for op, forms in ALU_FORMS.items():
            for form in forms.split():
                alu_case(t, op, form, sew)
    for op, forms in ALU_FORMS.items():
        if "vv" in forms.split():
            alu_case(t, op, "vv", 16)
    t.write()

def build_mask():
    t = TestFile("isa_mask_selfcheck",
                 "Mask compares (20, at e32 and e8), mask logicals (4), mask reductions (2).")
    for sew in (32, 8):
        for op, forms in CMP_FORMS.items():
            for form in forms.split():
                cmp_case(t, op, form, sew)
    M1, M2 = 0xA5C3, 0x0FF0
    logic = {"vmand": lambda a, b: a & b, "vmor": lambda a, b: a | b,
             "vmxor": lambda a, b: a ^ b, "vmnand": lambda a, b: ~(a & b)}
    for nbits, sew in ((16, 8), (4, 32)):
        for op, f in logic.items():
            t.begin(f"{op}.mm vl={nbits} (e{sew})")
            load_mask(t, "v1", M1); load_mask(t, "v2", M2)
            t.setvl(sew, nbits)
            t.code.append(f"    {op}.mm v3, v2, v1")
            read_mask_bits(t, "v3", nbits)
            le = t.label("exp"); t.words(le, [f(M2, M1) & ((1 << nbits) - 1)]); t.check_scalars(["a4"], le)
    red = [("vcpop.m", 0xA5C3, 16, 8, bin(0xA5C3).count("1")),
           ("vcpop.m", 0xA5C3, 6, 8, bin(0xA5C3 & 0x3F).count("1")),     # bits >= vl ignored
           ("vcpop.m", 0xF, 4, 32, 4),
           ("vfirst.m", 0xA5C0, 16, 8, 6),
           ("vfirst.m", 0x0000, 16, 8, 0xFFFFFFFF),                       # none set -> -1
           ("vfirst.m", 0x0100, 8, 8, 0xFFFFFFFF),                        # first set bit >= vl -> -1
           ("vfirst.m", 0x4, 4, 32, 2)]
    for op, mask, vl, sew, exp in red:
        t.begin(f"{op} mask=0x{mask:X} vl={vl} (e{sew})")
        load_mask(t, "v1", mask)
        t.setvl(sew, vl)
        t.code.append(f"    {op} a4, v1")
        le = t.label("exp"); t.words(le, [exp]); t.check_scalars(["a4"], le)
    t.write()

def build_misc():
    t = TestFile("isa_misc_selfcheck",
                 "vsetvli/vsetivli + vl/vtype/vlenb CSRs, vredsum.vs, vmv.v.x/vmv.x.s/vmv.s.x, vid.v.")
    # ---- configuration (VLEN-agnostic: VLMAX checked against vlenb)
    t.begin("vsetvli AVL=3 e32: rd=vl=3, vtype=0x10 (tu,mu)")
    t.code += ["    li      t0, 3", "    vsetvli a4, t0, e32, m1", "    csrr    a5, vl", "    csrr    a3, vtype"]
    le = t.label("exp"); t.words(le, [3, 3, 0x10]); t.check_scalars(["a4", "a5", "a3"], le)

    t.begin("vsetvli rs1=x0 e8: rd = VLMAX_e8 = vlenb, vtype=0x00")
    t.code += ["    vsetvli a4, x0, e8, m1", "    csrr    a5, vlenb", "    sub     a4, a4, a5", "    csrr    a3, vtype"]
    le = t.label("exp"); t.words(le, [0, 0x00]); t.check_scalars(["a4", "a3"], le)

    t.begin("vsetvli AVL=1000 e16 ta,ma: rd = VLMAX_e16 = vlenb/2, vtype=0xC8")
    t.code += ["    li      t0, 1000", "    vsetvli a4, t0, e16, m1, ta, ma", "    csrr    a5, vlenb",
               "    srli    a5, a5, 1", "    sub     a4, a4, a5", "    csrr    a3, vtype"]
    le = t.label("exp"); t.words(le, [0, 0xC8]); t.check_scalars(["a4", "a3"], le)

    t.begin("vsetivli AVL=5 e16: rd=vl=5")
    t.code += ["    vsetivli a4, 5, e16, m1", "    csrr    a5, vl"]
    le = t.label("exp"); t.words(le, [5, 5]); t.check_scalars(["a4", "a5"], le)

    t.begin("vsetvli rd=x0,rs1=x0 keeps vl (3)")
    t.code += ["    li      t0, 3", "    vsetvli zero, t0, e32, m1", "    vsetvli zero, x0, e32, m1", "    csrr    a4, vl"]
    le = t.label("exp"); t.words(le, [3]); t.check_scalars(["a4"], le)

    t.begin("vsetivli AVL=0: rd=vl=0")
    t.code += ["    vsetivli a4, 0, e32, m1", "    csrr    a5, vl"]
    le = t.label("exp"); t.words(le, [0, 0]); t.check_scalars(["a4", "a5"], le)

    t.begin("vsetvli e64 (unsupported): vill=1, vl=0, vtype=0x80000000")
    t.code += ["    li      t0, 4", "    vsetvli a4, t0, e64, m1", "    csrr    a5, vl", "    csrr    a3, vtype"]
    le = t.label("exp"); t.words(le, [0, 0, 0x80000000]); t.check_scalars(["a4", "a5", "a3"], le)

    # ---- vredsum.vs: vd[0] = vs1[0] + sum(vs2[0..vl-1]) (mod 2^SEW), read via vmv.x.s
    for sew in (32, 16, 8):
        d = DATA[sew]; vl, w = d["vl"], sew
        A = d["A"][:vl]; init = d["C"][0]
        t.begin(f"vredsum.vs e{sew} vl={vl} (+ vmv.x.s sign-extension)")
        la, lb, le = t.label("a"), t.label("b"), t.label("exp")
        t.words(la, pack(A, w))
        t.words(lb, pack([init] + [0] * (vl - 1), w))
        t.setvl(sew, vl); t.load("v2", la, sew); t.load("v1", lb, sew)
        t.code += ["    vredsum.vs v3, v2, v1", "    vmv.x.s a4, v3"]
        t.words(le, [sx(init + sum(A), w) & 0xFFFFFFFF]); t.check_scalars(["a4"], le)

    # ---- vmv.v.x (scalar truncated to SEW, broadcast to vl elements)
    for sew, x in ((32, 0xDEADBEEF), (16, 0x12345), (8, 0x1A5)):
        vl = DATA[sew]["vl"]
        t.begin(f"vmv.v.x e{sew} x=0x{x:X}")
        t.setvl(sew, vl); t.code += [f"    li      a3, 0x{x:X}", "    vmv.v.x v3, a3"]
        le = t.label("exp"); t.words(le, pack([x & m(sew)] * vl, sew)); t.check_vreg("v3", sew, vl * sew // 32, le)

    # ---- vmv.x.s: element 0, sign-extended from SEW
    for sew, e0 in ((32, 0x80000001), (16, 0x8001), (8, 0x80)):
        vl = DATA[sew]["vl"]
        t.begin(f"vmv.x.s e{sew} elem0=0x{e0:X}")
        la = t.label("a"); t.words(la, pack([e0] + [0x11] * (vl - 1), sew))
        t.setvl(sew, vl); t.load("v2", la, sew); t.code.append("    vmv.x.s a4, v2")
        le = t.label("exp"); t.words(le, [sx(e0, sew) & 0xFFFFFFFF]); t.check_scalars(["a4"], le)

    # ---- vmv.s.x: writes element 0 only (body elements 1..vl-1 untouched is NOT
    #      required by the spec — vmv.s.x ignores vl except vl=0 — so only elem 0 is checked)
    t.begin("vmv.s.x e32 x=0xCAFEBABE (elem 0)")
    t.code += ["    li      t0, 1", "    vsetvli t1, t0, e32, m1", "    li      a3, 0xCAFEBABE", "    vmv.s.x v3, a3"]
    le = t.label("exp"); t.words(le, [0xCAFEBABE]); t.check_vreg("v3", 32, 1, le)
    t.begin("vmv.s.x e8 x=0x1F0 -> elem0 = 0xF0 (read back sign-extended)")
    t.code += ["    li      t0, 16", "    vsetvli t1, t0, e8, m1", "    li      a3, 0x1F0", "    vmv.s.x v3, a3",
               "    vmv.x.s a4, v3"]
    le = t.label("exp"); t.words(le, [0xFFFFFFF0]); t.check_scalars(["a4"], le)

    # ---- vid.v: element i = i
    for sew in (32, 16, 8):
        vl = DATA[sew]["vl"]
        t.begin(f"vid.v e{sew} vl={vl}")
        t.setvl(sew, vl); t.code.append("    vid.v   v3")
        le = t.label("exp"); t.words(le, pack(list(range(vl)), sew)); t.check_vreg("v3", sew, vl * sew // 32, le)
    t.write()

def build_mem():
    t = TestFile("isa_mem_selfcheck",
                 "Unit-stride vle/vse 8/16/32 cross-checked across widths; strided vlse32/vsse32.")
    src = [0x13121110, 0x17161514, 0x1B1A1918, 0x1F1E1D1C, 0x23222120, 0x27262524]
    # (load SEW, load vl, store SEW, store vl): each pair moves exactly 3 words
    pairs = [(32, 3, 32, 3), (8, 12, 32, 3), (16, 6, 32, 3), (32, 3, 8, 12), (32, 3, 16, 6)]
    for ls, lvl, ss, svl in pairs:
        t.begin(f"vle{ls} (vl={lvl}) -> vse{ss} (vl={svl})")
        la = t.label("src"); t.words(la, src)
        t.setvl(ls, lvl); t.load("v2", la, ls)
        t.setvl(ss, svl)
        le = t.label("exp"); t.words(le, src[:3]); t.check_vreg("v2", ss, 3, le)
    # strided load: stride 8 bytes picks words 0, 2, 4
    t.begin("vlse32 stride=8 -> vse32")
    la = t.label("src"); t.words(la, src)
    t.setvl(32, 3); t.code += [f"    la      t2, {la}", "    li      a3, 8", "    vlse32.v v2, (t2), a3"]
    le = t.label("exp"); t.words(le, [src[0], src[2], src[4]]); t.check_vreg("v2", 32, 3, le)
    # strided store: stride 12 bytes -> words 0, 3, 6; gaps keep the sentinel
    t.begin("vsse32 stride=12 (gap words untouched)")
    la = t.label("src"); t.words(la, src)
    t.code += [f"    li      a0, {RESBUF}", "    li      a2, 7", "    jal     ra, prefill"]
    t.setvl(32, 3)
    t.code += [f"    la      t2, {la}", "    vle32.v v2, (t2)", f"    li      a0, {RESBUF}", "    li      a3, 12",
               "    vsse32.v v2, (a0), a3"]
    S = SENTINEL
    le = t.label("exp"); t.words(le, [src[0], S, S, src[1], S, S, src[2]])
    t.code += [f"    li      a0, {RESBUF}", f"    la      a1, {le}", "    li      a2, 7", "    jal     ra, check"]
    t.write()

if __name__ == "__main__":
    build_alu(); build_mask(); build_misc(); build_mem()
