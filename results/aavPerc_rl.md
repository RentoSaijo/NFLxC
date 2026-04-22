# aavPerc_rl

## Setup

- Task: `aavPerc`.
- Model family: `ridge_linear`.
- Engine: `glmnet`.
- Tuning method: `cv_grid`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `504`.
- Selection rule: `best`.
- Primary CV metric: `rmse`.
- Selected CV mean: `0.010295`.
- Selected CV std. err.: `0.000565`.
- Lambda grid size: `40`.

## Selected Parameters

| parameter | value |
| --- | --- |
| lambda | 0.002728 |
| .config | pre0_mod20_post0 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.005943 |
| mae | 0.003858 |
| mse | 0.00003532 |
| rsq | 0.888613 |

## Top CV Candidates

| penalty | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- |
| 2.728333e-03 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod20_post0 |
| 3.665241e-03 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod21_post0 |
| 2.030918e-03 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod19_post0 |
| 4.923883e-03 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod22_post0 |
| 1.000000e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod01_post0 |
| 1.343399e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod02_post0 |
| 1.804722e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod03_post0 |
| 2.424462e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod04_post0 |
| 3.257021e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod05_post0 |
| 4.375479e-05 | rmse | standard | 0.010295 | 5 | 0.000565 | pre0_mod06_post0 |
