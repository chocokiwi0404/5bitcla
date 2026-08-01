# 5-Bit Domino-Logic Adder — TSMC 180nm

A 5-bit adder built around a **dynamic (domino) CMOS Manchester carry chain**, with clocked TSPC-style flip-flops pipelining the inputs and outputs. The design is implemented and verified across three flows:

1. **Schematic-level SPICE** — pre-layout functional/timing simulation in `ngspice`
2. **Physical layout** — drawn in `Magic`, with **post-layout** (parasitic-extracted) `ngspice` simulation
3. **RTL** — a behavioral `Verilog` model for logical/functional cross-checking

> This README is a starting template based on the schematic netlist (`.sp`) you shared. Section headers marked 🔧 reference file paths/names I inferred generically — swap in your actual folder/file names and I'll tighten this up.

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

## 2. Repository Structure 🔧

```
.
├── spice/
│   ├── adder_5bit.sp            # schematic-level netlist (pre-layout)
│   ├── TSMC_180nm.txt           # process model file
│   └── results/                 # .raw / plots from pre-layout runs
├── layout/
│   ├── adder_5bit.mag           # Magic layout
│   ├── adder_5bit.ext           # extracted netlist (parasitics)
│   ├── adder_5bit_post.sp       # post-layout netlist (spice-extracted, back-annotated)
│   └── results/                 # post-layout sim outputs
├── verilog/
│   ├── adder_5bit.v             # behavioral/RTL model
│   ├── tb_adder_5bit.v          # testbench
│   └── results/                 # simulation logs / waveforms (.vcd)
└── README.md
```

*(Replace with your actual file/folder names — happy to regenerate this section once you confirm them.)*

---

## 3. Tools / Requirements

- [`ngspice`](https://ngspice.sourceforge.io/) — for both pre- and post-layout simulation
- [`Magic VLSI`](http://opencircuitdesign.com/magic/) — layout editing, DRC, and parasitic extraction (`ext2spice`)
- A Verilog simulator, e.g. [`Icarus Verilog`](http://iverilog.icarus.com/) (`iverilog` + `vvp`) or `Verilator`
- `TSMC_180nm.txt` SPICE model file (not redistributed here — obtain via your PDK access)

---

## 4. Running the Simulations

### 4.1 Pre-layout (schematic) — ngspice

```bash
cd spice
ngspice adder_5bit.sp
```

The `.control` block runs the transient analysis automatically and plots `clk`, `s0..s4`, and `cout`. To dump results instead of an interactive plot, add a `write` command inside the `.control` block, e.g. `write adder_5bit.raw`.

### 4.2 Post-layout — Magic + ngspice

1. Open/verify the layout in Magic and run DRC:
   ```bash
   magic adder_5bit.mag
   ```
2. Extract the netlist with parasitics:
   ```
   extract all
   ext2spice lvs
   ext2spice
   ```
3. Simulate the extracted netlist the same way as the schematic version:
   ```bash
   ngspice adder_5bit_post.sp
   ```
4. Compare `s0..s4` / `cout` timing against the pre-layout run to see the impact of layout parasitics (wire RC, extra diffusion/junction caps) on delay through the dynamic carry chain.

### 4.3 Verilog (behavioral check)

```bash
cd verilog
iverilog -o sim adder_5bit.v tb_adder_5bit.v
vvp sim
```

This is a functional (not timing) cross-check — useful for confirming `sum`/`carry` logic independent of the dynamic-logic/clocking implementation details in the SPICE version.

---

## 5. Verification Notes

- Because the carry chain is **dynamic**, correctness depends on the clocking discipline: nodes must be precharged (`clk = 0`) before they're evaluated/discharged (`clk = 1`), and downstream `ff` stages must sample only after their driving stage has settled. Keep this in mind if you change the clock period — too fast a clock relative to the technology's propagation delay will produce incorrect sums/carries.
- The `ff` blocks introduce a pipeline latency between input application and the corresponding sum/carry appearing at the outputs — the Verilog testbench should account for the same latency (in clock cycles) if you're doing a cycle-accurate comparison against the SPICE runs.
- Suggested exhaustive-ish test plan: sweep multiple `A`/`B` value pairs (not just the single `A=11111, B=00001` case in the current netlist) across pre-layout, post-layout, and Verilog to confirm functional equivalence, then compare **pre- vs post-layout delay** specifically (critical path is the carry ripple through all 5 `dyno` stages).

---

## 6. Author / License 🔧

- Author: *your name*
- Course/project context: *fill in if relevant*
- License: *fill in (e.g. MIT)*
