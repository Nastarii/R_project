library(shiny)
library(bslib)
library(DT)
library(processx)

app_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
app_dir <- if (!is.null(app_file)) dirname(normalizePath(app_file, winslash = "/")) else if (file.exists(file.path("services", "script_runner.R"))) normalizePath(".", winslash = "/", mustWork = TRUE) else normalizePath("app", winslash = "/", mustWork = TRUE)
workspace <- normalizePath(Sys.getenv("R_LAB_WORKSPACE", unset = file.path(app_dir, "..")), winslash = "/", mustWork = TRUE)
timeout_seconds <- suppressWarnings(as.numeric(Sys.getenv("R_LAB_TIMEOUT_SECONDS", "3600")))
if (!is.finite(timeout_seconds) || timeout_seconds <= 0) timeout_seconds <- 3600
dir.create(file.path(workspace, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(workspace, "output"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(workspace, "assets"), recursive = TRUE, showWarnings = FALSE)
source(file.path(app_dir, "services", "script_runner.R"), local = TRUE)
source(file.path(app_dir, "services", "package_manager.R"), local = TRUE)
source(file.path(app_dir, "services", "result_viewer.R"), local = TRUE)
source(file.path(app_dir, "modules", "environment.R"), local = TRUE)
source(file.path(app_dir, "modules", "execution.R"), local = TRUE)

ui <- page_navbar(
  title = "R Lab",
  theme = bs_theme(version = 5, primary = "#3569e8", font_scale = .96),
  header = tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "style.css")),
  nav_panel(tagList(icon("sliders"), " Ambiente"), environment_ui("environment")),
  nav_panel(tagList(icon("play"), " Executar scripts"), execution_ui("execution"))
)
server <- function(input, output, session) {
  environment_server("environment", workspace, timeout_seconds)
  execution_server("execution", workspace, timeout_seconds)
}
shinyApp(ui, server)
