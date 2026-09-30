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

ui <- shiny::tagList(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "style.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),
  shiny::div(
    class = "app-shell",
    shiny::div(
      class = "app-sidebar",
      shiny::div(class = "app-brand", shiny::div(class = "app-brand-mark", "R"), shiny::div(class = "app-brand-copy", shiny::strong("R Lab"), shiny::span("workspace"))),
      shiny::div(class = "app-nav-label", "Navegacao"),
      shiny::tags$button(
        type = "button", class = "app-nav-item", onclick = "document.querySelectorAll('.app-nav-item').forEach(function(el){el.classList.remove('active')});this.classList.add('active');document.getElementById('topbar-title').textContent='Ambiente';Shiny.setInputValue('main_section','environment',{priority:'event'});",
        shiny::icon("sliders"), shiny::span("Ambiente"), shiny::span(class = "app-nav-chevron", shiny::icon("chevron-right"))
      ),
      shiny::tags$button(
        type = "button", class = "app-nav-item active", onclick = "document.querySelectorAll('.app-nav-item').forEach(function(el){el.classList.remove('active')});this.classList.add('active');document.getElementById('topbar-title').textContent='Scripts';Shiny.setInputValue('main_section','scripts',{priority:'event'});",
        shiny::icon("terminal"), shiny::span("Scripts"), shiny::span(class = "app-nav-chevron", shiny::icon("chevron-right"))
      ),
      shiny::div(class = "app-sidebar-spacer"),
      shiny::div(class = "app-sidebar-footer", shiny::div(class = "workspace-badge", shiny::icon("folder-open"), shiny::div(shiny::strong("Workspace"), shiny::span("/workspace"))), shiny::span(class = "app-version", "R Lab - local")),
      shiny::radioButtons("main_section", NULL, choices = c(environment = "Ambiente", scripts = "Scripts"), selected = "scripts", inline = FALSE, width = "1px")
    ),
    shiny::div(
      class = "app-main",
      shiny::div(class = "app-topbar", shiny::div(class = "topbar-context", shiny::span(class = "topbar-kicker", "R LAB"), shiny::span(id = "topbar-title", "Scripts")), shiny::div(class = "topbar-status", shiny::span(class = "status-dot"), "Ambiente local")),
      shiny::conditionalPanel("input.main_section === 'environment'", environment_ui("environment")),
      shiny::conditionalPanel("input.main_section === 'scripts'", execution_ui("execution"))
    )
  )
)
server <- function(input, output, session) {
  environment_server("environment", workspace, timeout_seconds)
  execution_server("execution", workspace, timeout_seconds)
}
shinyApp(ui, server)
