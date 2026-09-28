resolve_workspace_file <- function(workspace, relative, root = workspace) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative), winslash = "/", mustWork = FALSE)
  if (!startsWith(candidate, paste0(root, "/")) && candidate != root) stop("Caminho fora do diretório permitido.")
  candidate
}

list_r_scripts <- function(workspace) {
  files <- list.files(workspace, recursive = TRUE, full.names = FALSE, pattern = "\\.R$", ignore.case = TRUE)
  files[!grepl("^(app/|renv/|logs/|output/|assets/)", files, ignore.case = TRUE)]
}

new_script_runner <- function(workspace, timeout_seconds = 3600) {
  runner <- new.env(parent = emptyenv())
  runner$workspace <- workspace; runner$timeout_seconds <- timeout_seconds; runner$process <- NULL
  runner$script <- NULL; runner$started_at <- NULL; runner$finished_at <- NULL; runner$status <- "Pronto"
  runner$exit_status <- NULL; runner$log_file <- NULL
  class(runner) <- "r_lab_script_runner"
  runner
}

script_runner_start <- function(runner, relative_script) {
  if (!is.null(runner$process) && runner$process$is_alive()) stop("Já existe um script em execução.")
  if (!relative_script %in% list_r_scripts(runner$workspace)) stop("Script inválido ou inexistente.")
  script_path <- resolve_workspace_file(runner$workspace, relative_script)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  safe_name <- gsub("[^A-Za-z0-9_.-]", "_", relative_script)
  log_file <- file.path(runner$workspace, "logs", paste0(stamp, "-", safe_name, ".log"))
  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(paste0("Script: ", relative_script), paste0("Início: ", format(Sys.time())), paste0("Diretório de trabalho: ", runner$workspace), "---"), log_file)
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
    runner$process$kill_tree(); runner$status <- "Tempo excedido"; runner$finished_at <- Sys.time()
  } else if (!runner$process$is_alive() && identical(runner$status, "Executando")) {
    script_runner_drain(runner); runner$exit_status <- runner$process$get_exit_status()
    runner$status <- if (identical(runner$exit_status, 0L)) "Concluído" else "Falhou"; runner$finished_at <- Sys.time()
  }
  invisible(runner)
}

script_runner_stop <- function(runner) {
  if (!is.null(runner$process) && runner$process$is_alive()) {
    runner$process$kill_tree(); runner$status <- "Interrompido"; runner$finished_at <- Sys.time()
  }
  invisible(runner)
}

script_runner_log <- function(runner, n = 800L) {
  if (is.null(runner$log_file) || !file.exists(runner$log_file)) return("Nenhuma execução iniciada.")
  lines <- readLines(runner$log_file, warn = FALSE, encoding = "UTF-8")
  if (!length(lines)) return("Aguardando saída...")
  paste(tail(lines, n), collapse = "\n")
}
