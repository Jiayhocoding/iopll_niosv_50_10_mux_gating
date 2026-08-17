# Agilex 5 HVIO IOPLL dual-clock MUX + gating experiment

This is a separate `mux_gating` experiment derived architecturally from
`../iopll_niosv_50_10_glitch_free_mux`. It does not dynamically change the
IOPLL and does not replace the MUX-only baseline.

## Architecture and supported gating resource

Quartus Pro 26.1 Clock Control FPGA IP (`intelclkctrl` 2.0.1) is used for all
clock gating and switching:

```text
50 MHz reference -> HVIO IOPLL (M=64, N=1, VCO=3.2 GHz)
                         | C0=64 -> 50 MHz -> root gate 50 --+
                         | C1=320 -> 10 MHz -> root gate 10 --+-> glitch-free MUX -> GPIO_D[0]
Nios V request -> mux_gating_switch_controller ----------------^ gates/select/markers
```

The two raw IOPLL outputs are generated continuously. Disabling a gate does
not stop C0, C1, the VCO, or the IOPLL. It only blocks that raw output from
propagating into the downstream gated clock path and MUX input.

Each one-input gate is configured with `ENABLE=true`, `ENABLE_TYPE=1` (root
level), and `ENABLE_REGISTER_TYPE=1` (negative latch). The two-input output MUX
has glitch-free switchover enabled. There is no `clk & enable` clock path in
design RTL. This choice follows the Agilex 5 clocking guide: an IOPLL output can
be dynamically gated at the clock network, and root gating stops more of the
downstream clock tree than register clock-enables.

Official references:

- [Agilex 5 Clock Control Features](https://www.intel.com/content/www/us/en/docs/programmable/813671/24-3/clock-control-features.html)
- [Agilex 5 HVIO I/O PLL reconfiguration](https://www.intel.com/content/www/us/en/docs/programmable/813671/24-2/implementing-hvio-i-o-pll-reconfiguration.html)
- [Quartus recommended clock-gating methods](https://www.intel.com/content/www/us/en/docs/programmable/683082/25-1/recommended-clock-gating-methods.html)

## RTL state machine and programmable intervals

Nios V writes one requested-frequency bit (`0=50 MHz`, `1=10 MHz`). It never
bit-bangs gate or select timing. The 50 MHz RTL controller performs:

```text
RUN_50 -> ENABLE_10 -> WAIT_PREPARE_10 -> MARK + MUX_TO_10
       -> WAIT_SWITCH_10 -> disable gate50 -> RUN_10

RUN_10 -> ENABLE_50 -> WAIT_PREPARE_50 -> MARK + MUX_TO_50
       -> WAIT_SWITCH_50 -> disable gate10 -> RUN_50
```

The controller has two compile-time parameters:

```systemverilog
PREPARE_CYCLES      = 4
SWITCH_GUARD_CYCLES = 50
```

Both intervals use the 50 MHz control clock; one cycle is 20 ns. The default
gate-enable-to-MUX-command preparation interval is therefore 80 ns. The target
gate is enabled throughout this interval while the old source continues to
drive the output. `prepare_marker` rises with target gate enable.

At the end of exactly `PREPARE_CYCLES`, `transition_marker` and the MUX select
command change on the same control edge. Thus the transition marker denotes the
actual switchover command, not preparation. `PREPARE_CYCLES=0` intentionally
commands gate enable and MUX selection on the same control edge for the sweep
baseline; the old path still remains enabled during and after this command.

The Clock Control MUX has no completion output. `WAIT_SWITCH_*` therefore keeps
both paths enabled for 50 system cycles = 1 us = ten periods of the slowest
10 MHz source before disabling the old path. The selected source is never
intentionally gated off before the MUX command. Hardware measurements can
justify reducing this conservative guard later.

Initial state is gate 50 enabled, gate 10 disabled, and MUX selecting 50 MHz.
The IOPLL register interface is tied idle; M/N/C0/C1 are fixed and normal
transitions perform no PLL reset, reconfiguration, recalibration, or relock.

## GPIO and oscilloscope procedure

The existing QSF pin assignments were preserved rather than remapped blindly.

| GPIO | Signal | Meaning |
|---|---|---|
| `GPIO_D[0]` | final output | Post-gate glitch-free MUX output |
| `GPIO_D[1]` | `target_iopll_locked` | Raw IOPLL lock indication |
| `GPIO_D[2]` | `mux_select_10mhz` | Actual MUX selection level: 0=50 MHz, 1=10 MHz |
| `GPIO_D[3]` | gated 50 MHz | Post-gating C0 path |
| `GPIO_D[4]` | gated 10 MHz | Post-gating C1 path |
| `GPIO_D[5]` | preparation marker | Rises when the target gate is enabled |

Trigger on either edge of `GPIO_D[2]`. Capture all six channels across
both directions. Confirm the target gated clock starts before the marker, the
old gated clock stops only after output switchover, and lock remains asserted.
Raw IOPLL clocks are available internally as `target_iopll_outclk0/1`; only the
post-gating versions are exported because those are the useful experiment data.

## Measurements

- `T_prepare`: MUX command/`GPIO_D[2]` edge minus preparation-marker rise.
  For nonzero settings it is `PREPARE_CYCLES * 20 ns` by RTL construction.
- `T_enable`: first valid target gated-clock edge minus preparation-marker rise.
- `T_switch`: first valid edge at the new selected frequency minus marker rise.
- `T_gap`: first valid new-frequency edge minus last valid old-frequency edge.
- `T_HIGH_min`, `T_LOW_min`: minimum output pulse widths around the boundary.
- `T_total`: request-to-completed-state controller latency; do not confuse it
  with the externally visible `T_gap`.

`T_total` and `T_gap` are intentionally different. Target preparation overlaps
the still-running old output, so preparation may be hundreds of nanoseconds
while visible interruption remains short. Check for runt/truncated pulses,
stretched cycles, double edges, and missing edges in addition to those metrics.

## Architecture comparison

| Property | A: Dynamic C-counter | B: Dual-clock MUX | C: MUX + gating |
|---|---:|---:|---:|
| Raw clocks pre-generated continuously | No | Yes | Yes |
| Dynamic C divider/reset/recalibration | Yes | No | No |
| Glitch-free Clock Control MUX | No | Yes | Yes |
| Unselected downstream path gated | No | No | Yes |
| PLL expected to stay locked in switch | No | Yes | Yes |

The goal of gating is not faster switching. It tests reduced unnecessary clock
switching activity versus target-clock wake-up/preparation overhead while trying
to keep `T_gap` small. Functional simulation proves neither power reduction nor
analog glitch freedom. Power Analyzer results would be estimates; board power
instrumentation is required for measured savings.

## Build and verification

```bash
quartus_sh --flow compile mux_gating_top
./simulation/run_dual_clock_mux_gating.sh
cmake -S software/nios_mux_gating_switch -B software/nios_mux_gating_switch/build
cmake --build software/nios_mux_gating_switch/build
```

Simulation uses the generated Clock Control MUX model and a negative-latched
behavioral model of the two root gates. It checks startup at 50 MHz, preparation
before selection, delayed old-clock gating, the reverse transition, PLL lock,
minimum 10 ns digital pulse width, and assertions against disabled selected
sources, both sources disabled, and premature old-source gating.

The simulation script automatically sweeps `PREPARE_CYCLES` through
`0, 1, 2, 4, 8, 16, 32`. All seven settings pass. The testbench separately
counts raw C0/C1-model edges while their downstream gates are disabled, proving
that gate state does not control raw clock generation in the model. It also
checks that marker and MUX command coincide, both gates are enabled at the MUX
command, and old-path disable occurs only after the full switch guard.

Quartus 26.1 compile/timing results and relevant clock warnings are recorded
below after each verified build:

- IP generation check: PASS, 0 errors and 0 warnings. Existing generated files
  were current, so Quartus regeneration policy skipped rewriting them.
- Functional simulation/PREPARE sweep: PASS for all seven values.
- Nios V software build: PASS; `nios_mux_gating_switch.elf` rebuilt successfully.
- Full compile: PASS; Fitter successful and `mux_gating_top.sof` generated.
  Worst setup slack is +8.421 ns, worst hold slack is +0.033 ns, and worst
  minimum-pulse-width slack is +3.661 ns (all reported TNS 0). The build uses
  6,155 ALMs, 7,288 registers, and one PLL. Fitter placement confirms
  both gates use Agilex 5 `CLK_GATE` resources. The Clock Control control inputs
  are false-pathed because their dedicated negative-latch/glitch-free circuits
  consume asynchronous commands; ordinary register setup/hold does not describe
  those resource interfaces.
- Timing warnings retained for review: reserved JTAG TCK and the inherited board
  manager 1 Hz divider lack explicit clock assignments; three invalid
  `set_net_delay` warnings originate in generated Nios V debug CDC SDC; Timing
  Analyzer consequently reports the whole board-template design is not fully
  constrained. Design Assistant also reports inherited missing I/O delays and
  asynchronous-reset findings. The final Timing Analyzer reports 0 errors and
  9 warnings, and states timing requirements were met. There are no PLL-setting, invalid-generated-
  clock, missing-exclusive-clock-group, pulse-collapse, setup, hold, or minimum-
  pulse-width violations.

Limitations: the MUX IP exposes no switchover-complete handshake, so old-clock
disable uses a conservative cycle guard. The digital testbench cannot model
clock-tree analog behavior, silicon PVT, oscilloscope loading, or power. Final
claims require hardware pulse-width/latency captures and, for power, matched
Power Analyzer assumptions or physical power measurements.
