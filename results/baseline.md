# WR Contract Baseline Modeling

## Scope

This baseline pass fits untuned models for both project tasks on the rebuilt contract files after:

- dropping embedded year rows that were already covered by earlier multi-year deals
- rebuilding `prev1` and `prev2` off observed or proxied signing dates rather than `startYear - 1` and `startYear - 2`

The two tasks are:

- `term`: Multiclass classification over contract terms `1:5`, where `5` means `5+`
- `aavPerc`: Regression on cap-share AAV

Evaluation uses `data/validate.csv`, not `data/test.csv`. `test.csv` is intentionally unlabeled and is reserved for future scoring, so it cannot support held-out metric comparison.

Outputs:

- `results/term_baseline.csv`
- `results/aavPerc_basline.csv`

The `aavPerc` filename keeps the requested `basline` spelling.

## Preprocessing

Both scripts use the same preprocessing logic from `R/baseline_helpers.R`:

- ID and bookkeeping columns are assigned out of the predictor set:
  - `contractRowId`, `sourceFile`, `playerName`, `playerKey`, `playerId`, `pfrId`, `birthDate`
- Non-ex-ante fields are removed:
  - `dateOfSigningObserved`, `featureReferenceDate`, `signingDateObserved`, `signingDateSource`
  - `signedTeam`
  - `isEntryLike`
  - `aav` and `aavPerc` for the `term` task
  - `aav` for the `aavPerc` task
- `term` is encoded as a factor with levels `1:5`
- Logical predictors are converted to `no/yes` factors
- Character predictors are converted to factors, unknown and novel levels are handled explicitly, then dummy encoded
- Nominal predictors are mode-imputed
- Numeric predictors are median-imputed, zero-variance filtered, and normalized

Final matrix widths:

- `term`: 500 predictors
- `aavPerc`: 504 predictors

`aavPerc` keeps `term` as a predictor on purpose. That matches the intended downstream setup where `aavPerc` is conditioned on a term scenario.

Current split sizes:

- `train.csv`: 2,795 rows
- `validate.csv`: 91 rows
- `test.csv`: 163 rows

## Model Grid

### `term`

Attempted engines:

- null classifier
- ordered logistic via `MASS::polr`
- multinomial logistic via `nnet`
- ridge, lasso, and elastic net via `glmnet`
- single-layer neural net via `nnet`
- decision tree via `rpart`
- random forest via `ranger`
- xgboost
- lightgbm
- Bayesian classifier placeholder

### `aavPerc`

Attempted engines:

- null regressor
- OLS via `lm`
- ridge, lasso, and elastic net via `glmnet`
- single-layer neural net via `nnet`
- decision tree via `rpart`
- random forest via `ranger`
- xgboost
- lightgbm
- Bayesian regressor placeholder

Bayesian baselines were not fit because no supported package such as `brulee` or `rstanarm` is installed in this environment.

## Held-Out Results

### `term`

Best proper scoring model was `xgboost`:

| model | log loss | ROC AUC | Brier | accuracy |
|---|---:|---:|---:|---:|
| xgboost | 0.5597 | 0.6655 | 0.0577 | 0.8132 |
| random_forest_ranger | 0.5695 | 0.6733 | 0.0587 | 0.8022 |
| lasso_glmnet | 0.5883 | 0.6452 | 0.0599 | 0.8132 |
| elastic_net_glmnet | 0.6132 | 0.6179 | 0.0608 | 0.8132 |
| lightgbm | 0.6524 | 0.6224 | 0.0622 | 0.8242 |
| ridge_glmnet | 0.7099 | 0.6008 | 0.0646 | 0.8132 |
| null_majority | 0.7567 | 0.5000 | 0.0720 | 0.8352 |

Important interpretation:

- The rebuilt validation set is still heavily skewed toward `1`-year deals: `76` of `91`.
- The null model still wins raw accuracy by always predicting `1` year, but it is much worse on log loss, AUC, and Brier.
- On a proper probabilistic basis, `xgboost` is the strongest baseline, with `ranger` close behind.
- Collapsing the long tail into `5+` makes the multinomial task materially more stable without changing the practical contract decision space.

Other successful `term` baselines were materially worse:

- `multinomial_logit_nnet`: log loss `1.0042`, accuracy `0.7912`
- `mlp_nnet`: log loss `1.1699`, accuracy `0.7253`
- `decision_tree_rpart`: log loss `1.3741`, accuracy `0.7912`

Failed `term` baselines:

- `ordinal_logit_mass` failed to find stable starting values in the full wide design.

Notable change from the earlier unbucketed run:

- `ridge_glmnet`, `lasso_glmnet`, and `elastic_net_glmnet` now fit successfully because the rare `6`, `7`, and `8` year contracts are absorbed into the `5+` bucket.

### `aavPerc`

Best held-out regressor was `xgboost`:

| model | RMSE | MAE | MSE | R² |
|---|---:|---:|---:|---:|
| xgboost | 0.00610 | 0.00318 | 0.0000373 | 0.8818 |
| random_forest_ranger | 0.00619 | 0.00319 | 0.0000383 | 0.8757 |
| ridge_glmnet | 0.00640 | 0.00405 | 0.0000410 | 0.8707 |
| lightgbm | 0.00655 | 0.00346 | 0.0000430 | 0.8617 |
| linear_lm | 0.00798 | 0.00478 | 0.0000637 | 0.7977 |

Additional results:

- `decision_tree_rpart`: RMSE `0.01036`, MAE `0.00430`, R² `0.7100`
- `mlp_nnet`: RMSE `0.01100`, MAE `0.00637`, R² `0.6159`
- `elastic_net_glmnet`: RMSE `0.01083`, MAE `0.00639`, R² `0.7406`
- `lasso_glmnet`: RMSE `0.01383`, MAE `0.00832`, R² `0.6691`
- `null_mean`: RMSE `0.01770`, MAE `0.01176`

Takeaways:

- Boosted trees still dominate the untuned regression baselines, with `xgboost` now slightly ahead of `lightgbm`.
- `ridge_glmnet` is the strongest linear-style baseline and comfortably beats plain OLS.
- `lasso_glmnet` is too aggressive at this fixed penalty in the untuned setting.

## Runtime Notes

The slowest successful models were the `nnet` neural nets:

- `term` `mlp_nnet`: about `126` seconds
- `aavPerc` `mlp_nnet`: about `115` seconds

The fastest strong baselines were the boosted trees:

- `term` `xgboost`: about `4.2` seconds
- `aavPerc` `xgboost`: about `0.78` seconds

## Practical Recommendation

If this baseline pass is the starting point for full tuning:

- Start `term` tuning with `xgboost`, `ranger`, and `lightgbm`
- Keep the null classifier in every future comparison because of the extreme 1-year class skew
- Start `aavPerc` tuning with `xgboost`, `ranger`, `ridge_glmnet`, and `lightgbm`
- Treat raw `term` accuracy as secondary to log loss and Brier unless the class balance changes
