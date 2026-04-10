#!/usr/bin/env Rscript

options(readr.show_col_types = FALSE)

source(file.path('R', 'baseline_helpers.R'))

# —— Packages —— #
requiredOptimizationPkgs <- c(
  'dials',
  'hardhat',
  'rsample',
  'stringr',
  'tune',
  'workflows'
)

missingOptimizationPkgs  <- requiredOptimizationPkgs[
  !vapply(requiredOptimizationPkgs, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missingOptimizationPkgs) > 0L) {
  stop(
    paste0(
      'Missing package(s): ',
      paste(missingOptimizationPkgs, collapse = ', '),
      '. Install them with install.packages(c(',
      paste(paste0('\'', missingOptimizationPkgs, '\''), collapse = ', '),
      ')).'
    ),
    call. = FALSE
  )
}

# —— Constants —— #
tuningSeed       <- 20260409L
defaultFoldCount <- 5L
xgbInitialSize   <- 12L
xgbBayesIter     <- 18L
rfInitialSize    <- 10L
rfBayesIter      <- 15L
lambdaGridSize   <- 40L

# —— Paths —— #
resultsDir <- 'results'

dir.create(resultsDir, recursive = TRUE, showWarnings = FALSE)

# —— Helpers —— #
primaryMetric <- function(task) {
  if (task == 'term') {
    return('mn_log_loss')
  }

  if (task == 'aavPerc') {
    return('rmse')
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

taskMetricSet <- function(task) {
  if (task == 'term') {
    return(
      yardstick::metric_set(
        yardstick::mn_log_loss,
        yardstick::accuracy
      )
    )
  }

  if (task == 'aavPerc') {
    return(
      yardstick::metric_set(
        yardstick::rmse,
        yardstick::mae,
        yardstick::rsq
      )
    )
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

taskMode <- function(task) {
  if (task == 'term') {
    return('classification')
  }

  if (task == 'aavPerc') {
    return('regression')
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

metricDirection <- function(task) {
  if (task == 'term') {
    return('minimize')
  }

  if (task == 'aavPerc') {
    return('minimize')
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

makeResamples <- function(trainingData) {
  foldCount <- max(2L, min(defaultFoldCount, dplyr::n_distinct(trainingData$playerId)))

  list(
    resamples = rsample::group_vfold_cv(
      trainingData,
      group   = playerId,
      v       = foldCount,
      balance = 'observations'
    ),
    foldCount = foldCount
  )
}

loadWorkflowInputs <- function(task) {
  trainingData <- loadTaskFrame(task, trainPath)
  validateData <- loadTaskFrame(task, validatePath)
  prepared     <- prepareTaskData(task)
  recipeSpec   <- buildRecipe(task, trainingData)
  splitInfo    <- makeResamples(trainingData)

  list(
    trainingData   = trainingData,
    validateData   = validateData,
    prepared       = prepared,
    recipeSpec     = recipeSpec,
    resamples      = splitInfo$resamples,
    foldCount      = splitInfo$foldCount,
    predictorCount = prepared$predictorCount,
    trainRows      = prepared$trainRows,
    validateRows   = prepared$validateRows
  )
}

arrangeMetricResults <- function(metricResults, task) {
  if (metricDirection(task) == 'maximize') {
    return(metricResults |> dplyr::arrange(dplyr::desc(mean), std_err))
  }

  metricResults |>
    dplyr::arrange(mean, std_err)
}

getBestMetricRow <- function(tunedResults, task, topN = 25L) {
  tune::show_best(
    tunedResults,
    metric = primaryMetric(task),
    n      = topN
  ) |>
    tibble::as_tibble() |>
    arrangeMetricResults(task = task)
}

formatScalar <- function(x, digits = 6L) {
  if (length(x) == 0L || is.null(x) || all(is.na(x))) {
    return(NA_character_)
  }

  value <- x[[1L]]

  if (is.character(value)) {
    return(value)
  }

  if (inherits(value, 'Date')) {
    return(as.character(value))
  }

  if (is.logical(value)) {
    return(ifelse(isTRUE(value), 'TRUE', 'FALSE'))
  }

  if (is.numeric(value)) {
    return(formatC(value, format = 'f', digits = digits))
  }

  as.character(value)
}

markdownTable <- function(data) {
  if (nrow(data) == 0L) {
    return(character())
  }

  header <- paste0('| ', paste(names(data), collapse = ' | '), ' |')
  rule   <- paste0('| ', paste(rep('---', ncol(data)), collapse = ' | '), ' |')
  rows   <- apply(
    data,
    1,
    function(row) {
      paste0('| ', paste(row, collapse = ' | '), ' |')
    }
  )

  c(header, rule, rows)
}

parameterTable <- function(summaryRow) {
  excludedCols <- c(
    'modelId',
    'task',
    'modelFamily',
    'engine',
    'package',
    'status',
    'tuningMethod',
    'selectionRule',
    'primaryMetric',
    'cvMetricMean',
    'cvMetricStdErr',
    'foldCount',
    'initialSize',
    'bayesIter',
    'gridSize',
    'predictorCount',
    'trainRows',
    'validateRows',
    'fitSeconds',
    'predictSeconds',
    'mnLogLoss',
    'rocAuc',
    'brier',
    'accuracy',
    'mse',
    'rmse',
    'mae',
    'rsq',
    'notes'
  )

  paramCols <- setdiff(names(summaryRow), excludedCols)

  if (length(paramCols) == 0L) {
    return(tibble::tibble())
  }

  tibble::tibble(
    parameter = paramCols,
    value     = vapply(summaryRow[paramCols], formatScalar, character(1))
  ) |>
    dplyr::filter(!is.na(value), value != '')
}

metricTable <- function(summaryRow, task) {
  if (task == 'term') {
    return(
      tibble::tibble(
        metric = c('mnLogLoss', 'rocAuc', 'brier', 'accuracy'),
        value  = c(
          formatScalar(summaryRow$mnLogLoss, digits = 6L),
          formatScalar(summaryRow$rocAuc, digits = 6L),
          formatScalar(summaryRow$brier, digits = 6L),
          formatScalar(summaryRow$accuracy, digits = 6L)
        )
      )
    )
  }

  tibble::tibble(
    metric = c('rmse', 'mae', 'mse', 'rsq'),
    value  = c(
      formatScalar(summaryRow$rmse, digits = 6L),
      formatScalar(summaryRow$mae, digits = 6L),
      formatScalar(summaryRow$mse, digits = 8L),
      formatScalar(summaryRow$rsq, digits = 6L)
    )
  )
}

topCandidatesTable <- function(tuningTable, topN = 10L) {
  bestRows <- tuningTable |>
    dplyr::slice_head(n = topN)

  if (nrow(bestRows) == 0L) {
    return(tibble::tibble())
  }

  bestRows |>
    dplyr::mutate(
      mean    = formatScalar(mean, digits = 6L),
      std_err = formatScalar(std_err, digits = 6L)
    ) |>
    dplyr::select(-dplyr::any_of(c('.iter')))
}

writeMarkdownSummary <- function(summaryRow, tuningTable, outputPath) {
  taskName       <- summaryRow$task[[1L]]
  modelId        <- summaryRow$modelId[[1L]]
  modelFamily    <- summaryRow$modelFamily[[1L]]
  tuningMethod   <- summaryRow$tuningMethod[[1L]]
  parameterLines <- markdownTable(parameterTable(summaryRow))
  metricLines    <- markdownTable(metricTable(summaryRow, taskName))
  topLines       <- markdownTable(topCandidatesTable(tuningTable, topN = 10L))

  lines <- c(
    paste('#', modelId),
    '',
    '## Setup',
    '',
    paste0('- Task: `', taskName, '`.'),
    paste0('- Model family: `', modelFamily, '`.'),
    paste0('- Engine: `', summaryRow$engine[[1L]], '`.'),
    paste0('- Tuning method: `', tuningMethod, '`.'),
    paste0('- Grouped folds on `playerId`: `', summaryRow$foldCount[[1L]], '`.'),
    paste0('- Training rows: `', summaryRow$trainRows[[1L]], '`.'),
    paste0('- Validation rows: `', summaryRow$validateRows[[1L]], '`.'),
    paste0('- Predictor count after recipe: `', summaryRow$predictorCount[[1L]], '`.'),
    paste0('- Selection rule: `', summaryRow$selectionRule[[1L]], '`.'),
    paste0('- Primary CV metric: `', summaryRow$primaryMetric[[1L]], '`.'),
    paste0('- Selected CV mean: `', formatScalar(summaryRow$cvMetricMean, digits = 6L), '`.'),
    paste0('- Selected CV std. err.: `', formatScalar(summaryRow$cvMetricStdErr, digits = 6L), '`.')
  )

  if (!is.na(summaryRow$initialSize[[1L]])) {
    lines <- c(lines, paste0('- Initial design size: `', summaryRow$initialSize[[1L]], '`.'))
  }

  if (!is.na(summaryRow$bayesIter[[1L]])) {
    lines <- c(lines, paste0('- Bayesian iterations: `', summaryRow$bayesIter[[1L]], '`.'))
  }

  if (!is.na(summaryRow$gridSize[[1L]])) {
    lines <- c(lines, paste0('- Lambda grid size: `', summaryRow$gridSize[[1L]], '`.'))
  }

  if (!is.na(summaryRow$notes[[1L]]) && nzchar(summaryRow$notes[[1L]])) {
    lines <- c(lines, paste0('- Notes: ', summaryRow$notes[[1L]], '.'))
  }

  lines <- c(lines, '', '## Selected Parameters', '')

  if (length(parameterLines) == 0L) {
    lines <- c(lines, 'No tuned parameters recorded.')
  } else {
    lines <- c(lines, parameterLines)
  }

  lines <- c(lines, '', '## Validate Metrics', '')

  if (length(metricLines) == 0L) {
    lines <- c(lines, 'No held-out metrics recorded.')
  } else {
    lines <- c(lines, metricLines)
  }

  lines <- c(lines, '', '## Top CV Candidates', '')

  if (length(topLines) == 0L) {
    lines <- c(lines, 'No tuning candidates recorded.')
  } else {
    lines <- c(lines, topLines)
  }

  writeLines(lines, con = outputPath)
}

writeTuningOutputs <- function(modelId, summaryRow, tuningTable) {
  summaryPath <- file.path(resultsDir, paste0(modelId, '.csv'))
  tuningPath  <- file.path(resultsDir, paste0(modelId, '_tuning.csv'))
  mdPath      <- file.path(resultsDir, paste0(modelId, '.md'))

  readr::write_csv(summaryRow, summaryPath)
  readr::write_csv(tuningTable, tuningPath)
  writeMarkdownSummary(summaryRow, tuningTable, mdPath)

  invisible(
    list(
      summaryPath = summaryPath,
      tuningPath  = tuningPath,
      mdPath      = mdPath
    )
  )
}

validationMetricsFromFit <- function(task, fitObj, validateData, validateY) {
  if (task == 'term') {
    probPred  <- predict(fitObj, new_data = validateData, type = 'prob')
    classPred <- predict(fitObj, new_data = validateData, type = 'class')

    return(
      classificationMetrics(
        truth     = validateY,
        probPred  = probPred,
        classPred = classPred$.pred_class
      )
    )
  }

  predObj <- predict(fitObj, new_data = validateData)

  regressionMetrics(validateY, predObj$.pred)
}

matchingMetricRow <- function(tuningTable, bestParams, paramCols, task) {
  joined <- tuningTable |>
    dplyr::semi_join(bestParams, by = paramCols) |>
    arrangeMetricResults(task = task)

  if (nrow(joined) == 0L) {
    return(tibble::tibble())
  }

  joined |>
    dplyr::slice(1L)
}

runBayesWorkflow <- function(
  task,
  modelId,
  modelFamily,
  engine,
  package,
  spec,
  paramInfo,
  initialSize,
  bayesIter
) {
  if (!requireNamespace(package, quietly = TRUE)) {
    summaryRow <- resultRow(
      modelId        = modelId,
      modelFamily    = modelFamily,
      engine         = engine,
      package        = package,
      status         = 'skipped_missing_package',
      predictorCount = NA_real_,
      trainRows      = NA_real_,
      validateRows   = NA_real_,
      notes          = sprintf('Package %s not installed.', package)
    ) |>
      dplyr::mutate(
        task          = task,
        tuningMethod  = 'bayes',
        selectionRule = 'best',
        primaryMetric = primaryMetric(task),
        cvMetricMean  = NA_real_,
        cvMetricStdErr = NA_real_,
        foldCount     = NA_integer_,
        initialSize   = initialSize,
        bayesIter     = bayesIter,
        gridSize      = NA_integer_
      )

    emptyTuning <- tibble::tibble()
    writeTuningOutputs(modelId, summaryRow, emptyTuning, emptyTuning)

    return(summaryRow)
  }

  inputs   <- loadWorkflowInputs(task)
  workflow <- workflows::workflow() |>
    workflows::add_recipe(inputs$recipeSpec) |>
    workflows::add_model(spec)

  tuningTable <- tibble::tibble()

  result <- tryCatch(
    {
      set.seed(tuningSeed)

      initialGrid <- dials::grid_space_filling(paramInfo, size = initialSize)

      initialRes <- tune::tune_grid(
        workflow,
        resamples = inputs$resamples,
        grid      = initialGrid,
        metrics   = taskMetricSet(task),
        control   = tune::control_grid(
          verbose      = TRUE,
          allow_par    = FALSE,
          parallel_over = NULL,
          save_pred    = FALSE
        )
      )

      tuned <- tune::tune_bayes(
        workflow,
        resamples   = inputs$resamples,
        param_info  = paramInfo,
        metrics     = taskMetricSet(task),
        iter        = bayesIter,
        initial     = initialRes,
        control     = tune::control_bayes(
          verbose       = TRUE,
          verbose_iter  = TRUE,
          no_improve    = 6L,
          uncertain     = 5L,
          seed          = tuningSeed,
          allow_par     = FALSE,
          parallel_over = NULL,
          save_pred     = FALSE
        )
      )

      tuningTable   <- getBestMetricRow(tuned, task, topN = 50L)
      bestParams    <- tune::select_best(tuned, metric = primaryMetric(task))
      paramCols     <- names(bestParams)
      bestMetricRow <- matchingMetricRow(tuningTable, bestParams, paramCols, task)
      finalWorkflow <- tune::finalize_workflow(workflow, bestParams)
      fitStart      <- proc.time()
      finalFit      <- parsnip::fit(finalWorkflow, data = inputs$trainingData)
      fitSecs       <- elapsedSeconds(fitStart)
      predictStart  <- proc.time()
      metrics       <- validationMetricsFromFit(
        task         = task,
        fitObj       = finalFit,
        validateData = inputs$validateData,
        validateY    = inputs$prepared$validateY
      )
      predictSecs   <- elapsedSeconds(predictStart)

      summaryRow <- resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'ok',
        predictorCount = inputs$predictorCount,
        trainRows      = inputs$trainRows,
        validateRows   = inputs$validateRows,
        fitSeconds     = fitSecs,
        predictSeconds = predictSecs,
        metrics        = metrics
      ) |>
        dplyr::mutate(
          task           = task,
          tuningMethod   = 'bayes',
          selectionRule  = 'best',
          primaryMetric  = primaryMetric(task),
          cvMetricMean   = if (nrow(bestMetricRow) == 0L) NA_real_ else bestMetricRow$mean[[1L]],
          cvMetricStdErr = if (nrow(bestMetricRow) == 0L) NA_real_ else bestMetricRow$std_err[[1L]],
          foldCount      = inputs$foldCount,
          initialSize    = initialSize,
          bayesIter      = bayesIter,
          gridSize       = NA_integer_
        ) |>
        dplyr::bind_cols(bestParams)

      outputs <- writeTuningOutputs(modelId, summaryRow, tuningTable)

      list(
        summary = summaryRow,
        tuning  = tuningTable,
        outputs = outputs
      )
    },
    error = function(e) {
      summaryRow <- resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'error',
        predictorCount = inputs$predictorCount,
        trainRows      = inputs$trainRows,
        validateRows   = inputs$validateRows,
        notes          = e$message
      ) |>
        dplyr::mutate(
          task           = task,
          tuningMethod   = 'bayes',
          selectionRule  = 'best',
          primaryMetric  = primaryMetric(task),
          cvMetricMean   = NA_real_,
          cvMetricStdErr = NA_real_,
          foldCount      = inputs$foldCount,
          initialSize    = initialSize,
          bayesIter      = bayesIter,
          gridSize       = NA_integer_
        )

      outputs <- writeTuningOutputs(modelId, summaryRow, tuningTable)

      list(
        summary = summaryRow,
        tuning  = tuningTable,
        outputs = outputs
      )
    }
  )

  result$summary
}

runPenaltyWorkflow <- function(
  task,
  modelId,
  modelFamily,
  engine,
  package,
  spec
) {
  if (!requireNamespace(package, quietly = TRUE)) {
    summaryRow <- resultRow(
      modelId        = modelId,
      modelFamily    = modelFamily,
      engine         = engine,
      package        = package,
      status         = 'skipped_missing_package',
      predictorCount = NA_real_,
      trainRows      = NA_real_,
      validateRows   = NA_real_,
      notes          = sprintf('Package %s not installed.', package)
    ) |>
      dplyr::mutate(
        task           = task,
        tuningMethod   = 'cv_grid',
        selectionRule  = 'best',
        primaryMetric  = primaryMetric(task),
        cvMetricMean   = NA_real_,
        cvMetricStdErr = NA_real_,
        foldCount      = NA_integer_,
        initialSize    = NA_integer_,
        bayesIter      = NA_integer_,
        gridSize       = lambdaGridSize
      )

    emptyTuning <- tibble::tibble()
    writeTuningOutputs(modelId, summaryRow, emptyTuning, emptyTuning)

    return(summaryRow)
  }

  inputs   <- loadWorkflowInputs(task)
  workflow <- workflows::workflow() |>
    workflows::add_recipe(inputs$recipeSpec) |>
    workflows::add_model(spec)

  tuningTable <- tibble::tibble()

  result <- tryCatch(
    {
      params <- hardhat::extract_parameter_set_dials(workflow) |>
        update(
          penalty = dials::penalty(c(-5, 0))
        )

      penaltyGrid <- dials::grid_regular(params, levels = lambdaGridSize)

      tuned <- tune::tune_grid(
        workflow,
        resamples = inputs$resamples,
        grid      = penaltyGrid,
        metrics   = taskMetricSet(task),
        control   = tune::control_grid(
          verbose      = TRUE,
          allow_par    = FALSE,
          parallel_over = NULL,
          save_pred    = FALSE
        )
      )

      tuningTable   <- getBestMetricRow(tuned, task, topN = 50L)
      bestParams    <- tune::select_best(tuned, metric = primaryMetric(task))
      paramCols     <- names(bestParams)
      bestMetricRow <- matchingMetricRow(tuningTable, bestParams, paramCols, task)
      finalWorkflow <- tune::finalize_workflow(workflow, bestParams)
      fitStart      <- proc.time()
      finalFit      <- parsnip::fit(finalWorkflow, data = inputs$trainingData)
      fitSecs       <- elapsedSeconds(fitStart)
      predictStart  <- proc.time()
      metrics       <- validationMetricsFromFit(
        task         = task,
        fitObj       = finalFit,
        validateData = inputs$validateData,
        validateY    = inputs$prepared$validateY
      )
      predictSecs   <- elapsedSeconds(predictStart)

      summaryRow <- resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'ok',
        predictorCount = inputs$predictorCount,
        trainRows      = inputs$trainRows,
        validateRows   = inputs$validateRows,
        fitSeconds     = fitSecs,
        predictSeconds = predictSecs,
        metrics        = metrics
      ) |>
        dplyr::mutate(
          task           = task,
          tuningMethod   = 'cv_grid',
          selectionRule  = 'best',
          primaryMetric  = primaryMetric(task),
          cvMetricMean   = if (nrow(bestMetricRow) == 0L) NA_real_ else bestMetricRow$mean[[1L]],
          cvMetricStdErr = if (nrow(bestMetricRow) == 0L) NA_real_ else bestMetricRow$std_err[[1L]],
          foldCount      = inputs$foldCount,
          initialSize    = NA_integer_,
          bayesIter      = NA_integer_,
          gridSize       = lambdaGridSize
        ) |>
        dplyr::bind_cols(bestParams) |>
        dplyr::rename(lambda = penalty)

      outputs <- writeTuningOutputs(modelId, summaryRow, tuningTable)

      list(
        summary = summaryRow,
        tuning  = tuningTable,
        outputs = outputs
      )
    },
    error = function(e) {
      summaryRow <- resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'error',
        predictorCount = inputs$predictorCount,
        trainRows      = inputs$trainRows,
        validateRows   = inputs$validateRows,
        notes          = e$message
      ) |>
        dplyr::mutate(
          task           = task,
          tuningMethod   = 'cv_grid',
          selectionRule  = 'best',
          primaryMetric  = primaryMetric(task),
          cvMetricMean   = NA_real_,
          cvMetricStdErr = NA_real_,
          foldCount      = inputs$foldCount,
          initialSize    = NA_integer_,
          bayesIter      = NA_integer_,
          gridSize       = lambdaGridSize
        )

      outputs <- writeTuningOutputs(modelId, summaryRow, tuningTable)

      list(
        summary = summaryRow,
        tuning  = tuningTable,
        outputs = outputs
      )
    }
  )

  result$summary
}
