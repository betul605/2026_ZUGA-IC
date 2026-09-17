# Demo Evaluation Report - ZUGA-IC

- Date: 2026-09-18T01:07:38+03:00
- Harness version: 1.0.2
- Configuration source: `takim_icd.json`
- Effective configuration: `config_used.json` (SHA256 `849691b385eb8587`)
- Dataset: public_dataset/manifest_demo40.csv | seed: 1337
- Interfaces: stream `/dev/ttyUSB0@115200`, core `/dev/ttyUSB0@115200`

## 1. Summary - RTL / Golden Model Agreement

> **The primary check is not model accuracy; it is fidelity of the design to the golden model.**
> The primary metric checks whether the hardware class matches the class produced by
> the golden model for the same vector. The ground-truth label (truth) is reported only
> as additional information and is not used for scoring.

| Metric | Value |
|---|---|
| Samples sent | 40 |
| Samples with golden reference | 40 |
| Responses received | 40 |
| **Golden agreement** | 100.00 %  (40/40) |
| Mismatches | 0 |
| Timeouts (samples with reference) | 0 |
| Strict agreement (timeouts counted as errors) | 100.00 % |
| Latency (median / p95 / max) | 106.09 / 115.55 / 117.03 ms |
| Robustness scenarios | 0 / 0 |

> Note: latency is measured from the end of frame transmission to receipt of the final
> byte of the result. It includes UART transfer and ISR time. For pure accelerator
> cycle counts, RTL-simulation cross-checking is the authoritative method.

## 2. Agreement Matrix (rows = golden reference, columns = hardware output)

| golden \ hardware | silence | unknown | yes | no | TIMEOUT |
|---|---|---|---|---|---|
| **silence** | **1** | 0 | 0 | 0 | 0 |
| **unknown** | 0 | **7** | 0 | 0 | 0 |
| **yes** | 0 | 0 | **15** | 0 | 0 |
| **no** | 0 | 0 | 0 | **17** | 0 |

The diagonal represents agreement with the golden class. Every off-diagonal cell is a
sample where the RTL differs from the golden model.

### Informational only: accuracy against ground truth

_This section is NOT used for scoring; it only provides context about dataset difficulty._

| | Accuracy |
|---|---|
| Hardware | 80.00 % |
| Golden model (software) | 80.00 % |
| Difference | +0.00 percentage points |

## 3. Robustness Scenarios (Option F)

| Scenario | Result | Description |
|---|---|---|

## 4. Samples That Differ from the Golden Model

_None._

## 5. Files

- `samples.csv` - per-sample raw records and score-error information
- `robustness.csv` - robustness scenario results
- `summary.json` - machine-readable summary
- `transcript.log` - raw core-UART output
- `config_used.json` - effective ICD actually used for the run
