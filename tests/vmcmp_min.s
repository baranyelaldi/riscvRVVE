.text
.global _start
_start:
    # Setup mem with test pattern: {3, 5, 7, 5}
    li      t0, 0x2000
    li      t1, 3;  sw t1, 0(t0)
    li      t1, 5;  sw t1, 4(t0)
    li      t1, 7;  sw t1, 8(t0)
    li      t1, 5;  sw t1, 12(t0)

    # v1 = {5, 5, 5, 5}; v2 = {3, 5, 7, 5}
    li      t1, 5
    vmv.v.x v1, t1
    vle32.v v2, (t0)

    # vmseq.vv v3, v2, v1 — bit i = (v2[i] == v1[i])
    # {3==5, 5==5, 7==5, 5==5} = {0,1,0,1} → bit3=1, bit2=0, bit1=1, bit0=0 → 0b1010 = 0xA
    vmseq.vv v3, v2, v1

    # vmsne.vv v4, v2, v1 — opposite of vmseq
    # → 0b0101 = 0x5
    vmsne.vv v4, v2, v1

    # vmsltu.vv v5, v2, v1 — bit i = (v2[i] < v1[i] unsigned)
    # {3<5, 5<5, 7<5, 5<5} = {1,0,0,0} → 0b0001 = 0x1
    vmsltu.vv v5, v2, v1

    # vmsleu.vx v6, v2, t1 — bit i = (v2[i] <= 5 unsigned)
    # {3<=5, 5<=5, 7<=5, 5<=5} = {1,1,0,1} → 0b1011 = 0xB
    vmsleu.vx v6, v2, t1

    # vmsgtu.vx v7, v2, t1 — bit i = (v2[i] > 5 unsigned)
    # {3>5, 5>5, 7>5, 5>5} = {0,0,1,0} → 0b0100 = 0x4
    vmsgtu.vx v7, v2, t1

    # vmseq.vi v8, v2, 7 — bit i = (v2[i] == 7)
    # {0,0,1,0} → 0x4
    vmseq.vi v8, v2, 7

    # Exit — inspect vregs_q[3-8] in GTKWave
    li      a0, 0
    csrw    dscratch, a0
1:  j       1b
