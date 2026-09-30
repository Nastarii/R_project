resolve_workspace_file <- function(workspace, relative, root = workspace) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidate <- normalizePath(file.path(root, relative), winslash = "/", mustWork = FALSE)
  if (!startsWith(candidate, paste0(root, "/")) && candidate != root) stop("Caminho fora do diretorio permitido.")
  candidate
}

normalise_logical_path <- function(path) gsub("^\\./|\\\\", "/", path)

r_files_under <- function(root) {
  if (!is.character(root) || !length(root) || !dir.exists(root)) return(character())
  files <- list.files(root, recursive = TRUE, full.names = FALSE, pattern = "\\.R$", ignore.case = TRUE)
  normalise_logical_path(files)
}

list_r_scripts <- function(workspace, project_root = NULL) {
  if (!is.character(project_root) || !length(project_root) || !dir.exists(project_root)) return(character())
  sort(unique(r_files_under(project_root)))
}

list_script_folders <- function(workspace, project_root = NULL) {
  scripts <- list_r_scripts(workspace, project_root)
  if (!length(scripts)) return("")
  folders <- unique(unlist(lapply(scripts, function(script) {
    folder <- dirname(script)
    parts <- if (identical(folder, ".")) character() else strsplit(folder, "/", fixed = TRUE)[[1]]
    if (!length(parts)) return("")
    c("", vapply(seq_along(parts), function(n) paste(parts[seq_len(n)], collapse = "/"), character(1)))
  })))
  sort(folders)
}

script_tree_children <- function(workspace, folder = "", project_root = NULL) {
  scripts <- list_r_scripts(workspace, project_root)
  folders <- list_script_folders(workspace, project_root)
  folder <- normalise_logical_path(if (is.null(folder)) "" else folder)
  folder <- sub("/$", "", folder)
  child_folders <- folders[folders != "" & dirname(folders) == if (nzchar(folder)) folder else "."]
  child_scripts <- scripts[dirname(scripts) == if (nzchar(folder)) folder else "."]
  data.frame(
    tipo = c(rep("pasta", length(child_folders)), rep("script", length(child_scripts))),
    caminho = c(child_folders, child_scripts),
    nome = c(basename(child_folders), basename(child_scripts)),
    stringsAsFactors = FALSE
  )
}

script_root_path <- function(workspace, logical, project_root = NULL) {
  if (!is.character(project_root) || !length(project_root) || !dir.exists(project_root)) stop("A pasta de projetos nao esta montada.")
  resolve_workspace_file(workspace, normalise_logical_path(logical), project_root)
}

script_display_path <- function(logical) paste0("/projects/", normalise_logical_path(logical))
new_script_runner <- function(workspace, timeout_seconds = 3600, project_root = NULL) {
  runner <- new.env(parent = emptyenv())
  runner$workspace <- workspace
  runner$project_root <- project_root
  runner$timeout_seconds <- timeout_seconds
  runner$process <- NULL
  runner$script <- NULL
  runner$started_at <- NULL
  runner$finished_at <- NULL
  runner$status <- "Pronto"
runner$exit_status <- NULL
  runner$log_lines <- character()
  class(runner) <- "r_lab_script_runner"
  runner
}

script_runner_active <- function(runner) {
  !is.null(runner$process) && identical(runner$status, "Executando") && runner$process$is_alive()
}

append_runner_summary <- function(runner) {
  if (is.null(runner$finished_at)) return(invisible(NULL))
  elapsed <- if (is.null(runner$started_at)) "-" else paste0(round(as.numeric(difftime(runner$finished_at, runner$started_at, units = "secs")), 1), " s")
  code <- if (is.null(runner$exit_status)) "-" else as.character(runner$exit_status)
  runner$log_lines <- c(runner$log_lines, paste0("[R LAB] Status: ", runner$status), paste0("[R LAB] Codigo: ", code), paste0("[R LAB] Duracao: ", elapsed), paste0("[R LAB] Fim: ", format(runner$finished_at)))
  invisible(NULL)
}

script_runner_start <- function(runner, relative_script) {
  if (script_runner_active(runner)) stop("Ja existe um script em execucao.")
  scripts <- list_r_scripts(runner$workspace, runner$project_root)
  relative_script <- normalise_logical_path(relative_script)
  if (!relative_script %in% scripts) stop("Script invalido ou inexistente.")
  script_path <- script_root_path(runner$workspace, relative_script, runner$project_root)
  if (!file.exists(script_path)) stop("O arquivo selecionado nao esta disponivel.")
  started <- Sys.time()
  runner$process <- processx::process$new("Rscript", c("--vanilla", script_path), wd = runner$project_root, stdout = "|", stderr = "|", cleanup = TRUE)
  runner$script <- relative_script
  runner$project_root <- runner$project_root
  runner$log_lines <- c(paste0("Script: ", relative_script), paste0("Inicio: ", format(started)), paste0("Diretorio de trabalho: ", runner$workspace), "---")
  runner$started_at <- started
  runner$finished_at <- NULL
  runner$exit_status <- NULL
  runner$status <- "Executando"
  invisible(runner)
}

script_runner_drain <- function(runner) {
  if (is.null(runner$process)) return(invisible(NULL))
  runner$process$poll_io(0)
  append_lines <- function(lines, prefix = "") if (length(lines)) runner$log_lines <- c(runner$log_lines, paste0(prefix, lines))
  append_lines(runner$process$read_output_lines())
  append_lines(runner$process$read_error_lines(), "[stderr] ")
  invisible(NULL)
}

script_runner_tick <- function(runner) {
  if (is.null(runner$process) || !identical(runner$status, "Executando")) return(invisible(runner))
  script_runner_drain(runner)
  if (runner$process$is_alive() && difftime(Sys.time(), runner$started_at, units = "secs") > runner$timeout_seconds) {
    runner$process$kill_tree()
    runner$process$wait(timeout = 1000)
    script_runner_drain(runner)
    runner$exit_status <- NA_integer_
    runner$status <- "Tempo excedido"
    runner$finished_at <- Sys.time()
    append_runner_summary(runner)
  } else if (!runner$process$is_alive()) {
    script_runner_drain(runner)
    runner$exit_status <- runner$process$get_exit_status()
    runner$status <- if (identical(runner$exit_status, 0L)) "Concluido" else "Falhou"
    runner$finished_at <- Sys.time()
    append_runner_summary(runner)
  }
  invisible(runner)
}

script_runner_stop <- function(runner) {
  if (!is.null(runner$process) && identical(runner$status, "Executando")) {
    if (runner$process$is_alive()) runner$process$kill_tree()
    runner$process$wait(timeout = 1000)
    script_runner_drain(runner)
    runner$exit_status <- NA_integer_
    runner$status <- "Interrompido"
    runner$finished_at <- Sys.time()
    append_runner_summary(runner)
  }
  invisible(runner)
}

script_runner_log <- function(runner, n = 800L) {
  lines <- runner$log_lines
  if (!length(lines)) return("Nenhuma execucao iniciada.")
  if (!length(lines)) return("Aguardando saida...")
  paste(tail(lines, n), collapse = "\n")
}
