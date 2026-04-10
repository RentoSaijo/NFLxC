# aavPerc_rf

## Setup

- Task: `aavPerc`.
- Model family: `random_forest`.
- Engine: `ranger`.
- Tuning method: `bayes`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `504`.
- Selection rule: `best`.
- Primary CV metric: `rmse`.
- Selected CV mean: `0.010546`.
- Selected CV std. err.: `0.000885`.
- Initial design size: `10`.
- Bayesian iterations: `15`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 150.000000 |
| trees | 942.000000 |
| min_n | 2.000000 |
| .config | iter04 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.006090 |
| mae | 0.003062 |
| mse | 0.00003709 |
| rsq | 0.879610 |

## Top CV Candidates

| mtry | trees | min_n | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 150 |  942 |  2 | rmse | standard | 0.010546 | 5 | 0.000885 | iter04 |
| 150 | 1572 | 10 | rmse | standard | 0.010546 | 5 | 0.000885 | iter05 |
| 147 |  326 |  3 | rmse | standard | 0.010546 | 5 | 0.000885 | iter03 |
| 149 |  737 | 10 | rmse | standard | 0.010546 | 5 | 0.000885 | iter06 |
| 149 | 1650 |  4 | rmse | standard | 0.010546 | 5 | 0.000885 | iter08 |
| 150 |  798 | 16 | rmse | standard | 0.010546 | 5 | 0.000885 | iter09 |
| 123 | 1779 |  3 | rmse | standard | 0.010546 | 5 | 0.000885 | iter07 |
| 133 |  966 |  8 | rmse | standard | 0.010546 | 5 | 0.000885 | pre0_mod09_post0 |
| 143 | 1737 |  3 | rmse | standard | 0.010546 | 5 | 0.000885 | iter02 |
| 101 |  404 |  2 | rmse | standard | 0.010546 | 5 | 0.000885 | iter01 |
