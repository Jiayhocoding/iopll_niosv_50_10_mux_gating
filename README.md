# Agilex 5 HVIO IOPLL Dual-Clock MUX + Root Gating

**Nios V controlled 50 MHz ↔ 10 MHz clock switching using two continuously running HVIO IOPLL outputs, Agilex 5 root clock gates, and a glitch-free Clock Control MUX.**

> **Design principle:** software chooses the target frequency; RTL owns the timing.  
> **Switch sequence:** enable target path → prepare → command MUX → guard → disable old path.

This repository is the **MUX + gating experiment**. It does **not** dynamically reconfigure the IOPLL during a normal 50 MHz ↔ 10 MHz transition.

---

## Experiment at a glance

| Item | This design |
|---|---|
| FPGA clock source | HVIO IOPLL |
| Raw outputs | 50 MHz (`C0=64`) and 10 MHz (`C1=320`) |
| VCO | 3.2 GHz (`M=64`, `N=1`) |
| Clock switching | 2:1 glitch-free `intelclkctrl` MUX |
| Clock gating | Two root-level `intelclkctrl` gates |
| Software control | One requested-frequency bit from Nios V |
| Timing owner | 50 MHz RTL FSM |
| Default prepare interval | `4 × 20 ns = 80 ns` |
| Default switch guard | `50 × 20 ns = 1 µs` |
| PLL reconfiguration during switch | **None** |
| Primary measurement | `GPIO_D[2]` MUX select vs. `GPIO_D[0]` output |

### Experimental question

Can the unselected downstream clock path be gated while preserving a controlled, glitch-free clock-source transition and keeping the IOPLL running continuously?

The experiment separates three effects that are easy to confuse:

1. **Raw clock generation** — both IOPLL outputs keep running.
2. **Clock-path availability** — root gates decide whether each raw clock reaches the MUX.
3. **Output selection** — the glitch-free MUX decides which available source reaches the output.

---

## 1. System architecture

### Clock plane + control plane

```mermaid
flowchart LR
    subgraph CP["Control plane"]
        SW["Nios V software<br/>requested frequency<br/>0 = 50 MHz / 1 = 10 MHz"]
        FSM["mux_gating_switch_controller<br/>50 MHz RTL FSM"]
        SW --> FSM
    end

    subgraph KP["Clock plane"]
        REF["50 MHz reference"] --> PLL["HVIO IOPLL<br/>M=64, N=1<br/>VCO=3.2 GHz"]
        PLL -->|"C0=64"| RAW50["raw_clk_50<br/>50 MHz<br/>always running"]
        PLL -->|"C1=320"| RAW10["raw_clk_10<br/>10 MHz<br/>always running"]
        RAW50 --> G50["Root Gate 50<br/>intelclkctrl"]
        RAW10 --> G10["Root Gate 10<br/>intelclkctrl"]
        G50 --> MUX["Glitch-free 2:1 MUX<br/>intelclkctrl"]
        G10 --> MUX
        MUX --> OUT["GPIO_D[0]<br/>final clock output"]
    end

    FSM -->|"gate50_en"| G50
    FSM -->|"gate10_en"| G10
    FSM -->|"mux_select"| MUX

    PLL -. "locked" .-> LOCK["GPIO_D[1]"]
    FSM -. "MUX select" .-> SEL["GPIO_D[2]"]
    G50 -. "gated 50 MHz" .-> D3["GPIO_D[3]"]
    G10 -. "gated 10 MHz" .-> D4["GPIO_D[4]"]
    FSM -. "prepare marker" .-> D5["GPIO_D[5]"]
```

### The most important distinction

```mermaid
flowchart LR
    RAW["IOPLL raw output<br/>still toggling"] --> GATE{"Root gate"}
    GATE -->|"disabled"| STOP["Downstream path blocked"]
    GATE -->|"enabled"| PASS["Clock reaches MUX input"]
```

**Gate disabled ≠ IOPLL clock stopped.** The gate only blocks propagation into the downstream clock network. C0, C1, and the VCO continue running.

### Design invariants

These rules define the intended behavior of every valid transition:

- both raw IOPLL outputs continue running,
- the target gated path is enabled **before** the MUX command,
- both gated sources are available at the MUX command,
- the selected source is never intentionally gated off before switchover,
- the old gated path is disabled only after the full switch guard,
- IOPLL lock is expected to remain asserted,
- no PLL reset, C-counter update, recalibration, or relock is part of a normal switch.

---

## 2. Switching sequence

A frequency change is a **make-before-break** operation at the gated clock-path level.

```mermaid
flowchart LR
    A["1. Request target"] --> B["2. Enable target gate"]
    B --> C["3. Wait PREPARE_CYCLES"]
    C --> D["4. Command MUX"]
    D --> E["5. Keep both gates ON<br/>SWITCH_GUARD_CYCLES"]
    E --> F["6. Disable old gate"]
    F --> G["7. Run target frequency"]
```

### Forward and reverse transitions

| Phase | 50 → 10 MHz | 10 → 50 MHz |
|---|---|---|
| Initial | gate50 ON, gate10 OFF, MUX=50 | gate50 OFF, gate10 ON, MUX=10 |
| Wake target path | enable gate10 | enable gate50 |
| Prepare | wait `PREPARE_CYCLES` | wait `PREPARE_CYCLES` |
| MUX command | `mux_select=1` | `mux_select=0` |
| Guard | both gates ON | both gates ON |
| Cleanup | disable gate50 | disable gate10 |
| Final | gate50 OFF, gate10 ON, MUX=10 | gate50 ON, gate10 OFF, MUX=50 |

### Why the guard exists

The Clock Control MUX has no switchover-complete output. The controller therefore cannot observe the exact internal completion instant. It keeps both clock paths available for a conservative fixed interval, then disables the old gated path.

The guard is **not** the measured switching latency. Actual output switchover is determined from `GPIO_D[0]`.

---

## 3. RTL state machine

```mermaid
stateDiagram-v2
    [*] --> RUN_50

    RUN_50 --> ENABLE_10: request = 10 MHz
    ENABLE_10 --> WAIT_PREPARE_10: gate10 = ON
    WAIT_PREPARE_10 --> MUX_TO_10: prepare complete
    MUX_TO_10 --> WAIT_SWITCH_10: mux_select = 1
    WAIT_SWITCH_10 --> RUN_10: guard complete / gate50 = OFF

    RUN_10 --> ENABLE_50: request = 50 MHz
    ENABLE_50 --> WAIT_PREPARE_50: gate50 = ON
    WAIT_PREPARE_50 --> MUX_TO_50: prepare complete
    MUX_TO_50 --> WAIT_SWITCH_50: mux_select = 0
    WAIT_SWITCH_50 --> RUN_50: guard complete / gate10 = OFF
```

Equivalent RTL sequence:

```text
RUN_50 -> ENABLE_10 -> WAIT_PREPARE_10 -> MUX_TO_10
       -> WAIT_SWITCH_10 -> RUN_10

RUN_10 -> ENABLE_50 -> WAIT_PREPARE_50 -> MUX_TO_50
       -> WAIT_SWITCH_50 -> RUN_50
```

Nios V writes only the requested-frequency bit. It does **not** bit-bang gate enables or MUX timing.

---

## 4. Timing model

The controller uses a 50 MHz clock:

```text
T_control = 1 / 50 MHz = 20 ns
```

Default parameters:

```systemverilog
PREPARE_CYCLES      = 4
SWITCH_GUARD_CYCLES = 50
```

Therefore:

```text
T_prepare(default) = 4  × 20 ns = 80 ns
T_guard(default)   = 50 × 20 ns = 1 µs
```

The 1 µs guard equals ten periods of the slowest 10 MHz source.

### 50 MHz → 10 MHz timing concept

```text
Time  ------------------------------------------------------------------------>

request_10       0 _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

gate10_en        0 _________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                          |<-- 80 ns -->|

mux_select       0 _____________________|‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
                                             ^
                                             | MUX command
                                             |<---- 1 µs guard ---->|

gate50_en        1 ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___

GPIO_D[0]          50 MHz ---------[ actual switchover ]---------- 10 MHz
```

The old 50 MHz clock continues driving the output during preparation. The MUX command occurs only after the target 10 MHz gated path has been made available.

`PREPARE_CYCLES=0` is intentionally supported as a sweep baseline: target gate enable and MUX command occur on the same control edge, while the old path still remains enabled through the guard.

---

## 5. What to trigger on

For output switching behavior, use the signal that actually commands the MUX:

> **Trigger reference = `GPIO_D[2]` (`mux_select_10mhz`)**

Do not use `prepare_marker` as the primary output-switch trigger. The marker answers a different question: **when did preparation begin?**

### Minimum two-channel measurement

```mermaid
flowchart LR
    TRIG["CH1: GPIO_D[2]<br/>MUX select"] -->|"rising edge"| FWD["50 → 10 command"]
    TRIG -->|"falling edge"| REV["10 → 50 command"]
    FWD --> OBS["CH2: GPIO_D[0]<br/>find first valid edge<br/>at new frequency"]
    REV --> OBS
```

- `GPIO_D[2] = 0` → MUX commands 50 MHz.
- `GPIO_D[2] = 1` → MUX commands 10 MHz.
- Rising edge on D2 → 50 MHz → 10 MHz command.
- Falling edge on D2 → 10 MHz → 50 MHz command.

### Full validation view

| GPIO | Pin | Signal | Why observe it |
|---|---|---|---|
| `GPIO_D[0]` | `PIN_BK31` | final output | Actual switched clock |
| `GPIO_D[1]` | `PIN_BE43` | `target_iopll_locked` | Confirm PLL remains locked |
| `GPIO_D[2]` | `PIN_BF29` | `mux_select_10mhz` | Actual MUX command / trigger |
| `GPIO_D[3]` | `PIN_BF40` | gated 50 MHz | Confirm 50 MHz path availability |
| `GPIO_D[4]` | `PIN_BK28` | gated 10 MHz | Confirm 10 MHz path availability |
| `GPIO_D[5]` | `PIN_BM31` | preparation marker | Measure preparation interval |

For a six-channel capture, verify that the target gated clock appears before the D2 MUX-select edge, the old gated path remains active through the switchover, and PLL lock stays asserted.

### Hardware capture: 50 MHz → 10 MHz

The following oscilloscope capture shows the forward transition at three time scales: an overall view, a zoomed view, and a close-up of the switching boundary.

![Hardware oscilloscope capture of the 50 MHz to 10 MHz clock transition](docs/images/hardware_50_to_10_transition.jpg)

**Channel interpretation**

- **CH1 / yellow:** `GPIO_D[0]` — final post-MUX clock output.
- **CH2 / blue:** `GPIO_D[2]` — `mux_select_10mhz`, used as the external switch-command reference.
- The CH2 rising edge corresponds to the **50 MHz → 10 MHz MUX command**.
- The yellow waveform changes from the faster 50 MHz region to the slower 10 MHz region after the command boundary.

These captures are primarily **qualitative hardware evidence** of the requested transition. At the displayed millisecond-scale timebases, the nominal 50 MHz and 10 MHz square waves are heavily undersampled by the oscilloscope display, so the yellow trace should not be interpreted as the actual clock waveform shape or used directly for nanosecond-level pulse-width claims.

> **Important:** the on-screen cursor `ΔX` values in these captures are not automatically treated as `T_switch` or `T_gap`. Those metrics must be measured with the cursors placed on the exact events defined in the next section, using an appropriate high-sample-rate / short-timebase acquisition.

---

## 6. Measurement definitions

```mermaid
flowchart LR
    P["prepare_marker rises"] -->|"T_prepare"| S["GPIO_D[2] MUX command"]
    S -->|"T_switch"| N["first valid new-frequency edge"]
    O["last valid old-frequency edge"] -->|"T_gap"| N
```

| Metric | Definition | What it tells us |
|---|---|---|
| `T_prepare` | D2 MUX-command edge − prepare-marker rise | Intentional target-path preparation |
| `T_enable` | First valid target gated-clock edge − prepare-marker rise | Gate/path wake-up behavior |
| `T_switch` | First valid new-frequency output edge − D2 edge | Actual MUX/output response |
| `T_gap` | First valid new-frequency edge − last valid old-frequency edge | Visible boundary interruption |
| `T_HIGH_min` | Minimum HIGH pulse width near boundary | Runt/truncated HIGH check |
| `T_LOW_min` | Minimum LOW pulse width near boundary | Runt/truncated LOW check |
| `T_total` | Request → completed FSM state | Controller-level latency |

For nonzero settings:

```text
T_prepare = PREPARE_CYCLES × 20 ns
```

`T_total` and `T_gap` are deliberately different. Preparation overlaps the still-running old output, so a long preparation interval does not imply an equally long visible output gap.

Also inspect for **runt pulses, truncated pulses, stretched cycles, double edges, and missing edges**.

---

## 7. Clock resources

Quartus Pro 26.1 Clock Control FPGA IP (`intelclkctrl` 2.0.1) is used for both gating and clock selection.

Each one-input clock gate is configured with:

```text
ENABLE=true
ENABLE_TYPE=1
ENABLE_REGISTER_TYPE=1
```

This selects root-level gating with the dedicated negative-latch behavior. The output uses a two-input Clock Control MUX with glitch-free switchover enabled.

There is **no `clk & enable` clock path in user RTL**.

The IOPLL register interface is tied idle during this experiment. M/N/C0/C1 stay fixed across normal transitions.

Official references:

- [Agilex 5 Clock Control Features](https://www.intel.com/content/www/us/en/docs/programmable/813671/24-3/clock-control-features.html)
- [Agilex 5 HVIO I/O PLL reconfiguration](https://www.intel.com/content/www/us/en/docs/programmable/813671/24-2/implementing-hvio-i-o-pll-reconfiguration.html)
- [Quartus recommended clock-gating methods](https://www.intel.com/content/www/us/en/docs/programmable/683082/25-1/recommended-clock-gating-methods.html)

---

## 8. Architecture comparison

| Property | A: Dynamic C-counter | B: Dual-clock MUX | C: MUX + gating |
|---|---:|---:|---:|
| Raw clocks pre-generated continuously | No | Yes | Yes |
| Dynamic C-divider / reset / recalibration | Yes | No | No |
| Glitch-free Clock Control MUX | No | Yes | Yes |
| Unselected downstream path gated | No | No | Yes |
| PLL expected to stay locked during switch | No | Yes | Yes |

This design is **Architecture C**.

The purpose of gating is **not to make the MUX switch faster**. The experiment studies the tradeoff between reducing unnecessary downstream clock activity and adding target-path preparation / cleanup control while trying to keep the visible transition clean.

See [`COMPARISON.md`](COMPARISON.md) for the broader architecture comparison.

---

## 9. Verification status

### Current verified build

| Check | Result |
|---|---|
| IP generation | **PASS** — 0 errors, 0 warnings |
| Functional simulation | **PASS** |
| `PREPARE_CYCLES` sweep | **PASS** for `0, 1, 2, 4, 8, 16, 32` |
| Nios V software build | **PASS** |
| Quartus full compile | **PASS** |
| Fitter output | `mux_gating_top.sof` generated |
| Worst setup slack | `+8.421 ns` |
| Worst hold slack | `+0.033 ns` |
| Worst min pulse-width slack | `+3.661 ns` |
| TNS | `0` |
| Clock-gate placement | Both gates mapped to Agilex 5 `CLK_GATE` resources |

Resource use from the verified compile:

```text
6,155 ALMs
7,288 registers
1 PLL
```

### Simulation checks

The testbench verifies:

- startup at 50 MHz,
- target preparation before selection,
- both gated sources available at the MUX command,
- delayed old-clock disable,
- reverse transition,
- PLL lock,
- minimum 10 ns digital pulse width,
- no selected disabled source,
- no state with both clock sources disabled,
- no premature old-source gating,
- raw C0/C1 model clocks continue toggling even when downstream gates are disabled.

Hardware measurements use `GPIO_D[2]` as the switch reference, not the internal transition marker.

### Timing-analysis warnings retained for review

The final Timing Analyzer reports **0 errors and 9 warnings** and states timing requirements were met, but the inherited board-template design is not fully constrained.

Known warning sources include:

- reserved JTAG TCK and inherited board-manager 1 Hz divider without explicit clock assignments,
- three invalid `set_net_delay` warnings from generated Nios V debug CDC SDC,
- inherited missing I/O delays,
- asynchronous-reset findings.

There are no reported PLL-setting, invalid-generated-clock, missing-exclusive-clock-group, pulse-collapse, setup, hold, or minimum-pulse-width violations in the verified build.

---

## 10. Build and run

`software/nios_mux_gating_switch` is the application for this experiment. It changes only the requested-frequency PIO; it does not issue IOPLL runtime reconfiguration, reset, or recalibration commands.

Generate/update `software/nios_bsp` locally from the Platform Designer system before building the application. Generated BSP/build products are excluded from Git.

```bash
quartus_sh --flow compile mux_gating_top
./simulation/run_dual_clock_mux_gating.sh
cmake -S software/nios_mux_gating_switch -B software/nios_mux_gating_switch/build
cmake --build software/nios_mux_gating_switch/build
```

The software changes the requested frequency every 1 second; all nanosecond-scale gate/MUX sequencing is performed in RTL.

---

## 11. Repository map

```text
.
├── README.md                         # experiment overview, switching flow, measurement method
├── COMPARISON.md                     # architecture comparison
├── mux_gating_top.v                  # FPGA top-level integration
├── mux_gating_top.qsf                # Quartus assignments / GPIO pins
├── mux_gating_top.sdc                # timing constraints
├── mux_gating_control_system.qsys    # Platform Designer / Nios V system
├── docs/images/                      # hardware oscilloscope captures used by README
├── rtl/
│   ├── mux_gating_switch_controller.sv  # precise gate + MUX FSM
│   ├── nios_iopll_bridge.sv
│   └── hvio_master.sv
├── simulation/                       # functional simulation and PREPARE sweep
└── software/
    └── nios_mux_gating_switch/       # Nios V request application
```

If you want to understand the clock-switch behavior first, read in this order:

```text
README.md
   ↓
rtl/mux_gating_switch_controller.sv
   ↓
mux_gating_top.v
   ↓
simulation/
   ↓
COMPARISON.md
```

---

## 12. Limitations and claim boundary

This repository demonstrates the **digital control architecture** and verifies the intended sequencing, but several conclusions require physical measurement.

- The MUX IP exposes no switchover-complete handshake; old-path disable therefore uses a fixed conservative guard.
- Functional simulation cannot prove analog clock-tree glitch freedom on silicon.
- Functional simulation cannot model silicon PVT, oscilloscope loading, or board-level power.
- Final pulse-width, glitch, and switching-latency claims require oscilloscope captures.
- Final power-savings claims require matched Power Analyzer assumptions or physical board power measurements.

### What this experiment can claim now

**Verified digitally:** control ordering, make-before-break path availability, FSM behavior, simulation assertions, successful compile, positive reported setup/hold/min-pulse slack.

### What still requires hardware evidence

**Measure physically:** `T_switch`, `T_gap`, minimum boundary pulse widths, actual glitch behavior, and power impact.

---

## One-sentence model

> **Both IOPLL clocks always run; RTL wakes the target gated path, commands the glitch-free MUX, waits a guard interval, and only then gates off the old downstream path.**
