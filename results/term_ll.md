# term_ll

## Setup

- Task: `term`.
- Model family: `lasso_multinomial`.
- Engine: `glmnet`.
- Tuning method: `cv_grid`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `500`.
- Selection rule: `best`.
- Primary CV metric: `mn_log_loss`.
- Selected CV mean: `0.832474`.
- Selected CV std. err.: `0.022121`.
- Lambda grid size: `40`.

## Selected Parameters

| parameter | value |
| --- | --- |
| lambda | 0.008886 |
| .config | pre0_mod24_post0 |

## Validate Metrics

| metric | value |
| --- | --- |
| mnLogLoss | 0.591975 |
| rocAuc | 0.642260 |
| brier | 0.060119 |
| accuracy | 0.813187 |

## Top CV Candidates

| penalty | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- |
| 0.008886238 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod24_post0 |
| 0.006614741 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod23_post0 |
| 0.004923883 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod22_post0 |
| 0.011937766 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod25_post0 |
| 0.003665241 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod21_post0 |
| 0.016037187 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod26_post0 |
| 0.002728333 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod20_post0 |
| 0.021544347 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod27_post0 |
| 0.002030918 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod19_post0 |
| 0.028942661 | mn_log_loss | multiclass | 0.832474 | 5 | 0.022121 | pre0_mod28_post0 |
