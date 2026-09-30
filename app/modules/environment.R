environment_ui <- function(id) {
  ns <- shiny::NS(id)
  menu_button <- function(value, icon_name, label, active = FALSE) {
    onclick <- sprintf("var root=this.closest('.environment-layout');root.querySelectorAll('[data-env-section]').forEach(function(el){el.classList.toggle('active', el.dataset.envSection === '%s')});Shiny.setInputValue('%s','%s',{priority:'event'});", value, ns("environment_section"), value)
    shiny::tags$button(type = "button", class = paste("environment-menu-item", if (active) "active" else ""), `data-env-section` = value, onclick = onclick, shiny::icon(icon_name), shiny::span(class = "environment-menu-copy", label))
  }
  shiny::div(
    class = "environment-content",
    shiny::div(class = "page-header",
      shiny::div(shiny::div(class = "eyebrow", shiny::icon("sliders"), "CONFIGURACAO DO WORKSPACE"), shiny::h1("Ambiente"), shiny::p("Gerencie a biblioteca R e acompanhe as fontes disponiveis para o projeto.")),
      shiny::div(class = "page-header-badge", shiny::span(class = "status-dot"), "Ambiente pronto")
    ),
    shiny::div(class = "environment-summary",
      shiny::div(class = "summary-card", shiny::div(class = "summary-icon blue", shiny::icon("code")), shiny::div(class = "summary-copy", shiny::span("R instalado"), shiny::strong(textOutput(ns("r_version"), inline = TRUE)))),
      shiny::div(class = "summary-card", shiny::div(class = "summary-icon violet", shiny::icon("bolt")), shiny::div(class = "summary-copy", shiny::span("Shiny"), shiny::strong(textOutput(ns("shiny_version"), inline = TRUE)))),
      shiny::div(class = "summary-card", shiny::div(class = "summary-icon green", shiny::icon("box")), shiny::div(class = "summary-copy", shiny::span("Pacotes disponiveis"), shiny::strong(textOutput(ns("package_count"), inline = TRUE)))),
      shiny::div(class = "summary-card", shiny::div(class = "summary-icon amber", shiny::icon("folder")), shiny::div(class = "summary-copy", shiny::span("Workspace"), shiny::strong("/workspace")))
    ),
    shiny::div(class = "environment-layout",
      shiny::tags$nav(class = "environment-menu",
        shiny::div(class = "environment-menu-title", "Seccoes"),
        menu_button("actions", "wand-magic-sparkles", "A\u00e7\u00f5es r\u00e1pidas", TRUE),
        menu_button("installed", "box-open", "Pacotes instalados"),
        menu_button("cran", "search", "Resultados do CRAN")
      ),
      shiny::tags$main(class = "environment-panel",
        shiny::radioButtons(ns("environment_section"), NULL, choices = c("A\u00e7\u00f5es r\u00e1pidas" = "actions", "Pacotes instalados" = "installed", "Resultados do CRAN" = "cran"), selected = "actions", width = "1px"),
        shiny::conditionalPanel(sprintf("input['%s'] === 'actions'", ns("environment_section")),
          shiny::div(class = "environment-section",
            shiny::div(class = "section-heading", shiny::div(shiny::h2("A\u00e7\u00f5es r\u00e1pidas"), shiny::p("Pesquise, instale, atualize ou remova pacotes da biblioteca persistente.")), shiny::span(class = "section-chip", shiny::icon("cloud-arrow-down"), "CRAN")),
            bslib::card(class = "content-card package-actions-card",
              bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("wand-magic-sparkles"), "Gerenciar pacotes")), shiny::span("executadas em segundo plano", class = "card-caption"))),
              shiny::div(class = "package-actions-body",
                shiny::div(class = "field-block", shiny::textInput(ns("query"), "Pesquisar no CRAN", placeholder = "shiny, dplyr..."), shiny::actionButton(ns("search"), "Pesquisar pacotes", icon = shiny::icon("search"), class = "btn-outline-primary w-100")),
                shiny::div(class = "package-field", shiny::textAreaInput(ns("install"), "Instalar pacotes", rows = 3, placeholder = "shiny, dplyr"), shiny::p("Separe por virgulas, espacos ou linhas.", class = "form-text"), shiny::textOutput(ns("install_count"), inline = TRUE)),
                shiny::div(class = "button-stack", shiny::actionButton(ns("install_btn"), "Instalar", icon = shiny::icon("download"), class = "btn-primary"), shiny::actionButton(ns("update_btn"), "Atualizar tudo", icon = shiny::icon("refresh"), class = "btn-ghost")),
                shiny::div(class = "field-block remove-block", shiny::textInput(ns("remove"), "Remover pacotes", placeholder = "pacote1, pacote2"), shiny::actionButton(ns("remove_btn"), "Remover selecionados", icon = shiny::icon("trash"), class = "btn-outline-danger w-100"))
              ),
              shiny::div(class = "package-status", shiny::div(class = "status-heading", shiny::strong("Status da operacao", class = "status-label"), shiny::span(class = "status-dot")), shiny::textOutput(ns("package_status")), shiny::verbatimTextOutput(ns("package_log"), placeholder = TRUE))
            )
          )
        ),
        shiny::conditionalPanel(sprintf("input['%s'] === 'installed'", ns("environment_section")),
          shiny::div(class = "environment-section",
            shiny::div(class = "section-heading", shiny::div(shiny::h2("Pacotes instalados"), shiny::p("Biblioteca R persistente disponivel neste ambiente.")), shiny::span(class = "section-chip", shiny::icon("box-open"), "Biblioteca atual")),
            bslib::card(class = "content-card package-list-card", bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("box-open"), "Pacotes instalados")), shiny::span("nome e versao", class = "card-caption"))), DT::DTOutput(ns("installed")))
          )
        ),
        shiny::conditionalPanel(sprintf("input['%s'] === 'cran'", ns("environment_section")),
          shiny::div(class = "environment-section",
            shiny::div(class = "section-heading", shiny::div(shiny::h2("Resultados do CRAN"), shiny::p("Pesquise no CRAN e adicione pacotes a fila de instalacao.")), shiny::span(class = "section-chip", shiny::icon("search"), "Pesquisa")),
            bslib::card(class = "content-card cran-card", bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("search"), "Resultados do CRAN")), shiny::div(class = "card-header-actions", shiny::span("Selecione para instalar", class = "card-caption"), shiny::actionButton(ns("add_selected"), "Adicionar selecionados", icon = shiny::icon("plus"), class = "btn-ghost btn-sm")))), DT::DTOutput(ns("search_results")))
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
    output$r_version <- shiny::renderText(sub("^R version ", "", R.version.string))
    output$shiny_version <- shiny::renderText(as.character(utils::packageVersion("shiny")))
    output$package_count <- shiny::renderText({ revision(); nrow(installed_packages_table()) })
    shiny::observe({ input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn; if (!package_active()) return(); shiny::invalidateLater(1000, session); old_status <- manager$status; package_manager_tick(manager); if (!identical(old_status, manager$status)) bump_revision() })
    run_package_action <- function(action, values = character(), query = "") { tryCatch(package_manager_start(manager, action, values, query), error = function(e) shiny::showNotification(conditionMessage(e), type = "error")); bump_revision() }
    shiny::observeEvent(input$search, { run_package_action("search", query = input$query) })
    shiny::observeEvent(input$install_btn, { run_package_action("install", package_names(input$install)) })
    shiny::observeEvent(input$update_btn, { run_package_action("update") })
    shiny::observeEvent(input$remove_btn, { run_package_action("remove", package_names(input$remove)) })
    shiny::observeEvent(input$add_selected, { result <- package_manager_search_result(manager); rows <- input$search_results_rows_selected; if (is.null(result) || !length(rows)) return(shiny::showNotification("Selecione um ou mais pacotes na pesquisa do CRAN.", type = "warning")); selected <- result$Package[rows]; shiny::updateTextAreaInput(session, "install", value = paste(unique(c(package_names(input$install), selected)), collapse = ", ")); shiny::showNotification(paste(length(selected), "pacote(s) adicionado(s) a instalacao."), type = "message") })
    output$install_count <- shiny::renderText({ values <- package_names(input$install); paste(length(values), if (length(values) == 1) "pacote selecionado" else "pacotes selecionados") })
    output$package_status <- shiny::renderText({ input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn; if (package_active()) shiny::invalidateLater(1000, session); if (is.null(manager$action)) return(manager$status); paste(manager$status, "-", manager$action) })
    output$package_log <- shiny::renderText({ input$search; input$install_btn; input$add_selected; input$update_btn; input$remove_btn; if (package_active()) shiny::invalidateLater(1000, session); package_manager_log(manager) })
    output$search_results <- DT::renderDT({ revision(); result <- package_manager_search_result(manager); if (is.null(result)) result <- data.frame(status = "Nenhuma pesquisa concluida"); DT::datatable(result, options = list(pageLength = 10, scrollX = TRUE, responsive = TRUE), selection = "multiple", rownames = FALSE) })
    output$installed <- DT::renderDT({ revision(); DT::datatable(installed_packages_table(), options = list(pageLength = 15, scrollX = TRUE, responsive = TRUE), rownames = FALSE) })
  })
}
