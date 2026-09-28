args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) quit(status = 2)

action <- args[[1]]
lib <- Sys.getenv("R_LIBS_USER", unset = path.expand("~/R/library"))
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(lib, .libPaths())))
repos <- "https://cloud.r-project.org"

log_message <- function(...) {
  cat(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", ..., "\n", sep = "")
  flush.console()
}

tryCatch({
  if (action == "search") {
    query <- if (length(args) >= 2) args[[2]] else ""
    result_file <- args[[3]]
    log_message("Pesquisando no CRAN...")
    index <- as.data.frame(utils::available.packages(repos = repos), stringsAsFactors = FALSE)
    if (nzchar(query)) {
      needle <- tolower(query)
      haystack <- paste(index$Package, index$Title, index$Description)
      index <- index[grepl(needle, tolower(haystack), fixed = TRUE), , drop = FALSE]
    }
    index <- head(index[, intersect(c("Package", "Version", "Title"), names(index)), drop = FALSE], 100)
    saveRDS(index, result_file)
    log_message("Encontrados ", nrow(index), " pacote(s).")
  } else if (action == "install") {
    packages <- args[-1]
    log_message("Instalando: ", paste(packages, collapse = ", "))
    utils::install.packages(packages, lib = lib, repos = repos, dependencies = TRUE)
    log_message("Instalação concluída.")
  } else if (action == "update") {
    log_message("Atualizando pacotes da biblioteca do projeto...")
    utils::update.packages(lib.loc = lib, ask = FALSE, checkBuilt = TRUE, repos = repos)
    log_message("Atualização concluída.")
  } else if (action == "remove") {
    packages <- args[-1]
    log_message("Removendo: ", paste(packages, collapse = ", "))
    utils::remove.packages(packages, lib = lib)
    log_message("Remoção concluída.")
  } else {
    stop("Ação desconhecida: ", action)
  }
}, error = function(error) {
  log_message("ERRO: ", conditionMessage(error))
  quit(status = 1)
})
