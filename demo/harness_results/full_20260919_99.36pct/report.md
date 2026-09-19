# Demo Evaluation Report - ZUGA-IC

- Date: 2026-09-19T10:53:42+03:00
- Harness version: 1.0.2
- Configuration source: `takim_icd.json`
- Effective configuration: `config_used.json` (SHA256 `849691b385eb8587`)
- Dataset: public_dataset/manifest.csv | seed: 1337
- Interfaces: stream `/dev/ttyUSB0@115200`, core `/dev/ttyUSB0@115200`

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
| **Golden agreement** | 99.36 %  (155/156) |
| Mismatches | 1 |
| Timeouts (samples with reference) | 0 |
| Strict agreement (timeouts counted as errors) | 99.36 % |
| Latency (median / p95 / max) | 106.14 / 113.34 / 118.56 ms |
| Robustness scenarios | 10 / 10 (+1 optional skipped) |

> Note: latency is measured from the end of frame transmission to receipt of the final
> byte of the result. It includes UART transfer and ISR time. For pure accelerator
> cycle counts, RTL-simulation cross-checking is the authoritative method.

## 2. Agreement Matrix (rows = golden reference, columns = hardware output)

| golden \ hardware | silence | unknown | yes | no | TIMEOUT |
|---|---|---|---|---|---|
| **silence** | **6** | 0 | 0 | 0 | 0 |
| **unknown** | 0 | **15** | 0 | 1 | 0 |
| **yes** | 0 | 0 | **50** | 0 | 0 |
| **no** | 0 | 0 | 0 | **84** | 0 |

The diagonal represents agreement with the golden class. Every off-diagonal cell is a
sample where the RTL differs from the golden model.

### Informational only: accuracy against ground truth

_This section is NOT used for scoring; it only provides context about dataset difficulty._

| | Accuracy |
|---|---|
| Hardware | 71.79 % |
| Golden model (software) | 72.44 % |
| Difference | -0.64 percentage points |

## 3. Robustness Scenarios (Option F)

| Scenario | Result | Description |
|---|---|---|
| silence_zeros | PASS | output=no, latency=106.1 ms, next valid frame responded |
| silence_dither | PASS | output=no, latency=106.1 ms, next valid frame responded |
| saturate_max | PASS | output=no, latency=111.4 ms, next valid frame responded |
| saturate_min | PASS | output=silence, latency=95.8 ms, next valid frame responded |
| alternating | PASS | output=silence, latency=117.6 ms, next valid frame responded |
| back_to_back | PASS | received responses for 5 of 5 back-to-back frames |
| truncated_frame | PASS | recovery after truncated frame successful (output=no) |
| oversized_frame | PASS | recovery after oversized frame successful (output=no) |
| peripheral_interleave | SKIP | Optional scenario not run: hooks.interleave_core_hex is not configured; the peripheral-interleave test was not executed. |
| determinism | PASS | 1 distinct result(s) across 10 repetitions; latency jitter=2.78 ms |
| recovery_after_idle | PASS | after a 3 s idle period responded (no) |

## 4. Samples That Differ from the Golden Model

| # | sample | golden | hardware | truth (info) | score error (%) | latency (ms) |
|---|---|---|---|---|---|---|
| 128 | go_274c008f_nohash_0 | unknown | no | unknown | - | 103.2 |

## 5. Files

- `samples.csv` - per-sample raw records and score-error information
- `robustness.csv` - robustness scenario results
- `summary.json` - machine-readable summary
- `transcript.log` - raw core-UART output
- `config_used.json` - effective ICD actually used for the run
