package_names <- function(value) {
  value <- if (length(value)) paste(value, collapse = " ") else ""
  values <- unique(trimws(unlist(strsplit(value, "[,;[:space:]]+"))))
  values[nzchar(values)]
}

package_roots <- function(workspace, project_root = NULL) {
  if (is.character(project_root) && length(project_root) && nzchar(project_root) && dir.exists(project_root)) return(c(projetos = project_root))
  character()
}
description_packages <- function(path) {
  fields <- tryCatch(read.dcf(path), error = function(e) NULL)
  if (is.null(fields) || !nrow(fields)) return(character())
  fields <- fields[1, intersect(c("Imports", "Depends", "LinkingTo"), colnames(fields)), drop = FALSE]
  if (!ncol(fields)) return(character())
  tokens <- trimws(unlist(strsplit(paste(fields[1, ], collapse = ","), ",", fixed = TRUE)))
  tokens <- trimws(sub("[(].*$", "", tokens))
  tokens <- trimws(tokens)
  tokens[tokens != "R" & grepl("^[A-Za-z][A-Za-z0-9.]*$", tokens)]
}

renv_packages <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(character())
  lock <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) NULL)
  packages <- if (is.null(lock)) NULL else lock$Packages
  if (is.null(packages)) return(character())
  unique(names(packages))
}

project_package_inventory <- function(workspace, project_root = NULL) {
  roots <- package_roots(workspace, project_root)
  rows <- list()
  for (root_name in names(roots)) {
    root <- roots[[root_name]]
    files <- list.files(root, recursive = TRUE, full.names = TRUE)
    files <- files[basename(files) %in% c("renv.lock", "DESCRIPTION")]
    files <- files[!grepl("(^|[/\\\\])(?:\\.git|renv)[/\\\\]", files, ignore.case = TRUE, perl = TRUE)]
    for (file in files) {
      packages <- if (identical(basename(file), "renv.lock")) renv_packages(file) else description_packages(file)
      if (length(packages)) rows[[length(rows) + 1L]] <- data.frame(
        pacote = packages,
        fonte = basename(file),
        arquivo = file,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame(pacote = character(), fonte = character(), arquivo = character(), stringsAsFactors = FALSE))
  inventory <- do.call(rbind, rows)
  inventory[!duplicated(inventory$pacote), , drop = FALSE]
}

project_package_names <- function(workspace, project_root = NULL) {
  inventory <- project_package_inventory(workspace, project_root)
  inventory$pacote
}

new_package_manager <- function(workspace, timeout_seconds = 3600, project_root = NULL) {
  manager <- new.env(parent = emptyenv())
  manager$workspace <- workspace
  manager$project_root <- project_root
  manager$worker <- file.path(workspace, "app", "services", "package_worker.R")
  manager$timeout_seconds <- timeout_seconds
  manager$process <- NULL
  manager$action <- NULL
  manager$started_at <- NULL
  manager$finished_at <- NULL
  manager$status <- "Pronto"
  manager$exit_status <- NULL
  manager$log_file <- NULL
  manager$result_file <- NULL
  manager$sync_packages <- character()
  class(manager) <- "r_lab_package_manager"
  manager
}

package_manager_start <- function(manager, action, values = character(), query = "") {
  if (!is.null(manager$process) && manager$process$is_alive()) stop("Ja existe uma operacao de pacotes em execucao.")
  valid_names <- function(x) grepl("^[A-Za-z][A-Za-z0-9.]*$", x)
  values <- package_names(values)
  if (identical(action, "sync")) values <- unique(project_package_names(manager$workspace, manager$project_root))
  if (action %in% c("install", "remove", "sync") && (!length(values) || any(!valid_names(values)))) stop("Nenhum pacote valido foi encontrado para esta operacao.")
  if (identical(action, "search") && !nzchar(trimws(query))) stop("Informe um termo para pesquisar.")
  log_file <- NULL
  if (!identical(action, "search")) {
    stamp <- gsub("[^0-9-]", "", format(Sys.time(), "%Y%m%d-%H%M%S-%OS3"))
    log_file <- file.path(manager$workspace, "logs", paste0("packages-", stamp, ".log"))
    dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
  }
  result_file <- if (identical(action, "search")) tempfile("r-lab-cran-", fileext = ".rds") else NULL
  args <- c("--vanilla", manager$worker, action)
  if (identical(action, "search")) args <- c(args, query, result_file)
  if (action %in% c("install", "remove", "sync")) args <- c(args, values)
  manager$log_file <- log_file
  manager$result_file <- result_file
  manager$sync_packages <- if (identical(action, "sync")) values else character()
  manager$action <- action
  manager$started_at <- Sys.time()
  manager$finished_at <- NULL
  manager$exit_status <- NULL
  manager$status <- "Executando"
  manager$process <- processx::process$new("Rscript", args, wd = manager$workspace, stdout = "|", stderr = "|", cleanup = TRUE)
  invisible(manager)
}

package_manager_drain <- function(manager) {
  if (is.null(manager$process)) return(invisible(NULL))
  manager$process$poll_io(0)
  write_lines <- function(lines, prefix = "") {
    if (length(lines) && !is.null(manager$log_file)) write(paste0(prefix, lines), file = manager$log_file, append = TRUE)
  }
  write_lines(manager$process$read_output_lines())
  write_lines(manager$process$read_error_lines(), "[stderr] ")
  invisible(NULL)
}

package_manager_tick <- function(manager) {
  if (is.null(manager$process)) return(invisible(manager))
  package_manager_drain(manager)
  if (manager$process$is_alive() && difftime(Sys.time(), manager$started_at, units = "secs") > manager$timeout_seconds) {
    manager$process$kill_tree()
    manager$process$wait(timeout = 1000)
    package_manager_drain(manager)
    manager$exit_status <- NA_integer_
    manager$status <- "Tempo excedido"
    manager$finished_at <- Sys.time()
  } else if (!manager$process$is_alive() && identical(manager$status, "Executando")) {
    package_manager_drain(manager)
    manager$exit_status <- manager$process$get_exit_status()
    manager$status <- if (identical(manager$exit_status, 0L)) "Concluido" else "Falhou"
    manager$finished_at <- Sys.time()
  }
  invisible(manager)
}

package_manager_log <- function(manager, n = 500L) {
  if (is.null(manager$log_file) || !file.exists(manager$log_file)) return("Nenhuma operacao iniciada.")
  lines <- readLines(manager$log_file, warn = FALSE, encoding = "UTF-8")
  if (!length(lines)) return("Aguardando saida...")
  paste(tail(lines, n), collapse = "\n")
}

package_manager_search_result <- function(manager) {
  if (is.null(manager$result_file) || !file.exists(manager$result_file)) return(NULL)
  tryCatch(readRDS(manager$result_file), error = function(e) NULL)
}

installed_packages_table <- function() {
  packages <- as.data.frame(utils::installed.packages(), stringsAsFactors = FALSE)
  packages <- packages[, intersect(c("Package", "Version", "LibPath"), names(packages)), drop = FALSE]
  packages[order(tolower(packages$Package)), , drop = FALSE]
}
