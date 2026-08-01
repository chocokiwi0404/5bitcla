# 5-Bit Domino-Logic Adder — TSMC 180nm

A 5-bit adder built around a **dynamic (domino) CMOS Manchester carry chain**, with clocked TSPC-style flip-flops pipelining the inputs and outputs. The design is implemented and verified across three flows:

1. **Schematic-level SPICE** — pre-layout functional/timing simulation in `ngspice`
2. **Physical layout** — drawn in `Magic`, with **post-layout** (parasitic-extracted) `ngspice` simulation
3. **RTL** — a behavioral `Verilog` model for logical/functional cross-checking

Repo: **`5bitcla`** — schematic sims live in `5bcla/`, Magic layouts + extracted cells live in `magicccccc/`, and the RTL model is `clav.v`.

---

## 1. Circuit Overview

The adder computes `A + B` for two 5-bit operands (`a0..a4`, `b0..b4`), clocked, using dynamic logic for the carry chain to minimize the carry propagation delay (the classic domino/Manchester-carry-chain trick — precharge the carry node, then conditionally discharge it based on propagate/generate signals rather than rippling through static full adders).

### Building blocks (subcircuits)

| Subckt | Role |
|---|---|
| `notg` | Static CMOS inverter |
| `andg` | Static AND gate (NAND + inverter) |
| `xor` | Static CMOS XOR (transmission-gate style) |
| `dyno` | **Dynamic carry cell.** Precharges the carry node `con` high when `clk = 0` (via `M4`); on `clk = 1` it conditionally discharges through `M1`/`M2`/`M3` based on propagate (`pi`), generate (`gi`), and the incoming carry (`cin`) — this is the Manchester carry chain element |
| `ff` | Clocked master–slave flip-flop (TSPC-style, built from clocked inverter stages) used to register/pipeline signals between dynamic evaluate phases |
| `onecla` | **One-bit adder slice.** Registers `ai`/`bi` through `ff`, computes propagate `pi = ai ⊕ bi` and generate `gi = ai·bi`, feeds the dynamic carry cell (`dyno`) to produce `cout`, and computes/register the sum bit `si` |

### Top-level structure

Five `onecla` slices are chained ripple-style (`co0 → co1 → co2 → co3 → co4`), each carry passing through a dynamic (domino) stage rather than a static full adder, which is what gives this style of adder its speed advantage over a plain ripple-carry adder. The initial carry-in and final carry-out are each passed through their own `ff`/`notg` stages to keep timing consistent with the internal pipeline.

```
a0,b0,cin ─▶ onecla ─▶ co0 ─▶ onecla ─▶ co1 ─▶ onecla ─▶ co2 ─▶ onecla ─▶ co3 ─▶ onecla ─▶ co4 ─▶ cout (registered)
              │s0                │s1                │s2                │s3                │s4
```

### Process / sizing

- Technology: **TSMC 180nm** (`TSMC_180nm.txt` model include)
- `LAMBDA = 0.09u`
- NMOS width: `width_N = 20·LAMBDA`; PMOS width: `Wp = 2·width_N` (standard 2:1 P:N ratio for balanced rise/fall)
- Channel length: `2·LAMBDA` on all devices
- Supply: `VDS = 1.8V`

### Testbench (in the provided `.sp`)

- `A = a4..a0 = 11111` (all inputs tied to `vdd`)
- `B = b4..b0 = 00001` (only `b0` tied high, rest to `gnd`)
- Clock: `PULSE(0 1.8 2n 1p 1p 2n 4n)` → 4ns period, 2ns pulse width, starts at 2ns
- Transient analysis: `0.1n` step, `80n` stop
- Plotted signals: `clk`, `s0..s4` (offset for visibility), `cout`

---

## 2. Repository Structure

```
5bitcla/
├── 5bcla/                        # ngspice schematic-level sims (pre- and post-layout)
│   ├── TSMC_180nm.txt            # process model file
│   ├── SCN6M_DEEP.09.tech27      # Magic tech file (also copied here for convenience)
│   ├── pggen.cir                 # propagate/generate gate (pi = a⊕b, gi = a·b)
│   ├── xorg.cir                  # standalone XOR gate test
│   ├── ff.cir / ff.log           # single flip-flop (ff subckt) test + log
│   ├── ff1bit_tb.spice           # 1-bit flip-flop testbench
│   ├── onebitcla_post.cir/.log   # single onecla (1-bit adder slice) — POST-layout, extracted
│   ├── fullcla5_pre.cir/.log     # full 5-bit adder — PRE-layout (this is the netlist covered in §1)
│   └── cla5_postmagic.cir/.log   # full 5-bit adder — POST-layout, extracted from Magic
│
├── magicccccc/                   # Magic layouts + extracted (.ext) and SPICE (.spice) netlists per cell
│   ├── SCN6M_DEEP.09.tech27      # Magic tech file
│   ├── nmos.mag/.ext, pmos.mag/.ext          # base devices
│   ├── inverter.mag/.ext/.spice              # + spare copies ("inverter (Copy).mag", etc.)
│   ├── doubleinv.mag/.ext                    # buffer / clock-buffer inverter pair
│   ├── buffer.ext/.spice
│   ├── nandg.mag/.ext/.spice                 # NAND (used inside andg)
│   ├── xorg.mag/.ext/.spice                  # XOR gate layout
│   ├── xorh.mag, "xorh (Copy).mag", xorha.mag  # XOR variants/iterations
│   ├── ff.mag/.ext/.spice                    # flip-flop layout
│   ├── manch.mag/.ext/.spice                 # Manchester carry (dyno) dynamic cell layout
│   ├── fulladd.mag/.ext/.spice               # full-adder cell layout
│   ├── 1bitaddie.mag/.ext/.spice             # 1-bit adder slice (onecla) layout
│   ├── all.mag                               # combined/top-level layout view
│   └── toomanyinv.mag                        # scratch/inverter chain test cell
│
├── clav.v                        # Verilog behavioral model of the 5-bit adder
└── README.md
```

**Notes on the layout:**
- `5bcla/` is the ngspice side: `fullcla5_pre.cir` is the pre-layout schematic netlist, and `cla5_postmagic.cir` is the same circuit extracted from the Magic layout, i.e. the post-layout run with parasitics back-annotated. `onebitcla_post.cir` is a smaller, single-slice post-layout sanity check before simulating the full 5-bit chain.
- `magicccccc/` is the Magic side: individual cells (`nmos`, `pmos`, `inverter`, `nandg`, `xorg`/`xorh`, `ff`, `manch`, `fulladd`) are laid out and extracted separately, then composed into the full adder (`1bitaddie` → the 1-bit top level, `all.mag` → the 5-bit top level).
- `clav.v` is a single-file Verilog model — a behavioral description of the same 5-bit adder used to cross-check functionality independent of the transistor-level implementation.

---

## 3. Tools / Requirements

- [`ngspice`](https://ngspice.sourceforge.io/) — for both pre- and post-layout simulation
- [`Magic VLSI`](http://opencircuitdesign.com/magic/) — layout editing, DRC, and parasitic extraction (`ext2spice`)
- A Verilog simulator, e.g. [`Icarus Verilog`](http://iverilog.icarus.com/) (`iverilog` + `vvp`) or `Verilator`
- `TSMC_180nm.txt` — SPICE model file (in `5bcla/`)
- `SCN6M_DEEP.09.tech27` — Magic technology file (in `magicccccc/`, also copied into `5bcla/`)

---
