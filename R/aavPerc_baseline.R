#!/usr/bin/env Rscript

source(file.path('R', 'baseline_helpers.R'))

# —— Data —— #
prepared <- prepareTaskData('aavPerc')

# —— Helpers —— #
sqrtMtry <- function(p) {
  max(1L, as.integer(floor(sqrt(p))))
}

forestMtry <- function(p) {
  max(1L, min(100L, as.integer(floor(p / 3))))
}

mlpUnits <- function(p) {
  min(20L, max(4L, as.integer(floor(sqrt(p)))))
}

# —— Models —— #
results <- dplyr::bind_rows(
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'null_mean',
    modelFamily  = 'null',
    engine       = 'parsnip',
    package      = 'parsnip',
    builder      = function(p) {
      parsnip::null_model(mode = 'regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'linear_lm',
    modelFamily  = 'linear',
    engine       = 'lm',
    package      = 'stats',
    builder      = function(p) {
      parsnip::linear_reg() |>
        parsnip::set_engine('lm') |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'ridge_glmnet',
    modelFamily  = 'ridge',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::linear_reg(penalty = 0.01, mixture = 0) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'lasso_glmnet',
    modelFamily  = 'lasso',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::linear_reg(penalty = 0.01, mixture = 1) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'elastic_net_glmnet',
    modelFamily  = 'elastic_net',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::linear_reg(penalty = 0.01, mixture = 0.5) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'mlp_nnet',
    modelFamily  = 'neural_net',
    engine       = 'nnet',
    package      = 'nnet',
    builder      = function(p) {
      parsnip::mlp(
        hidden_units = mlpUnits(p),
        penalty      = 0.001,
        epochs       = 200
      ) |>
        parsnip::set_engine('nnet', MaxNWts = 50000, trace = FALSE) |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'decision_tree_rpart',
    modelFamily  = 'decision_tree',
    engine       = 'rpart',
    package      = 'rpart',
    builder      = function(p) {
      parsnip::decision_tree(
        cost_complexity = 0.001,
        tree_depth      = 10,
        min_n           = 10
      ) |>
        parsnip::set_engine('rpart') |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'random_forest_ranger',
    modelFamily  = 'random_forest',
    engine       = 'ranger',
    package      = 'ranger',
    builder      = function(p) {
      parsnip::rand_forest(
        trees = 500,
        mtry  = forestMtry(p),
        min_n = 5
      ) |>
        parsnip::set_engine(
          'ranger',
          num.threads = 1,
          importance  = 'none',
          seed        = baselineSeed
        ) |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'xgboost',
    modelFamily  = 'boosted_tree',
    engine       = 'xgboost',
    package      = 'xgboost',
    builder      = function(p) {
      parsnip::boost_tree(
        trees          = 300,
        tree_depth     = 6,
        learn_rate     = 0.05,
        min_n          = 10,
        loss_reduction = 0,
        sample_size    = 0.8,
        mtry           = sqrtMtry(p)
      ) |>
        parsnip::set_engine('xgboost', nthread = 1, verbose = 0) |>
        parsnip::set_mode('regression')
    }
  ),
  runParsnipRegression(
    prepared     = prepared,
    modelId      = 'lightgbm',
    modelFamily  = 'boosted_tree',
    engine       = 'lightgbm',
    package      = 'lightgbm',
    builder      = function(p) {
      parsnip::boost_tree(
        trees          = 300,
        tree_depth     = 6,
        learn_rate     = 0.05,
        min_n          = 10,
        loss_reduction = 0,
        sample_size    = 0.8,
        mtry           = sqrtMtry(p)
      ) |>
        parsnip::set_engine(
          'lightgbm',
          num_threads  = 1,
          verbose      = -1,
          seed         = baselineSeed,
          deterministic = TRUE
        ) |>
        parsnip::set_mode('regression')
    }
  ),
  bayesSkippedRow('aavPerc') |>
    dplyr::mutate(
      predictorCount = prepared$predictorCount,
      trainRows      = prepared$trainRows,
      validateRows   = prepared$validateRows
    )
)

# —— Output —— #
readr::write_csv(results, file.path('results', 'aavPerc_basline.csv'))

message(sprintf(
  'Wrote %d aavPerc baseline rows to %s.',
  nrow(results),
  normalizePath(file.path('results', 'aavPerc_basline.csv'))
))

