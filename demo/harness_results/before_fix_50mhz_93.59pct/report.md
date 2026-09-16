# Demo Evaluation Report - ZUGA-IC

- Date: 2026-09-16T19:25:57+03:00
- Harness version: 1.0.2
- Configuration source: `takim_icd.json`
- Effective configuration: `config_used.json` (SHA256 `9f0df69d99a0985d`)
- Dataset: public_dataset/manifest.csv | seed: 1337
- Interfaces: stream `/dev/ttyUSB2@115200`, core `/dev/ttyUSB2@115200`

## 1. Summary - RTL / Golden Model Agreement

> **The primary check is not model accuracy; it is fidelity of the design to the golden model.**
> The primary metric checks whether the hardware class matches the class produced by
> the golden model for the same vector. The ground-truth label (truth) is reported only
> as additional information and is not used for scoring.

| Metric | Value |
|---|---|
| Samples sent | 156 |
| Samples with golden reference | 156 |
| Responses received | 156 |
| **Golden agreement** | 93.59 %  (146/156) |
| Mismatches | 10 |
| Timeouts (samples with reference) | 0 |
| Strict agreement (timeouts counted as errors) | 93.59 % |
| Latency (median / p95 / max) | 56.10 / 62.06 / 66.20 ms |
| Robustness scenarios | 0 / 0 |

> Note: latency is measured from the end of frame transmission to receipt of the final
> byte of the result. It includes UART transfer and ISR time. For pure accelerator
> cycle counts, RTL-simulation cross-checking is the authoritative method.

## 2. Agreement Matrix (rows = golden reference, columns = hardware output)

| golden \ hardware | silence | unknown | yes | no | TIMEOUT |
|---|---|---|---|---|---|
| **silence** | **6** | 0 | 0 | 0 | 0 |
| **unknown** | 0 | **13** | 0 | 3 | 0 |
| **yes** | 0 | 0 | **49** | 1 | 0 |
| **no** | 0 | 5 | 1 | **78** | 0 |

The diagonal represents agreement with the golden class. Every off-diagonal cell is a
sample where the RTL differs from the golden model.

### Informational only: accuracy against ground truth

_This section is NOT used for scoring; it only provides context about dataset difficulty._

| | Accuracy |
|---|---|
| Hardware | 67.31 % |
| Golden model (software) | 72.44 % |
| Difference | -5.13 percentage points |

## 3. Robustness Scenarios (Option F)

| Scenario | Result | Description |
|---|---|---|

## 4. Samples That Differ from the Golden Model

| # | sample | golden | hardware | truth (info) | score error (%) | latency (ms) |
|---|---|---|---|---|---|---|
| 38 | no_b69002d4_nohash_0 | no | unknown | no | - | 62.6 |
| 59 | go_1942abd7_nohash_0 | unknown | no | unknown | - | 58.9 |
| 61 | go_28e47b1a_nohash_1 | unknown | no | unknown | - | 55.1 |
| 71 | no_0132a06d_nohash_4 | no | unknown | no | - | 66.2 |
| 74 | no_37dca74f_nohash_0 | no | unknown | no | - | 66.2 |
| 83 | yes_41285056_nohash_2 | yes | no | yes | - | 60.1 |
| 95 | no_3cc595de_nohash_0 | no | yes | no | - | 58.8 |
| 107 | no_06a79a03_nohash_0 | no | unknown | no | - | 63.9 |
| 128 | go_274c008f_nohash_0 | unknown | no | unknown | - | 55.2 |
| 143 | go_31270cb2_nohash_0 | no | unknown | unknown | - | 57.9 |

## 5. Files

- `samples.csv` - per-sample raw records and score-error information
- `robustness.csv` - robustness scenario results
- `summary.json` - machine-readable summary
- `transcript.log` - raw core-UART output
- `config_used.json` - effective ICD actually used for the run
