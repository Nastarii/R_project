resolve_workspace_file <- function(workspace, relative, root = workspace) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative), winslash = "/", mustWork = FALSE)
  if (!startsWith(candidate, paste0(root, "/")) && candidate != root) stop("Caminho fora do diretorio permitido.")
  candidate
}

list_r_scripts <- function(workspace) {
  files <- list.files(workspace, recursive = TRUE, full.names = FALSE, pattern = "\\.R$", ignore.case = TRUE)
  files[!grepl("^(app/|renv/|logs/|output/|assets/)", files, ignore.case = TRUE)]
}

list_log_history <- function(workspace) {
  root <- file.path(workspace, "logs")
  empty <- data.frame(tipo = character(), arquivo = character(), caminho = character(), label = character(), tamanho = character(), modificado = character(), stringsAsFactors = FALSE)
  if (!dir.exists(root)) return(empty)
  files <- list.files(root, recursive = TRUE, full.names = FALSE)
  files <- files[!dir.exists(file.path(root, files))]
  if (!length(files)) return(empty)
  paths <- file.path(root, files); info <- file.info(paths)
  kind <- ifelse(grepl("^packages-", basename(files), ignore.case = TRUE), "Pacotes", "Script")
  modified <- format(info$mtime, "%d/%m/%Y %H:%M:%S")
  result <- data.frame(tipo = kind, arquivo = basename(files), caminho = file.path("logs", files), label = paste0(modified, " - ", kind, " - ", basename(files)), tamanho = format_bytes_result(paths), modificado = modified, stringsAsFactors = FALSE)
  result[order(info$mtime, decreasing = TRUE), , drop = FALSE]
}

log_history_path <- function(workspace, relative) {
  if (!startsWith(relative, "logs/")) stop("Log invalido.")
  resolve_workspace_file(workspace, sub("^logs/", "", relative), file.path(workspace, "logs"))
}

read_log_history <- function(workspace, relative, n = 1200L) {
  path <- log_history_path(workspace, relative)
  if (!file.exists(path)) return("Log nao encontrado.")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (!length(lines)) return("Log vazio.")
  paste(tail(lines, n), collapse = "\n")
}

delete_log_file <- function(workspace, relative) {
  path <- log_history_path(workspace, relative)
  if (file.exists(path)) isTRUE(file.remove(path)) else FALSE
}

delete_all_log_files <- function(workspace, keep = character()) {
  history <- list_log_history(workspace)
  if (!nrow(history)) return(0L)
  targets <- setdiff(history$caminho, keep)
  sum(vapply(targets, function(path) delete_log_file(workspace, path), logical(1)))
}

new_script_runner <- function(workspace, timeout_seconds = 3600) {
  runner <- new.env(parent = emptyenv())
  runner$workspace <- workspace; runner$timeout_seconds <- timeout_seconds; runner$process <- NULL
  runner$script <- NULL; runner$started_at <- NULL; runner$finished_at <- NULL; runner$status <- "Pronto"
  runner$exit_status <- NULL; runner$log_file <- NULL
  class(runner) <- "r_lab_script_runner"
  runner
}

append_runner_summary <- function(runner) {
  if (is.null(runner$log_file) || is.null(runner$finished_at)) return(invisible(NULL))
  elapsed <- if (is.null(runner$started_at)) "-" else paste0(round(as.numeric(difftime(runner$finished_at, runner$started_at, units = "secs")), 1), " s")
  code <- if (is.null(runner$exit_status)) "-" else as.character(runner$exit_status)
  writeLines(c(paste0("[R LAB] Status: ", runner$status), paste0("[R LAB] Codigo: ", code), paste0("[R LAB] Duracao: ", elapsed), paste0("[R LAB] Fim: ", format(runner$finished_at))), runner$log_file, sep = "\n", useBytes = TRUE)
  invisible(NULL)
}

script_runner_start <- function(runner, relative_script) {
  if (!is.null(runner$process) && runner$process$is_alive()) stop("Ja existe um script em execucao.")
  if (!relative_script %in% list_r_scripts(runner$workspace)) stop("Script invalido ou inexistente.")
  script_path <- resolve_workspace_file(runner$workspace, relative_script)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  safe_name <- gsub("[^A-Za-z0-9_.-]", "_", relative_script)
  log_file <- file.path(runner$workspace, "logs", paste0(stamp, "-", safe_name, ".log"))
  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(paste0("Script: ", relative_script), paste0("Inicio: ", format(Sys.time())), paste0("Diretorio de trabalho: ", runner$workspace), "---"), log_file)
  runner$process <- processx::process$new("Rscript", c("--vanilla", script_path), wd = runner$workspace, stdout = "|", stderr = "|", cleanup = TRUE)
  runner$script <- relative_script; runner$log_file <- log_file; runner$started_at <- Sys.time(); runner$finished_at <- NULL
  runner$exit_status <- NULL; runner$status <- "Executando"
  invisible(runner)
}

script_runner_drain <- function(runner) {
  if (is.null(runner$process)) return(invisible(NULL))
  append_lines <- function(lines, prefix = "") if (length(lines)) write(paste0(prefix, lines), file = runner$log_file, append = TRUE)
  append_lines(runner$process$read_output_lines()); append_lines(runner$process$read_error_lines(), "[stderr] ")
  invisible(NULL)
}

script_runner_tick <- function(runner) {
  if (is.null(runner$process)) return(invisible(runner))
  script_runner_drain(runner)
  if (runner$process$is_alive() && difftime(Sys.time(), runner$started_at, units = "secs") > runner$timeout_seconds) {
    runner$process$kill_tree(); runner$status <- "Tempo excedido"; runner$finished_at <- Sys.time(); append_runner_summary(runner)
  } else if (!runner$process$is_alive() && identical(runner$status, "Executando")) {
    script_runner_drain(runner); runner$exit_status <- runner$process$get_exit_status(); runner$status <- if (identical(runner$exit_status, 0L)) "Concluido" else "Falhou"; runner$finished_at <- Sys.time(); append_runner_summary(runner)
  }
  invisible(runner)
}

script_runner_stop <- function(runner) {
  if (!is.null(runner$process) && runner$process$is_alive()) {
    runner$process$kill_tree(); runner$status <- "Interrompido"; runner$exit_status <- NA_integer_; runner$finished_at <- Sys.time(); append_runner_summary(runner)
  }
  invisible(runner)
}

script_runner_log <- function(runner, n = 800L) {
  if (is.null(runner$log_file) || !file.exists(runner$log_file)) return("Nenhuma execucao iniciada.")
  lines <- readLines(runner$log_file, warn = FALSE, encoding = "UTF-8")
  if (!length(lines)) return("Aguardando saida...")
  paste(tail(lines, n), collapse = "\n")
}
