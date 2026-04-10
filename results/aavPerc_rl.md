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
- Selected CV mean: `0.010494`.
- Selected CV std. err.: `0.000295`.
- Lambda grid size: `40`.

## Selected Parameters

| parameter | value |
| --- | --- |
| lambda | 0.004924 |
| .config | pre0_mod22_post0 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.006082 |
| mae | 0.003890 |
| mse | 0.00003699 |
| rsq | 0.883440 |

## Top CV Candidates

| penalty | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- |
| 4.923883e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod22_post0 |
| 6.614741e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod23_post0 |
| 3.665241e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod21_post0 |
| 8.886238e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod24_post0 |
| 2.728333e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod20_post0 |
| 1.193777e-02 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod25_post0 |
| 2.030918e-03 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod19_post0 |
| 1.603719e-02 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod26_post0 |
| 1.000000e-05 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod01_post0 |
| 1.343399e-05 | rmse | standard | 0.010494 | 5 | 0.000295 | pre0_mod02_post0 |
