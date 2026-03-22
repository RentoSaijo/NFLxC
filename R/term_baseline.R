#!/usr/bin/env Rscript

source(file.path('R', 'baseline_helpers.R'))

# —— Data —— #
prepared <- prepareTaskData('term')

# —— Helpers —— #
sqrtMtry <- function(p) {
  max(1L, as.integer(floor(sqrt(p))))
}

mlpUnits <- function(p) {
  min(20L, max(4L, as.integer(floor(sqrt(p)))))
}

# —— Models —— #
results <- dplyr::bind_rows(
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'null_majority',
    modelFamily  = 'null',
    engine       = 'parsnip',
    package      = 'parsnip',
    builder      = function(p) {
      parsnip::null_model(mode = 'classification')
    }
  ),
  runOrderedLogit(prepared),
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'multinomial_logit_nnet',
    modelFamily  = 'multinomial_logistic',
    engine       = 'nnet',
    package      = 'nnet',
    builder      = function(p) {
      parsnip::multinom_reg(penalty = 0.001) |>
        parsnip::set_engine('nnet', MaxNWts = 50000, trace = FALSE) |>
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'ridge_glmnet',
    modelFamily  = 'ridge',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::multinom_reg(penalty = 0.01, mixture = 0) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'lasso_glmnet',
    modelFamily  = 'lasso',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::multinom_reg(penalty = 0.01, mixture = 1) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'elastic_net_glmnet',
    modelFamily  = 'elastic_net',
    engine       = 'glmnet',
    package      = 'glmnet',
    builder      = function(p) {
      parsnip::multinom_reg(penalty = 0.01, mixture = 0.5) |>
        parsnip::set_engine('glmnet') |>
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
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
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
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
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
    prepared     = prepared,
    modelId      = 'random_forest_ranger',
    modelFamily  = 'random_forest',
    engine       = 'ranger',
    package      = 'ranger',
    builder      = function(p) {
      parsnip::rand_forest(
        trees = 500,
        mtry  = sqrtMtry(p),
        min_n = 5
      ) |>
        parsnip::set_engine(
          'ranger',
          num.threads = 1,
          probability = TRUE,
          importance  = 'none',
          seed        = baselineSeed
        ) |>
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
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
        parsnip::set_mode('classification')
    }
  ),
  runParsnipClassification(
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
        parsnip::set_mode('classification')
    }
  ),
  bayesSkippedRow('term') |>
    dplyr::mutate(
      predictorCount = prepared$predictorCount,
      trainRows      = prepared$trainRows,
      validateRows   = prepared$validateRows
    )
)

# —— Output —— #
readr::write_csv(results, file.path('results', 'term_baseline.csv'))

message(sprintf(
  'Wrote %d term baseline rows to %s.',
  nrow(results),
  normalizePath(file.path('results', 'term_baseline.csv'))
))

