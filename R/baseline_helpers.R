#!/usr/bin/env Rscript

options(readr.show_col_types = FALSE)

# —— Packages —— #
requiredPkgs <- c(
  'dplyr',
  'parsnip',
  'readr',
  'recipes',
  'rlang',
  'tibble',
  'yardstick'
)

missingPkgs  <- requiredPkgs[!vapply(requiredPkgs, requireNamespace, logical(1), quietly = TRUE)]

if (length(missingPkgs) > 0L) {
  stop(
    paste0(
      'Missing package(s): ',
      paste(missingPkgs, collapse = ', '),
      '. Install them with install.packages(c(',
      paste(paste0('\'', missingPkgs, '\''), collapse = ', '),
      ')).'
    ),
    call. = FALSE
  )
}

invisible(
  lapply(
    c('bonsai'),
    function(pkg) {
      if (requireNamespace(pkg, quietly = TRUE)) {
        loadNamespace(pkg)
      }
    }
  )
)

# —— Paths —— #
trainPath     <- file.path('data', 'train.csv')
validatePath  <- file.path('data', 'validate.csv')
resultsDir    <- 'results'
baselineSeed  <- 20260322L
termLevels    <- as.character(1:5)

dir.create(resultsDir, recursive = TRUE, showWarnings = FALSE)

# —— Columns —— #
idCols <- c(
  'contractRowId',
  'sourceFile',
  'playerName',
  'playerKey',
  'playerId',
  'pfrId',
  'birthDate'
)

sharedDropCols <- c(
  'dateOfSigningObserved',
  'featureReferenceDate',
  'signingDateObserved',
  'signingDateSource',
  'signedTeam',
  'isEntryLike'
)

termDropCols <- c(
  'aav',
  'aavPerc'
)

aavPercDropCols <- c(
  'aav'
)

# —— Helpers —— #
responseCol <- function(task) {
  if (task == 'term') {
    return('term')
  }

  if (task == 'aavPerc') {
    return('aavPerc')
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

dropCols <- function(task) {
  if (task == 'term') {
    return(c(sharedDropCols, termDropCols))
  }

  if (task == 'aavPerc') {
    return(c(sharedDropCols, aavPercDropCols))
  }

  stop(sprintf('Unknown task: %s', task), call. = FALSE)
}

nullDefault <- function(x, default) {
  if (is.null(x)) {
    return(default)
  }

  x
}

coerceLogicalToFactor <- function(data, response = NULL) {
  logicalCols <- setdiff(names(data)[vapply(data, is.logical, logical(1))], response)

  if (length(logicalCols) == 0L) {
    return(data)
  }

  data |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(logicalCols),
        ~ factor(dplyr::if_else(.x, 'yes', 'no'), levels = c('no', 'yes'))
      )
    )
}

loadTaskFrame <- function(task, path) {
  data <- readr::read_csv(path, show_col_types = FALSE)

  data <- data |>
    dplyr::mutate(
      contractRowId         = as.integer(contractRowId),
      dateOfSigningObserved = as.Date(dateOfSigningObserved),
      featureReferenceDate  = as.Date(featureReferenceDate),
      signingDateObserved   = as.logical(signingDateObserved),
      signingDateSource     = as.character(signingDateSource),
      startYear             = as.integer(startYear),
      aav                   = as.numeric(aav),
      aavPerc               = as.numeric(aavPerc),
      signedTeam            = as.character(signedTeam),
      draftYear             = as.integer(draftYear),
      draftRound            = as.integer(draftRound),
      draftPick             = as.integer(draftPick),
      rookieSeason          = as.integer(rookieSeason),
      prevContractStartYear = as.integer(prevContractStartYear),
      prevContractEndYear   = as.integer(prevContractEndYear),
      prev1Season           = as.integer(prev1Season),
      prev2Season           = as.integer(prev2Season),
      birthDate             = as.Date(birthDate),
      isEntryLike           = as.logical(isEntryLike)
    )

  if (task == 'term') {
    data <- data |>
      dplyr::mutate(
        term = factor(as.integer(term), levels = termLevels)
      )
  } else {
    data <- data |>
      dplyr::mutate(
        term = factor(as.integer(term), levels = termLevels),
        aavPerc = as.numeric(aavPerc)
      )
  }

  coerceLogicalToFactor(data, response = responseCol(task))
}

buildRecipe <- function(task, trainingData) {
  response <- responseCol(task)

  recipes::recipe(stats::as.formula(paste(response, '~ .')), data = trainingData) |>
    recipes::update_role(tidyselect::any_of(idCols), new_role = 'id') |>
    recipes::step_rm(tidyselect::any_of(dropCols(task))) |>
    recipes::step_string2factor(recipes::all_nominal_predictors()) |>
    recipes::step_unknown(recipes::all_nominal_predictors()) |>
    recipes::step_novel(recipes::all_nominal_predictors()) |>
    recipes::step_impute_mode(recipes::all_nominal_predictors()) |>
    recipes::step_dummy(recipes::all_nominal_predictors()) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_zv(recipes::all_predictors()) |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

prepareTaskData <- function(task) {
  trainingData  <- loadTaskFrame(task, trainPath)
  validateData  <- loadTaskFrame(task, validatePath)
  recipeSpec    <- buildRecipe(task, trainingData)
  recipePrep    <- recipes::prep(recipeSpec, training = trainingData, retain = TRUE)
  trainX        <- recipes::juice(recipePrep, recipes::all_predictors())
  validateX     <- recipes::bake(recipePrep, new_data = validateData, recipes::all_predictors())
  trainY        <- recipes::juice(recipePrep, recipes::all_outcomes())[[responseCol(task)]]
  validateY     <- validateData[[responseCol(task)]]

  list(
    trainingData   = trainingData,
    validateData   = validateData,
    recipe         = recipePrep,
    trainX         = trainX,
    validateX      = validateX,
    trainY         = trainY,
    validateY      = validateY,
    predictorCount = ncol(trainX),
    trainRows      = nrow(trainX),
    validateRows   = nrow(validateX)
  )
}

expectedProbCols <- function(levelsVec) {
  paste0('.pred_', levelsVec)
}

alignProbabilities <- function(probPred, levelsVec) {
  probCols <- expectedProbCols(levelsVec)
  out      <- tibble::as_tibble(probPred)

  missingCols <- setdiff(probCols, names(out))

  if (length(missingCols) > 0L) {
    for (col in missingCols) {
      out[[col]] <- 0
    }
  }

  out[, probCols, drop = FALSE]
}

multiclassBrier <- function(truth, probPred) {
  levelsVec <- levels(truth)
  probCols  <- expectedProbCols(levelsVec)
  probs     <- as.matrix(probPred[, probCols, drop = FALSE])
  truthMat  <- stats::model.matrix(~ truth - 1)

  colnames(truthMat) <- probCols

  mean(rowMeans((probs - truthMat) ^ 2))
}

classificationMetrics <- function(truth, probPred = NULL, classPred = NULL) {
  levelsVec  <- levels(truth)
  metricData <- tibble::tibble(truth = truth)

  if (!is.null(probPred)) {
    probPred   <- alignProbabilities(probPred, levelsVec)
    metricData <- dplyr::bind_cols(metricData, probPred)
  }

  if (!is.null(classPred)) {
    metricData$estimate <- classPred
  } else if (!is.null(probPred)) {
    probMat <- as.matrix(probPred)
    metricData$estimate <- factor(
      levelsVec[max.col(probMat, ties.method = 'first')],
      levels = levelsVec
    )
  } else {
    metricData$estimate <- factor(NA_character_, levels = levelsVec)
  }

  observedLevels <- sort(unique(as.character(truth)))
  rocData        <- if (!is.null(probPred)) {
    dplyr::bind_cols(
      tibble::tibble(truth = factor(as.character(truth), levels = observedLevels)),
      probPred[, expectedProbCols(observedLevels), drop = FALSE]
    )
  } else {
    NULL
  }

  mnLogLoss <- if (!is.null(probPred)) {
    yardstick::mn_log_loss(
      metricData,
      truth = truth,
      !!!rlang::syms(expectedProbCols(levelsVec))
    )$.estimate[[1L]]
  } else {
    NA_real_
  }

  rocAuc <- if (!is.null(rocData) && length(observedLevels) >= 2L) {
    yardstick::roc_auc(
      rocData,
      truth = truth,
      !!!rlang::syms(expectedProbCols(observedLevels)),
      estimator = 'hand_till'
    )$.estimate[[1L]]
  } else {
    NA_real_
  }

  brierScore <- if (!is.null(probPred)) {
    multiclassBrier(truth, probPred)
  } else {
    NA_real_
  }

  accuracy <- yardstick::accuracy(metricData, truth = truth, estimate = estimate)$.estimate[[1L]]

  list(
    mnLogLoss = mnLogLoss,
    rocAuc    = rocAuc,
    brier     = brierScore,
    accuracy  = accuracy
  )
}

regressionMetrics <- function(truth, estimate) {
  list(
    mse  = mean((truth - estimate) ^ 2),
    rmse = yardstick::rmse_vec(truth = truth, estimate = estimate),
    mae  = yardstick::mae_vec(truth = truth, estimate = estimate),
    rsq  = yardstick::rsq_vec(truth = truth, estimate = estimate)
  )
}

elapsedSeconds <- function(startTime) {
  as.numeric((proc.time() - startTime)[['elapsed']])
}

safePredict <- function(object, newData, type = NULL) {
  tryCatch(
    {
      if (is.null(type)) {
        predict(object, new_data = newData)
      } else {
        predict(object, new_data = newData, type = type)
      }
    },
    error = function(e) e
  )
}

resultRow <- function(
  modelId,
  modelFamily,
  engine,
  status,
  package,
  predictorCount,
  trainRows,
  validateRows,
  fitSeconds      = NA_real_,
  predictSeconds  = NA_real_,
  notes           = NA_character_,
  metrics         = list()
) {
  tibble::tibble(
    modelId         = modelId,
    modelFamily     = modelFamily,
    engine          = engine,
    package         = package,
    status          = status,
    predictorCount  = predictorCount,
    trainRows       = trainRows,
    validateRows    = validateRows,
    fitSeconds      = fitSeconds,
    predictSeconds  = predictSeconds,
    mnLogLoss       = nullDefault(metrics[['mnLogLoss']], NA_real_),
    rocAuc          = nullDefault(metrics[['rocAuc']], NA_real_),
    brier           = nullDefault(metrics[['brier']], NA_real_),
    accuracy        = nullDefault(metrics[['accuracy']], NA_real_),
    mse             = nullDefault(metrics[['mse']], NA_real_),
    rmse            = nullDefault(metrics[['rmse']], NA_real_),
    mae             = nullDefault(metrics[['mae']], NA_real_),
    rsq             = nullDefault(metrics[['rsq']], NA_real_),
    notes           = notes
  )
}

runParsnipClassification <- function(prepared, modelId, modelFamily, engine, package, builder, yOverride = NULL) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'skipped_missing_package',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        notes          = sprintf('Package %s not installed.', package)
      )
    )
  }

  set.seed(baselineSeed)

  fitStart <- proc.time()
  fitObj   <- tryCatch(
    parsnip::fit_xy(
      builder(prepared$predictorCount),
      x = prepared$trainX,
      y = if (is.null(yOverride)) prepared$trainY else yOverride(prepared$trainY)
    ),
    error = function(e) e
  )
  fitSecs <- elapsedSeconds(fitStart)

  if (inherits(fitObj, 'error')) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'fit_error',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        fitSeconds     = fitSecs,
        notes          = fitObj$message
      )
    )
  }

  predictStart <- proc.time()
  probPred     <- safePredict(fitObj, prepared$validateX, type = 'prob')
  classPred    <- safePredict(fitObj, prepared$validateX, type = 'class')
  predictSecs  <- elapsedSeconds(predictStart)

  if (inherits(probPred, 'error')) {
    probPred <- NULL
  }

  if (inherits(classPred, 'error')) {
    classPred <- NULL
  } else {
    classPred <- classPred$.pred_class
  }

  metrics <- classificationMetrics(
    truth    = prepared$validateY,
    probPred = probPred,
    classPred = classPred
  )

  resultRow(
    modelId        = modelId,
    modelFamily    = modelFamily,
    engine         = engine,
    package        = package,
    status         = 'ok',
    predictorCount = prepared$predictorCount,
    trainRows      = prepared$trainRows,
    validateRows   = prepared$validateRows,
    fitSeconds     = fitSecs,
    predictSeconds = predictSecs,
    metrics        = metrics
  )
}

runParsnipRegression <- function(prepared, modelId, modelFamily, engine, package, builder) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'skipped_missing_package',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        notes          = sprintf('Package %s not installed.', package)
      )
    )
  }

  set.seed(baselineSeed)

  fitStart <- proc.time()
  fitObj   <- tryCatch(
    parsnip::fit_xy(
      builder(prepared$predictorCount),
      x = prepared$trainX,
      y = prepared$trainY
    ),
    error = function(e) e
  )
  fitSecs <- elapsedSeconds(fitStart)

  if (inherits(fitObj, 'error')) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'fit_error',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        fitSeconds     = fitSecs,
        notes          = fitObj$message
      )
    )
  }

  predictStart <- proc.time()
  predObj      <- safePredict(fitObj, prepared$validateX)
  predictSecs  <- elapsedSeconds(predictStart)

  if (inherits(predObj, 'error')) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = modelFamily,
        engine         = engine,
        package        = package,
        status         = 'predict_error',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        fitSeconds     = fitSecs,
        predictSeconds = predictSecs,
        notes          = predObj$message
      )
    )
  }

  metrics <- regressionMetrics(prepared$validateY, predObj$.pred)

  resultRow(
    modelId        = modelId,
    modelFamily    = modelFamily,
    engine         = engine,
    package        = package,
    status         = 'ok',
    predictorCount = prepared$predictorCount,
    trainRows      = prepared$trainRows,
    validateRows   = prepared$validateRows,
    fitSeconds     = fitSecs,
    predictSeconds = predictSecs,
    metrics        = metrics
  )
}

runOrderedLogit <- function(prepared, modelId = 'ordinal_logit_mass') {
  if (!requireNamespace('MASS', quietly = TRUE)) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = 'ordinal_logistic',
        engine         = 'polr',
        package        = 'MASS',
        status         = 'skipped_missing_package',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        notes          = 'Package MASS not installed.'
      )
    )
  }

  trainData <- dplyr::bind_cols(
    tibble::tibble(term = ordered(prepared$trainY, levels = levels(prepared$trainY))),
    prepared$trainX
  )
  validateData <- prepared$validateX

  fitStart <- proc.time()
  fitObj   <- tryCatch(
    MASS::polr(term ~ ., data = trainData, method = 'logistic', Hess = TRUE, model = FALSE),
    error = function(e) e
  )
  fitSecs <- elapsedSeconds(fitStart)

  if (inherits(fitObj, 'error')) {
    return(
      resultRow(
        modelId        = modelId,
        modelFamily    = 'ordinal_logistic',
        engine         = 'polr',
        package        = 'MASS',
        status         = 'fit_error',
        predictorCount = prepared$predictorCount,
        trainRows      = prepared$trainRows,
        validateRows   = prepared$validateRows,
        fitSeconds     = fitSecs,
        notes          = fitObj$message
      )
    )
  }

  predictStart <- proc.time()
  probPred     <- tryCatch(
    tibble::as_tibble(predict(fitObj, newdata = validateData, type = 'probs')),
    error = function(e) e
  )
  classPred    <- tryCatch(
    predict(fitObj, newdata = validateData, type = 'class'),
    error = function(e) e
  )
  predictSecs <- elapsedSeconds(predictStart)

  if (inherits(probPred, 'error')) {
    probPred <- NULL
  } else {
    names(probPred) <- expectedProbCols(names(probPred))
  }

  if (inherits(classPred, 'error')) {
    classPred <- NULL
  } else {
    classPred <- factor(as.character(classPred), levels = levels(prepared$validateY))
  }

  metrics <- classificationMetrics(
    truth     = prepared$validateY,
    probPred  = probPred,
    classPred = classPred
  )

  resultRow(
    modelId        = modelId,
    modelFamily    = 'ordinal_logistic',
    engine         = 'polr',
    package        = 'MASS',
    status         = 'ok',
    predictorCount = prepared$predictorCount,
    trainRows      = prepared$trainRows,
    validateRows   = prepared$validateRows,
    fitSeconds     = fitSecs,
    predictSeconds = predictSecs,
    metrics        = metrics
  )
}

bayesSkippedRow <- function(task) {
  resultRow(
    modelId        = if (task == 'term') 'bayes_classifier_unavailable' else 'bayes_regression_unavailable',
    modelFamily    = if (task == 'term') 'bayesian_classification' else 'bayesian_regression',
    engine         = 'unavailable',
    package        = 'brulee/rstanarm',
    status         = 'skipped_missing_package',
    predictorCount = NA_real_,
    trainRows      = NA_real_,
    validateRows   = NA_real_,
    notes          = 'No supported Bayesian baseline package is installed in this environment.'
  )
}
