artifact_roots <- function(workspace) c(output = file.path(workspace, "output"), assets = file.path(workspace, "assets"))

format_bytes_result <- function(paths) {
  vapply(paths, function(path) {
    bytes <- file.info(path)$size
    if (is.na(bytes)) return("-")
    if (bytes < 1024) return(sprintf("%d B", bytes))
    if (bytes < 1024^2) return(sprintf("%.1f KB", bytes / 1024))
    sprintf("%.1f MB", bytes / 1024^2)
  }, character(1))
}

list_artifacts <- function(workspace) {
  roots <- artifact_roots(workspace)
  rows <- do.call(rbind, lapply(names(roots), function(kind) {
    root <- roots[[kind]]
    if (!dir.exists(root)) return(NULL)
    files <- list.files(root, recursive = TRUE, full.names = FALSE)
    files <- files[!dir.exists(file.path(root, files))]
    if (!length(files)) return(NULL)
    paths <- file.path(root, files)
    data.frame(tipo = kind, arquivo = files, caminho = file.path(kind, files),
               tamanho = format_bytes_result(paths), modificado = as.character(file.info(paths)$mtime),
               stringsAsFactors = FALSE)
  }))
  if (is.null(rows)) data.frame(tipo = character(), arquivo = character(), caminho = character(),
                                tamanho = character(), modificado = character()) else rows
}

artifact_path <- function(workspace, relative) {
  roots <- artifact_roots(workspace)
  kind <- if (startsWith(relative, "output/")) "output" else if (startsWith(relative, "assets/")) "assets" else stop("Arquivo inválido.")
  resolve_workspace_file(workspace, sub(paste0("^", kind, "/"), "", relative), roots[[kind]])
}

table_artifacts <- function(workspace) {
  artifacts <- list_artifacts(workspace)
  artifacts[grepl("\\.(csv|tsv)$", artifacts$caminho, ignore.case = TRUE), , drop = FALSE]
}

read_result_table <- function(workspace, relative) {
  path <- artifact_path(workspace, relative)
  if (grepl("\\.tsv$", path, ignore.case = TRUE)) return(read.delim(path, check.names = FALSE))
  read.csv(path, check.names = FALSE)
}

tail_result_file <- function(workspace, relative, n = 1000L) {
  lines <- readLines(artifact_path(workspace, relative), warn = FALSE, encoding = "UTF-8")
  paste(tail(lines, n), collapse = "\n")
}
