execution_ui <- function(id) {
  ns <- shiny::NS(id)
  detail_button <- function(value, icon_name, label, active = FALSE) {
    onclick <- sprintf("var root=this.closest('.detail-switcher');root.querySelectorAll('[data-detail-section]').forEach(function(el){el.classList.toggle('active', el.dataset.detailSection === '%s')});Shiny.setInputValue('%s','%s',{priority:'event'});", value, ns("execution_view"), value)
    shiny::tags$button(type = "button", class = paste("detail-tab", if (active) "active" else ""), `data-detail-section` = value, onclick = onclick, shiny::icon(icon_name), shiny::span(label))
  }
  log_card <- bslib::card(class = "content-card log-card",
    bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("terminal"), "Terminal")), shiny::div(class = "card-header-actions", shiny::span("saida em tempo real", class = "card-caption"), shiny::actionButton(ns("copy_logs"), NULL, icon = shiny::icon("copy"), class = "icon-button", title = "Copiar logs", onclick = sprintf("navigator.clipboard.writeText(document.getElementById('%s').innerText);", ns("log_terminal"))), shiny::actionButton(ns("clear_log_view"), NULL, icon = shiny::icon("eraser"), class = "icon-button", title = "Limpar visualizacao"), shiny::actionButton(ns("refresh_logs"), NULL, icon = shiny::icon("refresh"), class = "icon-button", title = "Atualizar")))),
    shiny::div(class = "log-toolbar", shiny::span("Logs da execucao selecionada", class = "log-current-label"), shiny::span(class = "live-indicator", shiny::span(class = "status-dot"), "Atualizacao automatica")),
    shiny::uiOutput(ns("log_terminal"))
  )
  results_card <- bslib::card(class = "content-card results-card",
    bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("file-lines"), "Resultados")), shiny::span("arquivos produzidos pelo workspace", class = "card-caption"))),
    shiny::actionButton(ns("refresh_results"), NULL, icon = shiny::icon("refresh"), class = "btn-ghost result-refresh", title = "Atualizar resultados"),
    shiny::uiOutput(ns("results_panel"))
  )
  shiny::div(
    class = "execution-content",
    shiny::div(class = "page-header", shiny::div(shiny::div(class = "eyebrow", shiny::icon("terminal"), "CENTRAL DE EXECUCAO"), shiny::h1("Scripts"), shiny::p("Execute scripts confiaveis da pasta de projetos montada em /projects.")), shiny::div(class = "page-header-actions", shiny::span(class = "workspace-status", shiny::span(class = "status-dot"), "Workspace local"), shiny::actionButton(ns("refresh_scripts"), "Atualizar", icon = shiny::icon("refresh"), class = "btn-ghost"))),
    shiny::uiOutput(ns("script_metrics")),
    shiny::div(class = "script-toolbar", shiny::textInput(ns("script_filter"), NULL, placeholder = "Pesquisar por nome ou caminho...", width = "100%"), shiny::selectInput(ns("status_filter"), NULL, choices = c("Todos os status" = "all", "Executando" = "running", "Concluido" = "success", "Com erro" = "error", "Interrompido" = "stopped"), selected = "all"), shiny::selectInput(ns("sort_scripts"), NULL, choices = c("Mais recentes" = "recent", "Nome A-Z" = "name", "Status" = "status"), selected = "recent")),
    shiny::uiOutput(ns("folder_browser")),
    shiny::uiOutput(ns("script_list")),
    shiny::tags$main(class = "execution-detail",
      shiny::div(class = "script-selection-state", shiny::textInput(ns("script_selected"), NULL, value = "")),
      shiny::conditionalPanel(sprintf("input['%s'] !== ''", ns("script_selected")),
        shiny::uiOutput(ns("selected_script_header")),
        shiny::div(class = "content-switcher detail-switcher",
          shiny::div(class = "detail-tabs", detail_button("logs", "terminal", "Logs", TRUE), detail_button("results", "file-lines", "Resultados")),
          shiny::radioButtons(ns("execution_view"), NULL, choices = c("Logs" = "logs", "Resultados" = "results"), selected = "logs", width = "1px"),
          shiny::conditionalPanel(sprintf("input['%s'] === 'logs'", ns("execution_view")), log_card),
          shiny::conditionalPanel(sprintf("input['%s'] === 'results'", ns("execution_view")), results_card)
        )
      )
    )
  )
}

execution_server <- function(id, workspace, timeout_seconds, project_root = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    runner <- new_script_runner(workspace, timeout_seconds, project_root)
    results_revision <- shiny::reactiveVal(0L)
    log_revision <- shiny::reactiveVal(0L)
    script_revision <- shiny::reactiveVal(0L)
    selected_script <- shiny::reactiveVal(character())
    current_folder <- shiny::reactiveVal("")
    log_cleared <- shiny::reactiveVal(FALSE)
    bump <- function(value) value(shiny::isolate(value()) + 1L)
    `%||%` <- function(value, fallback) if (is.null(value) || !length(value) || is.na(value)) fallback else value
    script_active <- function() script_runner_active(runner)
    scripts_now <- function() list_r_scripts(workspace, project_root)
    status_key <- function(status) {
      status <- status %||% "Parado"
      switch(as.character(status[[1]]), "Executando" = "running", "Concluido" = "success", "Falhou" = "error", "Tempo excedido" = "error", "Interrompido" = "stopped", "idle")
    }
    status_class <- function(status) status_key(status)
    status_label <- function(status) if (identical(status, "Pronto")) "Parado" else status
    summary_for <- function(script) {
      running <- script_active() && identical(runner$script, script)
      same_script <- !is.null(runner$started_at) && identical(runner$script, script)
      if (!same_script) return(list(status = "Parado", last = "Nunca executado", duration = "-", code = "-", sort_time = as.POSIXct(0, origin = "1970-01-01")))
      elapsed <- if (is.null(runner$finished_at)) as.numeric(difftime(Sys.time(), runner$started_at, units = "secs")) else as.numeric(difftime(runner$finished_at, runner$started_at, units = "secs"))
      list(status = if (running) "Executando" else status_label(runner$status), last = format(runner$started_at, "%d/%m/%Y %H:%M"), duration = paste0(round(elapsed, 1), " s"), code = if (is.null(runner$exit_status)) "-" else as.character(runner$exit_status), sort_time = runner$started_at)
    }
    refresh_results <- function() {
      artifacts <- list_artifacts(workspace)
      tables <- table_artifacts(workspace)
      assets <- artifacts[!grepl("\\.(csv|tsv)$", artifacts$caminho, ignore.case = TRUE), , drop = FALSE]
      tv <- tables$caminho
      av <- assets$caminho
      st <- shiny::isolate(input$table)
      sa <- shiny::isolate(input$asset)
      shiny::updateSelectInput(session, "table", choices = stats::setNames(tv, tables$arquivo), selected = if (shiny::isTruthy(st) && st %in% tv) st else if (length(tv)) tv[[1]] else character())
      shiny::updateSelectInput(session, "asset", choices = stats::setNames(av, assets$arquivo), selected = if (shiny::isTruthy(sa) && sa %in% av) sa else if (length(av)) av[[1]] else character())
      bump(results_revision)
    }
    selected_summary <- function() if (length(selected_script())) summary_for(selected_script()) else NULL

    output$script_metrics <- shiny::renderUI({
      script_revision()
      scripts <- scripts_now()
      summaries <- lapply(scripts, summary_for)
      statuses <- if (length(summaries)) vapply(summaries, `[[`, character(1), "status") else character()
      shiny::div(class = "script-metrics", shiny::div(class = "metric-item", shiny::strong(length(scripts)), shiny::span("scripts")), shiny::div(class = "metric-item", shiny::strong(sum(statuses == "Executando")), shiny::span("executando")), shiny::div(class = "metric-item", shiny::strong(sum(statuses == "Concluido")), shiny::span("concluidos")), shiny::div(class = "metric-item", shiny::strong(sum(statuses %in% c("Falhou", "Tempo excedido"))), shiny::span("com erro")))
    })

    output$folder_browser <- shiny::renderUI({
      script_revision()
      folder <- current_folder()
      children <- script_tree_children(workspace, folder, project_root)
      parts <- if (nzchar(folder)) strsplit(folder, "/", fixed = TRUE)[[1]] else character()
      breadcrumb_paths <- c("", if (length(parts)) vapply(seq_along(parts), function(n) paste(parts[seq_len(n)], collapse = "/"), character(1)) else character())
      breadcrumb <- lapply(breadcrumb_paths, function(path) {
        label <- if (identical(path, "")) "Raiz" else basename(path)
        request <- jsonlite::toJSON(path, auto_unbox = TRUE)
        shiny::tags$button(type = "button", class = "folder-breadcrumb", onclick = sprintf("Shiny.setInputValue('%s',%s,{priority:'event'});", ns("folder_select"), request), label)
      })
      folder_rows <- children[children$tipo == "pasta", , drop = FALSE]
      folder_buttons <- lapply(seq_len(nrow(folder_rows)), function(index) {
        path <- folder_rows$caminho[[index]]
        request <- jsonlite::toJSON(path, auto_unbox = TRUE)
        shiny::tags$button(type = "button", class = "folder-entry", onclick = sprintf("Shiny.setInputValue('%s',%s,{priority:'event'});", ns("folder_select"), request), shiny::icon("folder"), shiny::span(folder_rows$nome[[index]]))
      })
      source_label <- if (nzchar(folder)) script_display_path(folder) else "/projects"
      shiny::div(class = "folder-browser", shiny::div(class = "folder-browser-heading", shiny::span(shiny::icon("folder-tree"), "Pastas montadas"), shiny::span(source_label, class = "folder-current-path")), shiny::div(class = "folder-breadcrumbs", breadcrumb), if (length(folder_buttons)) shiny::div(class = "folder-entries", folder_buttons) else NULL)
    })

    output$script_list <- shiny::renderUI({
      script_revision()
      all_scripts <- scripts_now()
      filter <- tolower(trimws(input$script_filter %||% ""))
      scripts <- if (nzchar(filter)) all_scripts[grepl(filter, tolower(all_scripts), fixed = TRUE)] else all_scripts[dirname(all_scripts) == if (nzchar(current_folder())) current_folder() else "."]
      rows <- lapply(scripts, function(script) list(script = script, summary = summary_for(script)))
      filter_key <- input$status_filter %||% "all"
      if (!identical(filter_key, "all")) rows <- Filter(function(row) identical(status_key(row$summary$status), filter_key), rows)
      if (identical(input$sort_scripts, "name")) rows <- rows[order(vapply(rows, function(row) tolower(row$script), character(1)))]
      if (identical(input$sort_scripts, "status")) rows <- rows[order(vapply(rows, function(row) row$summary$status, character(1)))]
      if (identical(input$sort_scripts, "recent")) rows <- rows[order(vapply(rows, function(row) as.numeric(row$summary$sort_time), numeric(1)), decreasing = TRUE)]
      if (!length(rows)) return(shiny::div(class = "list-empty scripts-empty", shiny::icon("file-circle-xmark"), shiny::strong("Nenhum script encontrado"), shiny::span(if (nzchar(filter)) "Tente mudar a busca." else "Abra uma pasta ou atualize a montagem.")))
      current <- selected_script()
      cards <- lapply(seq_along(rows), function(index) {
        row <- rows[[index]]
        script <- row$script
        summary <- row$summary
        request <- jsonlite::toJSON(script, auto_unbox = TRUE)
        running <- identical(summary$status, "Executando")
        selected <- identical(current, script)
        action <- if (running) {
          shiny::actionButton(ns(paste0("stop_script_", index)), NULL, icon = shiny::icon("stop"), title = "Interromper", class = "script-quick-action stop", onclick = sprintf("event.stopPropagation();Shiny.setInputValue('%s',%s,{priority:'event'});", ns("stop_request"), request))
        } else {
          shiny::actionButton(ns(paste0("run_script_", index)), NULL, icon = shiny::icon("play"), title = "Executar", class = "script-quick-action", disabled = script_active(), onclick = sprintf("event.stopPropagation();Shiny.setInputValue('%s',%s,{priority:'event'});", ns("run_request"), request))
        }
        main <- shiny::div(class = "script-card-main",
          shiny::div(class = "script-card-icon", shiny::icon("file-code")),
          shiny::div(class = "script-card-copy",
            shiny::div(class = "script-card-title", shiny::strong(basename(script)), shiny::span(class = paste("status-badge", status_class(summary$status)), shiny::span(class = "status-dot"), summary$status)),
            shiny::span(class = "script-card-path", script_display_path(script)),
            shiny::div(class = "script-card-meta", shiny::span(shiny::icon("clock"), summary$last), shiny::span(shiny::icon("hourglass-half"), summary$duration), shiny::span(shiny::icon("hashtag"), paste("codigo", summary$code)))
          )
        )
        shiny::tags$article(class = paste("script-card", if (selected) "selected" else ""), onclick = sprintf("Shiny.setInputValue('%s',%s,{priority:'event'});", ns("script_select"), request), main, action)
      })
      shiny::div(class = "script-list", cards)
    })

    output$selected_script_header <- shiny::renderUI({
      script <- selected_script()
      shiny::req(length(script))
      summary <- selected_summary()
      running <- identical(summary$status, "Executando")
      request <- jsonlite::toJSON(script, auto_unbox = TRUE)
      run_button <- if (running) shiny::actionButton(ns("stop_selected"), "Interromper", icon = shiny::icon("stop"), class = "btn-outline-danger", onclick = sprintf("Shiny.setInputValue('%s',%s,{priority:'event'});", ns("stop_request"), request)) else shiny::actionButton(ns("run_selected"), "Executar", icon = shiny::icon("play"), class = "btn-primary", disabled = script_active(), onclick = sprintf("Shiny.setInputValue('%s',%s,{priority:'event'});", ns("run_request"), request))
      shiny::div(class = "selected-script-context", shiny::actionButton(ns("script_back"), "Voltar para scripts", icon = shiny::icon("arrow-left"), class = "breadcrumb-back"), shiny::span(class = "context-divider"), shiny::span(class = "context-label", script_display_path(script)), shiny::span(class = paste("status-badge", "large", status_class(summary$status)), shiny::span(class = "status-dot"), summary$status), shiny::div(class = "selected-script-buttons", run_button, shiny::actionButton(ns("refresh_selected"), NULL, icon = shiny::icon("refresh"), class = "btn-ghost", title = "Atualizar dados")))
    })

    output$log_terminal <- shiny::renderUI({
      log_revision()
      if (script_active()) shiny::invalidateLater(1000, session)
      if (log_cleared()) return(shiny::div(class = "terminal-output terminal-empty", "Visualizacao limpa. Atualize para carregar os logs novamente."))
      content <- script_runner_log(runner)
      lines <- strsplit(content, "\n", fixed = TRUE)[[1]]
      shiny::div(class = "terminal-output", lapply(lines, function(line) {
        level <- if (grepl("stderr|error|erro|falhou", line, ignore.case = TRUE)) "error" else if (grepl("warning|aviso", line, ignore.case = TRUE)) "warning" else if (grepl("Status: Concluido|conclu", line, ignore.case = TRUE)) "success" else "info"
        shiny::div(class = paste("terminal-line", level), htmltools::htmlEscape(line))
      }))
    })

    output$results_panel <- shiny::renderUI({
      results_revision()
      artifacts <- list_artifacts(workspace)
      tables <- table_artifacts(workspace)
      assets <- artifacts[!grepl("\\.(csv|tsv)$", artifacts$caminho, ignore.case = TRUE), , drop = FALSE]
      table_section <- if (nrow(tables)) bslib::card(class = "artifact-card", bslib::card_header(shiny::tagList(shiny::icon("table"), "Tabelas")), shiny::selectInput(session$ns("table"), NULL, choices = NULL), DT::DTOutput(session$ns("table_view")), shiny::downloadButton(session$ns("download_table"), label = shiny::tagList(shiny::icon("download"), "Baixar tabela"), class = "btn-ghost")) else shiny::div(class = "result-hint", shiny::icon("table"), shiny::span("Nenhuma tabela gerada"))
      asset_section <- if (nrow(assets)) bslib::card(class = "artifact-card", bslib::card_header(shiny::tagList(shiny::icon("image"), "Imagens e arquivos")), shiny::selectInput(session$ns("asset"), NULL, choices = NULL), shiny::uiOutput(session$ns("asset_preview")), shiny::downloadButton(session$ns("download_asset"), label = shiny::tagList(shiny::icon("download"), "Baixar arquivo"), class = "btn-ghost")) else shiny::div(class = "result-hint", shiny::icon("image"), shiny::span("Nenhuma imagem gerada"))
      files_card <- if (nrow(artifacts)) bslib::card(class = "artifact-card files-artifact-card", bslib::card_header(shiny::tagList(shiny::icon("file"), "Arquivos gerados")), DT::DTOutput(session$ns("files"))) else shiny::div(class = "result-hint wide", shiny::icon("folder-open"), shiny::span("Nenhum resultado disponivel no workspace"))
      shiny::div(class = "results-grid", files_card, table_section, asset_section)
    })
    output$files <- DT::renderDT({ results_revision(); DT::datatable(list_artifacts(workspace), options = list(pageLength = 8, scrollX = TRUE, responsive = TRUE), rownames = FALSE) })
    output$table_view <- DT::renderDT({ shiny::req(input$table); value <- tryCatch(read_result_table(workspace, input$table), error = function(e) data.frame(Erro = conditionMessage(e))); DT::datatable(value, options = list(pageLength = 8, scrollX = TRUE, responsive = TRUE), rownames = FALSE) })
    output$download_table <- shiny::downloadHandler(filename = function() basename(input$table), content = function(file) file.copy(artifact_path(workspace, input$table), file))
    output$asset_preview <- shiny::renderUI({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); ext <- tolower(tools::file_ext(path)); if (ext %in% c("png", "jpg", "jpeg")) return(shiny::imageOutput(session$ns("asset_image"), height = "auto")); if (ext %in% c("txt", "log", "json", "html", "htm")) return(shiny::verbatimTextOutput(session$ns("asset_text"))); shiny::p("Pre-visualizacao indisponivel; use o download.", class = "text-muted") })
    output$asset_image <- shiny::renderImage({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); list(src = path, contentType = paste0("image/", tools::file_ext(path)), alt = input$asset) }, deleteFile = FALSE)
    output$asset_text <- shiny::renderText({ shiny::req(input$asset); tail_result_file(workspace, input$asset) })
    output$download_asset <- shiny::downloadHandler(filename = function() basename(input$asset), content = function(file) file.copy(artifact_path(workspace, input$asset), file))

    shiny::observe({
      shiny::invalidateLater(1000, session)
      if (!is.null(runner$process) && identical(runner$status, "Executando")) {
        old_status <- runner$status
        script_runner_tick(runner)
        bump(log_revision)
        bump(script_revision)
        if (!identical(old_status, runner$status)) refresh_results()
      }
    })
    shiny::observeEvent(input$refresh_scripts, { bump(script_revision) })
    shiny::observeEvent(input$folder_select, { current_folder(input$folder_select); bump(script_revision) }, ignoreNULL = TRUE)
    shiny::observeEvent(input$refresh_results, { refresh_results() })
    shiny::observeEvent(input$refresh_logs, { log_cleared(FALSE); bump(log_revision) })
    shiny::observeEvent(input$clear_log_view, { log_cleared(TRUE); bump(log_revision) })
    shiny::observeEvent(input$refresh_selected, { bump(script_revision); refresh_results() })
    shiny::observeEvent(input$script_select, {
      selected_script(input$script_select)
      shiny::updateTextInput(session, "script_selected", value = input$script_select)
      shiny::updateRadioButtons(session, "execution_view", selected = "logs")
      log_cleared(FALSE)
      bump(log_revision)
    }, ignoreNULL = TRUE)
    shiny::observeEvent(input$script_back, { selected_script(character()); shiny::updateTextInput(session, "script_selected", value = ""); bump(script_revision) })
    shiny::observeEvent(input$run_request, {
      script <- input$run_request
      tryCatch({
        script_runner_start(runner, script)
        selected_script(script)
        shiny::updateTextInput(session, "script_selected", value = script)
        log_cleared(FALSE)
      }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
      bump(script_revision)
      bump(log_revision)
    }, ignoreNULL = TRUE)
    shiny::observeEvent(input$stop_request, {
      if (!is.null(runner$process) && identical(input$stop_request, runner$script) && identical(runner$status, "Executando")) script_runner_stop(runner)
      bump(script_revision)
      bump(log_revision)
    }, ignoreNULL = TRUE)
  })
}
