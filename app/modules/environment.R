environment_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      width = "350px",
      shiny::div(class = "sidebar-intro", shiny::div(class = "eyebrow", shiny::icon("sliders"), "CONTROLE DO AMBIENTE"), shiny::h4("Ambiente"), shiny::p("Gerencie a biblioteca e acompanhe as operações em segundo plano.", class = "text-muted small")),
      shiny::div(class = "environment-info", shiny::tableOutput(ns("info"))),
      shiny::hr(),
      shiny::h5(shiny::tagList(shiny::icon("box"), "Pacotes"), class = "section-title"),
      shiny::div(class = "field-block", shiny::textInput(ns("query"), "Pesquisar no CRAN", placeholder = "shiny, dplyr..."), shiny::actionButton(ns("search"), "Pesquisar pacotes", icon = shiny::icon("search"), class = "btn-outline-primary w-100")),
      shiny::div(class = "package-field", shiny::textAreaInput(ns("install"), "Instalar vários pacotes", rows = 4, placeholder = "shiny, dplyr\nreadr"), shiny::p("Separe por vírgulas, espaços ou uma linha por pacote.", class = "form-text"), shiny::textOutput(ns("install_count"), inline = TRUE)),
      shiny::div(class = "button-stack", shiny::actionButton(ns("install_btn"), "Instalar pacotes", icon = shiny::icon("download"), class = "btn-primary w-100"), shiny::actionButton(ns("update_btn"), "Atualizar biblioteca", icon = shiny::icon("refresh"), class = "btn-ghost w-100")),
      shiny::div(class = "field-block remove-block", shiny::textInput(ns("remove"), "Remover pacotes", placeholder = "pacote1, pacote2"), shiny::actionButton(ns("remove_btn"), "Remover pacotes", icon = shiny::icon("trash"), class = "btn-outline-danger w-100")),
      shiny::hr(),
      shiny::div(class = "status-heading", shiny::strong("Status", class = "status-label"), shiny::span(class = "status-dot")),
      shiny::textOutput(ns("package_status")),
      shiny::verbatimTextOutput(ns("package_log"), placeholder = TRUE)
    ),
    shiny::div(
      class = "environment-content",
      shiny::div(class = "page-intro", shiny::div(class = "eyebrow", shiny::icon("chart-line"), "VISÃO GERAL"), shiny::h2("Biblioteca R"), shiny::p("Pesquise no CRAN, instale dependências e mantenha o ambiente pronto para executar seus scripts.")),
      shiny::div(
        class = "content-switcher",
        bslib::navset_pill(
          id = ns("library_view"),
        bslib::nav_panel(
          shiny::tagList(shiny::icon("box-open"), "Pacotes instalados"),
          bslib::card(class = "content-card", bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("box-open"), "Pacotes instalados")), shiny::span("Biblioteca atual", class = "card-caption"))), DT::DTOutput(ns("installed")))
        ),
        bslib::nav_panel(
          shiny::tagList(shiny::icon("search"), "Resultados do CRAN"),
          bslib::card(class = "content-card", bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("search"), "Resultados do CRAN")), shiny::div(class = "card-header-actions", shiny::span("Selecione para instalar", class = "card-caption"), shiny::actionButton(ns("add_selected"), "Adicionar selecionados", icon = shiny::icon("plus"), class = "btn-ghost btn-sm")))), DT::DTOutput(ns("search_results")))
        )
      )
      )
    )
  )
}
environment_server <- function(id, workspace, timeout_seconds) {
  shiny::moduleServer(id, function(input, output, session) {
    manager <- new_package_manager(workspace, timeout_seconds)
    revision <- shiny::reactiveVal(0L)
    bump_revision <- function() revision(shiny::isolate(revision()) + 1L)
    package_active <- function() !is.null(manager$process) && manager$process$is_alive()

    output$info <- shiny::renderTable({
      revision()
      packages <- installed_packages_table()
      data.frame(item = c("R", "Shiny", "Projeto", "Pacotes instalados"), valor = c(R.version.string, as.character(utils::packageVersion("shiny")), workspace, nrow(packages)), check.names = FALSE)
    }, striped = TRUE, bordered = FALSE, spacing = "xs")

    observe({
      input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn
      if (!package_active()) return()
      shiny::invalidateLater(1000, session)
      old_status <- manager$status
      package_manager_tick(manager)
      if (!identical(old_status, manager$status)) bump_revision()
    })

    run_package_action <- function(action, values = character(), query = "") {
      tryCatch(package_manager_start(manager, action, values, query), error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
      bump_revision()
    }

    shiny::observeEvent(input$search, { run_package_action("search", query = input$query) })
    shiny::observeEvent(input$install_btn, { run_package_action("install", package_names(input$install)) })
    shiny::observeEvent(input$update_btn, { run_package_action("update") })
    shiny::observeEvent(input$remove_btn, { run_package_action("remove", package_names(input$remove)) })
    shiny::observeEvent(input$add_selected, {
      result <- package_manager_search_result(manager)
      rows <- input$search_results_rows_selected
      if (is.null(result) || !length(rows)) {
        shiny::showNotification("Selecione um ou mais pacotes na pesquisa do CRAN.", type = "warning")
        return()
      }
      selected <- result$Package[rows]
      shiny::updateTextAreaInput(session, "install", value = paste(unique(c(package_names(input$install), selected)), collapse = ", "))
      shiny::showNotification(paste(length(selected), "pacote(s) adicionado(s) à instalação."), type = "message")
    })

    output$install_count <- shiny::renderText({
      values <- package_names(input$install)
      paste(length(values), if (length(values) == 1) "pacote selecionado" else "pacotes selecionados")
    })
    output$package_status <- shiny::renderText({
      input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn
      if (package_active()) shiny::invalidateLater(1000, session)
      if (is.null(manager$action)) return(manager$status)
      paste(manager$status, "-", manager$action)
    })
    output$package_log <- shiny::renderText({
      input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn
      if (package_active()) shiny::invalidateLater(1000, session)
      package_manager_log(manager)
    })
    output$search_results <- DT::renderDT({
      revision()
      result <- package_manager_search_result(manager)
      if (is.null(result)) result <- data.frame(status = "Nenhuma pesquisa concluída")
      DT::datatable(result, options = list(pageLength = 10, scrollX = TRUE, responsive = TRUE), selection = "multiple", rownames = FALSE)
    })
    output$installed <- DT::renderDT({
      revision()
      DT::datatable(installed_packages_table(), options = list(pageLength = 15, scrollX = TRUE, responsive = TRUE), rownames = FALSE)
    })
  })
}
