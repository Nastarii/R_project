new_package_manager <- function(workspace, timeout_seconds = 3600) {
  manager <- new.env(parent = emptyenv())
  manager$workspace <- workspace
  manager$worker <- file.path(workspace, "app", "services", "package_worker.R")
  manager$timeout_seconds <- timeout_seconds
  manager$process <- NULL
  manager$action <- NULL
  manager$started_at <- NULL
  manager$finished_at <- NULL
  manager$status <- "Pronto"
  manager$log_file <- NULL
  manager$result_file <- NULL
  class(manager) <- "r_lab_package_manager"
  manager
}

package_manager_start <- function(manager, action, values = character(), query = "") {
  if (!is.null(manager$process) && manager$process$is_alive()) stop("Já existe uma operação de pacotes em execução.")
  valid_names <- function(x) grepl("^[A-Za-z][A-Za-z0-9.]*$", x)
  values <- unique(trimws(values[nzchar(trimws(values))]))
  if (action %in% c("install", "remove") && (!length(values) || any(!valid_names(values)))) stop("Informe nomes de pacotes válidos, separados por vírgula.")
  if (action == "search" && !nzchar(trimws(query))) stop("Informe um termo para pesquisar.")
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  log_file <- file.path(manager$workspace, "logs", paste0("packages-", stamp, ".log"))
  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
  result_file <- if (action == "search") tempfile("r-lab-cran-", fileext = ".rds") else NULL
  args <- c("--vanilla", manager$worker, action)
  if (action == "search") args <- c(args, query, result_file)
  if (action %in% c("install", "remove")) args <- c(args, values)
  manager$log_file <- log_file
  manager$result_file <- result_file
  manager$action <- action
  manager$started_at <- Sys.time()
  manager$finished_at <- NULL
  manager$status <- "Executando"
  manager$process <- processx::process$new("Rscript", args, wd = manager$workspace, stdout = "|", stderr = "|", cleanup = TRUE)
  invisible(manager)
}

package_manager_drain <- function(manager) {
  if (is.null(manager$process)) return(invisible(NULL))
  write_lines <- function(lines, prefix = "") if (length(lines)) write(paste0(prefix, lines), file = manager$log_file, append = TRUE)
  write_lines(manager$process$read_output_lines())
  write_lines(manager$process$read_error_lines(), "[stderr] ")
  invisible(NULL)
}

package_manager_tick <- function(manager) {
  if (is.null(manager$process)) return(invisible(manager))
  package_manager_drain(manager)
  if (manager$process$is_alive() && difftime(Sys.time(), manager$started_at, units = "secs") > manager$timeout_seconds) {
    manager$process$kill_tree(); manager$status <- "Tempo excedido"; manager$finished_at <- Sys.time()
  } else if (!manager$process$is_alive() && identical(manager$status, "Executando")) {
    package_manager_drain(manager)
    manager$status <- if (identical(manager$process$get_exit_status(), 0L)) "Concluído" else "Falhou"
    manager$finished_at <- Sys.time()
  }
  invisible(manager)
}

package_manager_log <- function(manager, n = 500L) {
  if (is.null(manager$log_file) || !file.exists(manager$log_file)) return("Nenhuma operação iniciada.")
  lines <- readLines(manager$log_file, warn = FALSE, encoding = "UTF-8")
  if (!length(lines)) return("Aguardando saída...")
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
