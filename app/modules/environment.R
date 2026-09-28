environment_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      shiny::h4("Ambiente"), shiny::tableOutput(ns("info")), shiny::hr(), bslib::input_dark_mode(id = ns("dark_mode")),
      shiny::h4("Pacotes"), shiny::textInput(ns("query"), "Pesquisar no CRAN", placeholder = "shiny, dplyr..."),
      shiny::actionButton(ns("search"), "Pesquisar", class = "btn-outline-primary w-100"), shiny::textInput(ns("install"), "Instalar", placeholder = "pacote1, pacote2"),
      shiny::actionButton(ns("install_btn"), "Instalar pacotes", class = "btn-success w-100"), shiny::actionButton(ns("update_btn"), "Atualizar biblioteca", class = "btn-secondary w-100"),
      shiny::textInput(ns("remove"), "Remover", placeholder = "pacote1, pacote2"), shiny::actionButton(ns("remove_btn"), "Remover pacotes", class = "btn-outline-danger w-100"),
      shiny::hr(), shiny::strong("Status"), shiny::textOutput(ns("package_status")), shiny::verbatimTextOutput(ns("package_log"), placeholder = TRUE)
    ),
    bslib::layout_columns(bslib::card(bslib::card_header("Resultados da pesquisa no CRAN"), DT::DTOutput(ns("search_results"))), bslib::card(bslib::card_header("Pacotes instalados"), DT::DTOutput(ns("installed"))), col_widths = c(6, 6))
  )
}

environment_server <- function(id, workspace, timeout_seconds) {
  shiny::moduleServer(id, function(input, output, session) {
    manager <- new_package_manager(workspace, timeout_seconds); revision <- shiny::reactiveVal(0L)
    bump_revision <- function() revision(shiny::isolate(revision()) + 1L)
    package_active <- function() !is.null(manager$process) && manager$process$is_alive()
    output$info <- shiny::renderTable({ revision(); packages <- installed_packages_table(); data.frame(item = c("R", "Shiny", "Projeto", "Pacotes instalados"), valor = c(R.version.string, as.character(utils::packageVersion("shiny")), workspace, nrow(packages)), check.names = FALSE) }, striped = TRUE, bordered = FALSE, spacing = "xs")
    observe({
      input$search; input$install_btn; input$update_btn; input$remove_btn
      if (!package_active()) return()
      shiny::invalidateLater(1000, session); old_status <- manager$status; package_manager_tick(manager)
      if (!identical(old_status, manager$status)) bump_revision()
    })
    run_package_action <- function(action, values = character(), query = "") {
      tryCatch(package_manager_start(manager, action, values, query), error = function(e) shiny::showNotification(conditionMessage(e), type = "error")); bump_revision()
    }
    shiny::observeEvent(input$search, { run_package_action("search", query = input$query) }); shiny::observeEvent(input$install_btn, { run_package_action("install", strsplit(input$install, "[,;[:space:]]+")[[1]]) }); shiny::observeEvent(input$update_btn, { run_package_action("update") }); shiny::observeEvent(input$remove_btn, { run_package_action("remove", strsplit(input$remove, "[,;[:space:]]+")[[1]]) })
    output$package_status <- shiny::renderText({ input$search; input$install_btn; input$update_btn; input$remove_btn; if (package_active()) shiny::invalidateLater(1000, session); if (is.null(manager$action)) return(manager$status); paste(manager$status, "—", manager$action) })
    output$package_log <- shiny::renderText({ input$search; input$install_btn; input$update_btn; input$remove_btn; if (package_active()) shiny::invalidateLater(1000, session); package_manager_log(manager) })
    output$search_results <- DT::renderDT({ revision(); result <- package_manager_search_result(manager); if (is.null(result)) result <- data.frame(status = "Nenhuma pesquisa concluída"); DT::datatable(result, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE) })
    output$installed <- DT::renderDT({ revision(); DT::datatable(installed_packages_table(), options = list(pageLength = 15, scrollX = TRUE), rownames = FALSE) })
  })
}
