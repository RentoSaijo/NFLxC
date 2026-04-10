# term_rf

## Setup

- Task: `term`.
- Model family: `random_forest`.
- Engine: `ranger`.
- Tuning method: `bayes`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `500`.
- Selection rule: `best`.
- Primary CV metric: `mn_log_loss`.
- Selected CV mean: `0.795450`.
- Selected CV std. err.: `0.023842`.
- Initial design size: `10`.
- Bayesian iterations: `15`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 150.000000 |
| trees | 485.000000 |
| min_n | 58.000000 |
| .config | iter03 |

## Validate Metrics

| metric | value |
| --- | --- |
| mnLogLoss | 0.544580 |
| rocAuc | 0.669144 |
| brier | 0.057318 |
| accuracy | 0.813187 |

## Top CV Candidates

| mtry | trees | min_n | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 150 |  485 | 58 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter03 |
| 148 | 1502 | 43 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter07 |
| 150 | 1300 | 40 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | pre0_mod10_post0 |
| 122 |  466 | 50 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter09 |
| 150 |  300 | 17 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter02 |
| 145 |  916 | 60 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter04 |
| 101 | 1800 | 21 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | pre0_mod07_post0 |
| 117 |  466 | 47 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | pre0_mod08_post0 |
| 127 | 1776 | 19 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | iter06 |
|  85 | 1466 | 60 | mn_log_loss | multiclass | 0.795450 | 5 | 0.023842 | pre0_mod06_post0 |
