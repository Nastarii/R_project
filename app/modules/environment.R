environment_ui <- function(id) {
  ns <- shiny::NS(id)
  menu_button <- function(value, icon_name, label, active = FALSE) {
    onclick <- sprintf("var root=this.closest('.environment-layout');root.querySelectorAll('[data-env-section]').forEach(function(el){el.classList.toggle('active', el.dataset.envSection === '%s')});Shiny.setInputValue('%s','%s',{priority:'event'});", value, ns("environment_section"), value)
    shiny::tags$button(type = "button", class = paste("environment-menu-item", if (active) "active" else ""), `data-env-section` = value, onclick = onclick, shiny::icon(icon_name), shiny::span(class = "environment-menu-copy", label))
  }
  shiny::div(
    class = "environment-content",
    shiny::div(class = "page-header",
      shiny::div(shiny::div(class = "eyebrow", shiny::icon("sliders"), "CONFIGURACAO DO WORKSPACE"), shiny::h1("Ambiente"), shiny::p("Gerencie a biblioteca R, sincronize projetos e pesquise no CRAN.")),
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
        menu_button("actions", "wand-magic-sparkles", "Acoes rapidas", TRUE),
        menu_button("installed", "box-open", "Pacotes instalados"),
        menu_button("cran", "search", "Resultados do CRAN")
      ),
      shiny::tags$main(class = "environment-panel",
        shiny::radioButtons(ns("environment_section"), NULL, choices = c("Acoes rapidas" = "actions", "Pacotes instalados" = "installed", "Resultados do CRAN" = "cran"), selected = "actions", width = "1px"),
        shiny::conditionalPanel(sprintf("input['%s'] === 'actions'", ns("environment_section")),
          shiny::div(class = "environment-section",
            shiny::div(class = "section-heading", shiny::div(shiny::h2("Acoes rapidas"), shiny::p("Instale, remova ou sincronize pacotes sem bloquear a interface.")), shiny::span(class = "section-chip", shiny::icon("wand-magic-sparkles"), "Biblioteca")),
            bslib::card(class = "content-card package-actions-card",
              bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("box"), "Gerenciar pacotes")), shiny::span("processos independentes", class = "card-caption"))),
              shiny::div(class = "package-actions-body",
                shiny::div(class = "package-action-group", shiny::textAreaInput(ns("install"), "Instalar pacotes", rows = 3, placeholder = "shiny, dplyr"), shiny::p("Separe por virgulas, espacos ou linhas.", class = "form-text"), shiny::actionButton(ns("install_btn"), "Instalar", icon = shiny::icon("download"), class = "btn-primary w-100")),
                shiny::div(class = "package-action-group", shiny::textInput(ns("remove"), "Remover pacotes", placeholder = "pacote1, pacote2"), shiny::p("Somente pacotes da biblioteca persistente.", class = "form-text"), shiny::actionButton(ns("remove_btn"), "Remover", icon = shiny::icon("trash"), class = "btn-outline-danger w-100")),
                shiny::div(class = "package-action-group package-sync-group", shiny::strong("Sincronizar projeto"), shiny::p("Detecta renv.lock e DESCRIPTION dentro da pasta de projetos montada.", class = "form-text"), shiny::textOutput(ns("sync_info")), shiny::actionButton(ns("sync_btn"), "Importar e instalar", icon = shiny::icon("arrows-rotate"), class = "btn-outline-primary w-100")),
                shiny::div(class = "package-action-group package-update-group", shiny::strong("Manutencao"), shiny::p("Atualiza todos os pacotes disponiveis no CRAN.", class = "form-text"), shiny::actionButton(ns("update_btn"), "Atualizar tudo", icon = shiny::icon("refresh"), class = "btn-ghost w-100"))
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
            shiny::div(class = "section-heading", shiny::div(shiny::h2("Pesquisa de pacotes no CRAN"), shiny::p("Encontre pacotes por nome, titulo ou descricao e envie os selecionados para instalacao." )), shiny::span(class = "section-chip", shiny::icon("search"), "Pesquisa")),
            bslib::card(class = "content-card cran-card",
              bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("search"), "Pesquisar no CRAN")), shiny::div(class = "card-header-actions", shiny::span("ate 100 resultados", class = "card-caption"), shiny::actionButton(ns("add_selected"), "Adicionar selecionados", icon = shiny::icon("plus"), class = "btn-ghost btn-sm")))),
              shiny::div(class = "cran-search-panel",
                shiny::div(class = "cran-search-bar", shiny::textInput(ns("query"), NULL, placeholder = "shiny, dplyr...", width = "100%"), shiny::actionButton(ns("search"), "Pesquisar pacotes", icon = shiny::icon("search"), class = "btn-outline-primary")),
                DT::DTOutput(ns("search_results"))
              )
            )
          )
        )
      )
    )
  )
}

environment_server <- function(id, workspace, timeout_seconds, project_root = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    manager <- new_package_manager(workspace, timeout_seconds, project_root)
    revision <- shiny::reactiveVal(0L)
    bump_revision <- function() revision(shiny::isolate(revision()) + 1L)
    package_active <- function() !is.null(manager$process) && identical(manager$status, "Executando")
    output$r_version <- shiny::renderText(sub("^R version ", "", R.version.string))
    output$shiny_version <- shiny::renderText(as.character(utils::packageVersion("shiny")))
    output$package_count <- shiny::renderText({ revision(); nrow(installed_packages_table()) })

    shiny::observe({
      shiny::invalidateLater(1000, session)
      if (package_active()) {
        old_status <- manager$status
        package_manager_tick(manager)
        if (!identical(old_status, manager$status)) bump_revision()
      }
    })

    run_package_action <- function(action, values = character(), query = "") {
      tryCatch(package_manager_start(manager, action, values, query), error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
      bump_revision()
    }
    shiny::observeEvent(input$search, {
      run_package_action("search", query = input$query)
      shiny::updateRadioButtons(session, "environment_section", selected = "cran")
    })
    shiny::observeEvent(input$install_btn, { run_package_action("install", package_names(input$install)) })
    shiny::observeEvent(input$update_btn, { run_package_action("update") })
    shiny::observeEvent(input$sync_btn, { run_package_action("sync") })
    shiny::observeEvent(input$remove_btn, { run_package_action("remove", package_names(input$remove)) })
    shiny::observeEvent(input$add_selected, {
      result <- package_manager_search_result(manager)
      rows <- input$search_results_rows_selected
      if (is.null(result) || !length(rows)) return(shiny::showNotification("Selecione um ou mais pacotes na pesquisa do CRAN.", type = "warning"))
      selected <- result$Package[rows]
      shiny::updateTextAreaInput(session, "install", value = paste(unique(c(package_names(input$install), selected)), collapse = ", "))
      shiny::showNotification(paste(length(selected), "pacote(s) adicionado(s) a instalacao."), type = "message")
      shiny::updateRadioButtons(session, "environment_section", selected = "actions")
    })
    output$sync_info <- shiny::renderText({
      inventory <- project_package_inventory(workspace, project_root)
      if (!nrow(inventory)) return("Nenhum renv.lock ou DESCRIPTION com pacotes foi encontrado.")
      paste(length(unique(inventory$pacote)), "pacote(s) identificado(s) em", length(unique(inventory$arquivo)), "arquivo(s).")
    })
    output$package_status <- shiny::renderText({
      input$search; input$install_btn; input$add_selected; input$update_btn; input$sync_btn; input$remove_btn
      if (package_active()) shiny::invalidateLater(1000, session)
      if (is.null(manager$action)) return(manager$status)
      paste(manager$status, "-", manager$action, if (identical(manager$action, "sync") && length(manager$sync_packages)) paste0("(", length(manager$sync_packages), " pacotes)") else "")
    })
    output$package_log <- shiny::renderText({
      input$search; input$install_btn; input$add_selected; input$update_btn; input$sync_btn; input$remove_btn
      if (package_active()) shiny::invalidateLater(1000, session)
      package_manager_log(manager)
    })
    output$search_results <- DT::renderDT({
      revision()
      result <- package_manager_search_result(manager)
      if (is.null(result)) result <- data.frame(status = "Nenhuma pesquisa concluida")
      DT::datatable(result, options = list(pageLength = 10, scrollX = TRUE, responsive = TRUE), selection = "multiple", rownames = FALSE)
    })
    output$installed <- DT::renderDT({
      revision()
      DT::datatable(installed_packages_table(), options = list(pageLength = 15, scrollX = TRUE, responsive = TRUE), rownames = FALSE)
    })
  })
}
