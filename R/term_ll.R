#!/usr/bin/env Rscript

source(file.path('R', 'optimization_helpers.R'))

# —— Model —— #
spec <- parsnip::multinom_reg(
  penalty = tune::tune(),
  mixture = 1
) |>
  parsnip::set_engine('glmnet') |>
  parsnip::set_mode('classification')

# —— Run —— #
summaryRow <- runPenaltyWorkflow(
  task        = 'term',
  modelId     = 'term_ll',
  modelFamily = 'lasso_multinomial',
  engine      = 'glmnet',
  package     = 'glmnet',
  spec        = spec
)

message(sprintf(
  'Wrote term_ll results to %s.',
  normalizePath(file.path('results', 'term_ll.csv'))
))
