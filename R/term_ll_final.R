#!/usr/bin/env Rscript

source(file.path('R', 'final_model_helpers.R'))

# —— Inputs —— #
selectedResult <- loadSelectedResult(file.path('results', 'term_ll.csv'))
modelId        <- 'term_ll_final'
lambdaValue    <- selectedResult$lambda[[1L]]

# —— Model —— #
spec <- parsnip::multinom_reg(
  penalty = lambdaValue,
  mixture = 1
) |>
  parsnip::set_engine('glmnet') |>
  parsnip::set_mode('classification')

# —— Fit —— #
modelObject <- fitFinalModel(
  modelId        = modelId,
  task           = 'term',
  engine         = 'glmnet',
  spec           = spec,
  selectedResult = selectedResult
)

# —— Reports —— #
coefTable <- extractMultinomialCoefficients(modelObject, lambda = lambdaValue)
coefPath  <- file.path(modelsDir, paste0(modelId, '_coefficients.csv'))
plotPath  <- saveMultinomialCoefficientPlot(
  coefTable = coefTable,
  modelId   = modelId,
  title     = 'Term Lasso Multinomial Coefficients'
)

readr::write_csv(coefTable, coefPath)

nonZeroCounts <- coefTable |>
  dplyr::filter(feature != '(Intercept)', coefficient != 0) |>
  dplyr::count(class, name = 'nonZeroCoefficients') |>
  dplyr::mutate(nonZeroCoefficients = as.character(nonZeroCoefficients))

topCoefficients <- coefTable |>
  dplyr::filter(feature != '(Intercept)', coefficient != 0) |>
  dplyr::mutate(absCoefficient = abs(coefficient)) |>
  dplyr::group_by(class) |>
  dplyr::slice_max(absCoefficient, n = 10L, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::transmute(
    class       = class,
    feature     = feature,
    coefficient = formatNumber(coefficient)
  )

metricTable <- tibble::tibble(
  metric = c('mnLogLoss', 'rocAuc', 'brier', 'accuracy'),
  value  = c(
    formatNumber(selectedResult$mnLogLoss),
    formatNumber(selectedResult$rocAuc),
    formatNumber(selectedResult$brier),
    formatNumber(selectedResult$accuracy)
  )
)

lines <- c(
  '# term_ll_final',
  '',
  '## Purpose',
  '',
  'This is the final interpretable term model. It is a lasso-penalized multinomial logistic regression refit on `train.csv + validate.csv` using the lambda that was selected by grouped cross-validation on the original training split.',
  '',
  '## Why This Model',
  '',
  '- The multinomial lasso is materially more interpretable than boosted trees because it has an explicit softmax form with a finite coefficient vector for each term class.',
  '- The lasso penalty performs embedded variable selection, which is useful in this very wide engineered design.',
  '- This model is the right audit companion to the stronger but less transparent `xgboost` classifier.',
  '',
  '## Final Fit',
  '',
  paste0('- Final training rows: `', modelObject$fittedRows, '`.'),
  paste0('- Predictor count after recipe: `', modelObject$predictorCount, '`.'),
  paste0('- Selected lambda: `', formatNumber(lambdaValue, digits = 8L), '`.'),
  paste0('- Final fit time: `', formatNumber(modelObject$fitSeconds), '` seconds.'),
  paste0('- Saved model object: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  '',
  '## Historical Held-Out Metrics',
  '',
  markdownTable(metricTable),
  '',
  '## Closed-Form Structure',
  '',
  'For each term class `k` in `{1, 2, 3, 4, 5+}`, the model defines a linear score',
  '',
  '```text',
  'eta_k(x) = beta_0k + sum_j beta_jk x_j',
  'P(term = k | x) = exp(eta_k(x)) / sum_m exp(eta_m(x))',
  '```',
  '',
  'The `x_j` terms are the recipe-transformed predictors after dummy encoding, missing-data handling, and normalization. So the exact closed form exists, but it is written on the transformed feature space rather than the raw CSV columns directly.',
  '',
  '## Sparsity',
  '',
  'The table below counts how many non-zero coefficients remain in each class-specific linear predictor after lasso shrinkage.',
  '',
  markdownTable(nonZeroCounts),
  '',
  paste0('![Term Lasso Coefficients](', file.path('plots', basename(plotPath)), ')'),
  '',
  'Top non-zero coefficients by class:',
  '',
  markdownTable(topCoefficients),
  '',
  '## Statistical Notes',
  '',
  '- Coefficients here should be interpreted as penalized partial associations on the transformed feature space, not as unbiased frequentist estimates with p-values.',
  '- A non-zero coefficient is the practical notion of “significant” in this model family because lasso explicitly zeroes many weaker terms out.',
  '- Classwise coefficient signs affect the relative linear score for that class and therefore the softmax probability, holding all other transformed features fixed.',
  '',
  '## Files',
  '',
  paste0('- Model: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  paste0('- Coefficients CSV: `', coefPath, '`.'),
  paste0('- Coefficient plot: `', plotPath, '`.')
)

writeLines(lines, con = file.path(modelsDir, paste0(modelId, '.md')))

message(sprintf(
  'Wrote final term lasso model to %s.',
  normalizePath(file.path(modelsDir, paste0(modelId, '.rds')))
))
