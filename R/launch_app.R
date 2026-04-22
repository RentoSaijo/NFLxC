#!/usr/bin/env Rscript

# —— Constants —— #
host        <- '127.0.0.1'
port        <- 8181L
projectDir  <- normalizePath('.', winslash = '/', mustWork = TRUE)
appUrl      <- sprintf('http://%s:%s/', host, port)
pythonBin   <- Sys.which('python3')

if (!nzchar(pythonBin)) {
  stop('python3 is required to serve the static app.', call. = FALSE)
}

# This opens the browser, then keeps the local server process alive.
message(sprintf('Serving %s at %s', projectDir, appUrl))

utils::browseURL(appUrl)

status <- system2(
  command = pythonBin,
  args    = c(
    '-m', 'http.server',
    as.character(port),
    '--bind', host,
    '--directory', projectDir
  ),
  wait    = TRUE
)

quit(save = 'no', status = status)
