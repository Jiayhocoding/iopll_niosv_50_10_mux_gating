# IOPLL switching experiment comparison

## Architectures

| Item | A. Dynamic C-counter | B. Pre-generated MUX-only | C. Pre-generated MUX + gating |
|---|---|---|---|
| Project | `../iopll_niosv_runtime_50to10_codex` | `../iopll_niosv_50_10_glitch_free_mux` | this directory |
| Raw 50/10 MHz clocks | One output reconfigured between rates | Both generated continuously | Both generated continuously |
| Normal switch changes M/N/C0/C1 | C0 changes | No | No |
| PLL reset/recalibration | Yes | No | No |
| Glitch-free Clock Control MUX | No | Yes | Yes |
| Unselected downstream path | Not applicable | Continues propagating | Blocked by dedicated root gate |
| Target preparation | PLL reconfiguration/relock | Already active | Enable target gate and wait `PREPARE_CYCLES` |
| Old path removal | Frequency source itself changes | Never gated | Gated only after MUX command and switch guard |
| Expected lock during switch | May deassert | Remains asserted | Remains asserted |

In experiment C, disabling a gate does not stop the IOPLL VCO or C counter.
It only blocks propagation through that downstream clock path.

## Measurement definitions

Use identical probes, bandwidth, threshold, acquisition mode, and clock hold
times for experiments B and C.

| Metric | Definition | Required evidence |
|---|---|---|
| `T_switch` | first valid new-frequency output edge minus `GPIO_D[2]` MUX-select edge | Oscilloscope, both directions |
| `T_gap` | first valid new-frequency edge minus last valid old-frequency edge | Oscilloscope, both directions |
| `T_prepare` | `GPIO_D[2]` MUX-select edge minus preparation-marker rise | GPIO_D[2] minus GPIO_D[5] |
| Minimum HIGH/LOW | shortest stable output HIGH and LOW around switch | Oscilloscope pulse statistics |
| Pulse integrity | runt, truncated, stretched, double, or missing edges | Deep capture around both transitions |
| PLL lock | lock remains asserted throughout preparation/switch/gating | GPIO_D[1] capture |
| Switching activity | downstream clock activity when unselected | Signal Tap and/or Power Analyzer activity assumptions |
| Power | matched-estimate or measured board power delta | Label clearly as estimate or measurement |

## Current verified results

| Check | B. MUX-only | C. MUX + gating |
|---|---:|---:|
| Existing Quartus full compile | PASS | PASS |
| Existing functional simulation | PASS | PASS |
| C `PREPARE_CYCLES` sweep | N/A | PASS: 0, 1, 2, 4, 8, 16, 32 |
| Worst setup slack | +8.678 ns (prior build) | +8.421 ns |
| Worst hold slack | +0.018 ns (prior build) | +0.033 ns |
| Worst minimum pulse-width slack | +3.857 ns (prior build) | +3.661 ns |
| Hardware `T_switch` | Not measured here | Not measured here |
| Hardware `T_gap` | Not measured here | Not measured here |
| Hardware pulse integrity | Not measured here | Not measured here |
| Hardware/estimated power delta | Not measured here | Not measured here |

Quartus timing success and digital simulation do not prove analog glitch
freedom on a board. The research question can only be answered after filling
the hardware rows above for each preparation setting.

## PREPARE_CYCLES sweep worksheet

At 50 MHz, one preparation cycle is 20 ns. `transition_marker` and the MUX
select command change on the same controller edge.

| `PREPARE_CYCLES` | Programmed `T_prepare` | 50→10 `T_switch` | 50→10 `T_gap` | 10→50 `T_switch` | 10→50 `T_gap` | Min H/L | Clean? |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 0 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 1 | 20 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 2 | 40 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 4 | 80 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 8 | 160 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 16 | 320 ns | TBD | TBD | TBD | TBD | TBD | TBD |
| 32 | 640 ns | TBD | TBD | TBD | TBD | TBD | TBD |

The minimum acceptable value is the smallest row that has clean pulse
integrity in both directions and a `T_gap` statistically comparable with the
MUX-only baseline.
