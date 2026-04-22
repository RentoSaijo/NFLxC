#!/usr/bin/env Rscript

source(file.path('R', 'final_model_helpers.R'))

# —— Inputs —— #
selectedResult <- loadSelectedResult(file.path('results', 'aavPerc_rl.csv'))
modelId        <- 'aavPerc_rl_final'
lambdaValue    <- selectedResult$lambda[[1L]]

# —— Model —— #
spec <- parsnip::linear_reg(
  penalty = lambdaValue,
  mixture = 0
) |>
  parsnip::set_engine('glmnet') |>
  parsnip::set_mode('regression')

# —— Fit —— #
modelObject <- fitFinalModel(
  modelId        = modelId,
  task           = 'aavPerc',
  engine         = 'glmnet',
  spec           = spec,
  selectedResult = selectedResult
)

# —— Reports —— #
coefTable <- extractRegressionCoefficients(modelObject, lambda = lambdaValue)
coefPath  <- file.path(modelsDir, paste0(modelId, '_coefficients.csv'))
plotPath  <- saveRegressionCoefficientPlot(
  coefTable = coefTable,
  modelId   = modelId,
  title     = 'AAV% Ridge Coefficients'
)

readr::write_csv(coefTable, coefPath)

topCoefficients <- coefTable |>
  dplyr::filter(feature != '(Intercept)') |>
  dplyr::mutate(absCoefficient = abs(coefficient)) |>
  dplyr::slice_max(absCoefficient, n = 25L, with_ties = FALSE) |>
  dplyr::transmute(
    feature     = feature,
    coefficient = formatNumber(coefficient),
    absValue    = formatNumber(absCoefficient)
  )

metricTable <- tibble::tibble(
  metric = c('rmse', 'mae', 'rsq'),
  value  = c(
    formatNumber(selectedResult$rmse),
    formatNumber(selectedResult$mae),
    formatNumber(selectedResult$rsq)
  )
)

lines <- c(
  '# aavPerc_rl_final',
  '',
  '## Purpose',
  '',
  'This is the final interpretable `aavPerc` model. It is a ridge-penalized linear regression refit on `train.csv + validate.csv`, again conditioned on a supplied term scenario.',
  '',
  '## Why This Model',
  '',
  '- Ridge regression gives a fully explicit linear equation and remains stable in the wide, correlated feature space created by the contract recipe.',
  '- Unlike lasso, ridge keeps all predictors in the model, which is useful when several feature families carry overlapping market information.',
  '- This is the audit-friendly companion to the predictive `xgboost` compensation model.',
  '',
  '## Final Fit',
  '',
  paste0('- Final training rows: `', modelObject$fittedRows, '`.'),
  paste0('- Predictor count after recipe: `', modelObject$predictorCount, '`.'),
  paste0('- Selected lambda: `', formatNumber(lambdaValue, digits = 8L), '`.'),
  paste0('- Final fit time: `', formatNumber(modelObject$fitSeconds), '` seconds.'),
  paste0('- Implied 2026 cap used for dollar translation: `', formatNumber(modelObject$impliedCap2026, digits = 0L), '`.'),
  paste0('- Saved model object: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  '',
  '## Historical Held-Out Metrics',
  '',
  markdownTable(metricTable),
  '',
  '## Closed-Form Structure',
  '',
  'The final model is',
  '',
  '```text',
  'aavPerc_hat(x) = beta_0 + sum_j beta_j x_j',
  '```',
  '',
  'where the `x_j` terms are the recipe-transformed predictors after dummy encoding, missing handling, and normalization. Because the model is ridge-penalized, every transformed predictor keeps a coefficient, but the penalty shrinks unstable estimates toward zero.',
  '',
  paste0('![AAV% Ridge Coefficients](', file.path('plots', basename(plotPath)), ')'),
  '',
  'Largest absolute coefficients:',
  '',
  markdownTable(topCoefficients),
  '',
  '## Statistical Notes',
  '',
  '- Ridge coefficients are not classical p-value-based significance statements. Their interpretation is shrinkage-regularized linear weight on the transformed feature scale.',
  '- Because the recipe normalizes numeric predictors, coefficient size is more comparable across transformed continuous features than it would be on raw units.',
  '- The final prediction remains conditional on the supplied term scenario and is translated into dollars using the implied 2026 cap from the observed 2026 contracts.',
  '',
  '## Files',
  '',
  paste0('- Model: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  paste0('- Coefficients CSV: `', coefPath, '`.'),
  paste0('- Coefficient plot: `', plotPath, '`.')
)

writeLines(lines, con = file.path(modelsDir, paste0(modelId, '.md')))

message(sprintf(
  'Wrote final aavPerc ridge model to %s.',
  normalizePath(file.path(modelsDir, paste0(modelId, '.rds')))
))
