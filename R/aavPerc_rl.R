#!/usr/bin/env Rscript

source(file.path('R', 'optimization_helpers.R'))

# —— Model —— #
spec <- parsnip::linear_reg(
  penalty = tune::tune(),
  mixture = 0
) |>
  parsnip::set_engine('glmnet') |>
  parsnip::set_mode('regression')

# —— Run —— #
summaryRow <- runPenaltyWorkflow(
  task        = 'aavPerc',
  modelId     = 'aavPerc_rl',
  modelFamily = 'ridge_linear',
  engine      = 'glmnet',
  package     = 'glmnet',
  spec        = spec
)

message(sprintf(
  'Wrote aavPerc_rl results to %s.',
  normalizePath(file.path('results', 'aavPerc_rl.csv'))
))
