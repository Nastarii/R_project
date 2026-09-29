execution_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_sidebar(
      sidebar = bslib::sidebar(
        width = "330px",
        shiny::div(class = "sidebar-intro", shiny::div(class = "eyebrow", shiny::icon("terminal"), "CENTRAL DE EXECUÇÃO"), shiny::h4("Executar scripts"), shiny::p("Cada script aparece em uma lista própria, com execução direta.", class = "text-muted small")),
        shiny::div(class = "script-list-heading", shiny::span(shiny::tagList(shiny::icon("file-code"), "Scripts disponíveis")), shiny::actionButton(ns("refresh_scripts"), NULL, icon = shiny::icon("refresh"), class = "icon-button", title = "Atualizar scripts")),
        shiny::uiOutput(ns("script_list")),
        shiny::div(class = "run-status-card", shiny::div(class = "status-heading", shiny::strong("Estado", class = "status-label"), shiny::span(class = "status-dot")), shiny::textOutput(ns("status")), shiny::textOutput(ns("duration"))),
        shiny::p(shiny::tagList(shiny::icon("shield-halved"), " Scripts R executam código arbitrário. Execute somente arquivos confiáveis."), class = "text-muted small safety-note")
      ),
      shiny::div(
        class = "execution-content",
        shiny::div(class = "page-intro", shiny::div(class = "eyebrow", shiny::icon("bolt"), "FLUXO DE TRABALHO"), shiny::h2("Execução e resultados"), shiny::p("Acompanhe os logs em tempo real e consulte os arquivos produzidos pelo script.")),
        shiny::div(
          class = "content-switcher",
          bslib::navset_pill(
            id = ns("execution_view"),
          bslib::nav_panel(
            shiny::tagList(shiny::icon("list"), "Logs"),
            bslib::card(
              class = "content-card log-card",
              bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("list"), "Logs")), shiny::div(class = "card-header-actions", shiny::span("saída da execução", class = "card-caption"), shiny::actionButton(ns("toggle_history"), "Histórico", icon = shiny::icon("clock"), class = "btn-ghost btn-sm")))),
              shiny::div(class = "log-toolbar", shiny::span("Log atual", class = "log-current-label"), shiny::actionButton(ns("refresh_logs"), "Atualizar", icon = shiny::icon("refresh"), class = "btn-ghost btn-sm")),
              shiny::uiOutput(ns("log_history_panel")),
              shiny::verbatimTextOutput(ns("log"), placeholder = TRUE)
            )
          ),
          bslib::nav_panel(
            shiny::tagList(shiny::icon("file-lines"), "Resultados"),
            bslib::card(
              class = "content-card results-card",
              bslib::card_header(shiny::div(class = "card-heading", shiny::span(shiny::tagList(shiny::icon("file-lines"), "Resultados")), shiny::span("arquivos produzidos pelo script", class = "card-caption"))),
              shiny::actionButton(ns("refresh_results"), "Atualizar resultados", icon = shiny::icon("refresh"), class = "btn-ghost result-refresh"),
              shiny::uiOutput(ns("results_panel"))
            )
          )
        )
      )
    )
  )
  )
}

execution_server <- function(id, workspace, timeout_seconds) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns
    runner <- new_script_runner(workspace, timeout_seconds)
    results_revision <- shiny::reactiveVal(0L)
    log_revision <- shiny::reactiveVal(0L)
    history_revision <- shiny::reactiveVal(0L)
    script_revision <- shiny::reactiveVal(0L)
    log_signature <- shiny::reactiveVal("")
    selected_log <- shiny::reactiveVal(character())
    history_open <- shiny::reactiveVal(FALSE)
    script_active <- function() !is.null(runner$process) && runner$process$is_alive()

    update_scripts <- function() script_revision(shiny::isolate(script_revision()) + 1L)
    update_results <- function() {
      artifacts <- list_artifacts(workspace)
      tables <- table_artifacts(workspace)
      asset_artifacts <- artifacts[!grepl("\\.(csv|tsv)$", artifacts$caminho, ignore.case = TRUE), , drop = FALSE]
      table_values <- tables$caminho
      asset_values <- asset_artifacts$caminho
      selected_table <- shiny::isolate(input$table)
      selected_asset <- shiny::isolate(input$asset)
      shiny::updateSelectInput(session, "table", choices = stats::setNames(table_values, tables$arquivo), selected = if (shiny::isTruthy(selected_table) && selected_table %in% table_values) selected_table else if (length(table_values)) table_values[[1]] else character())
      shiny::updateSelectInput(session, "asset", choices = stats::setNames(asset_values, asset_artifacts$arquivo), selected = if (shiny::isTruthy(selected_asset) && selected_asset %in% asset_values) selected_asset else if (length(asset_values)) asset_values[[1]] else character())
      results_revision(shiny::isolate(results_revision()) + 1L)
    }
    current_log_relative <- function() {
      if (is.null(runner$log_file)) return(character())
      file.path("logs", basename(runner$log_file))
    }
    refresh_log_history <- function() {
      history <- list_log_history(workspace)
      signature <- paste(history$caminho, history$modificado, collapse = "|")
      if (!identical(signature, shiny::isolate(log_signature()))) {
        log_signature(signature)
        history_revision(shiny::isolate(history_revision()) + 1L)
        log_revision(shiny::isolate(log_revision()) + 1L)
      }
    }

    observe({ update_scripts() })
    observe({ update_results() })
    observe({ shiny::invalidateLater(1000, session); refresh_log_history() })
    shiny::observeEvent(input$refresh_scripts, { update_scripts() })
    shiny::observeEvent(input$refresh_results, { update_results() })
    shiny::observeEvent(input$refresh_logs, { refresh_log_history() })
    shiny::observeEvent(input$toggle_history, { history_open(!history_open()) })

    output$script_list <- shiny::renderUI({
      script_revision()
      scripts <- list_r_scripts(workspace)
      if (!length(scripts)) return(shiny::div(class = "list-empty", shiny::icon("file-circle-xmark"), shiny::span("Nenhum script .R encontrado.")))
      shiny::div(class = "script-list", lapply(seq_along(scripts), function(index) {
        script <- scripts[[index]]
        request <- jsonlite::toJSON(script, auto_unbox = TRUE)
        folder <- dirname(script)
        folder <- if (identical(folder, ".")) "raiz do projeto" else folder
        is_running <- script_active() && identical(runner$script, script)
        script_button <- if (is_running) {
          shiny::actionButton(ns(paste0("stop_script_", index)), "Interromper", icon = shiny::icon("stop"), class = "btn-outline-danger btn-sm script-run-button", onclick = sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", ns("stop_request"), request))
        } else {
          shiny::actionButton(ns(paste0("run_script_", index)), "Executar", icon = shiny::icon("play"), class = "btn-primary btn-sm script-run-button", disabled = script_active(), onclick = sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", ns("run_request"), request))
        }
        shiny::div(class = "script-row", shiny::div(class = "script-meta", shiny::div(class = "script-icon", shiny::icon("file-code")), shiny::div(class = "script-name", shiny::span(basename(script)), shiny::tags$small(folder))), script_button)
      }))
    })

    shiny::observeEvent(input$run_request, {
      script <- input$run_request
      tryCatch({
        script_runner_start(runner, script)
        selected_log(current_log_relative())
      }, error = function(e) shiny::showNotification(conditionMessage(e), type = "error"))
      refresh_log_history()
      update_scripts()
    }, ignoreNULL = TRUE)
    shiny::observeEvent(input$stop_request, {
      if (script_active() && identical(input$stop_request, runner$script)) script_runner_stop(runner)
      refresh_log_history()
      update_scripts()
    }, ignoreNULL = TRUE)
    observe({
      input$run_request; input$stop_request
      if (!script_active()) return()
      shiny::invalidateLater(1000, session)
      old_status <- runner$status
      script_runner_tick(runner)
      if (!identical(old_status, runner$status)) {
        update_results()
        update_scripts()
      }
    })

    output$log_history_panel <- shiny::renderUI({
      shiny::req(history_open())
      history_revision()
      history <- list_log_history(workspace)
      header <- shiny::div(class = "history-panel-header", shiny::div(shiny::strong("Histórico de logs"), shiny::span("Selecione um registro para visualizar", class = "text-muted small")), shiny::div(class = "history-panel-actions", shiny::actionButton(ns("refresh_history_list"), NULL, icon = shiny::icon("refresh"), class = "icon-button", title = "Atualizar histórico"), shiny::actionButton(ns("clear_logs"), "Limpar", icon = shiny::icon("trash"), class = "btn-outline-danger btn-sm")))
      if (!nrow(history)) return(shiny::div(class = "history-panel", header, shiny::div(class = "list-empty history-empty", shiny::icon("clock"), shiny::span("Nenhum log salvo ainda."))))
      rows <- lapply(seq_len(nrow(history)), function(index) {
        path <- history$caminho[[index]]
        request <- jsonlite::toJSON(path, auto_unbox = TRUE)
        shiny::div(class = "history-row", shiny::tags$button(type = "button", class = "history-open", onclick = sprintf("Shiny.setInputValue('%s', %s, {priority: 'event'});", ns("log_request"), request), shiny::span(class = "history-type", history$tipo[[index]]), shiny::span(class = "history-name", history$arquivo[[index]]), shiny::span(class = "history-date", history$modificado[[index]])), shiny::tags$button(type = "button", class = "history-delete", title = "Excluir log", onclick = sprintf("event.stopPropagation(); Shiny.setInputValue('%s', %s, {priority: 'event'});", ns("delete_log_request"), request), shiny::icon("trash")))
      })
      shiny::div(class = "history-panel", header, shiny::div(class = "history-list", rows))
    })
    shiny::observeEvent(input$refresh_history_list, { refresh_log_history(); history_revision(shiny::isolate(history_revision()) + 1L) })
    shiny::observeEvent(input$log_request, { selected_log(input$log_request); history_open(FALSE); log_revision(shiny::isolate(log_revision()) + 1L) }, ignoreNULL = TRUE)
    shiny::observeEvent(input$delete_log_request, {
      selected <- input$delete_log_request
      if (script_active() && identical(normalizePath(log_history_path(workspace, selected), winslash = "/", mustWork = FALSE), normalizePath(runner$log_file, winslash = "/", mustWork = FALSE))) {
        shiny::showNotification("Interrompa o script antes de excluir o log atual.", type = "warning")
        return()
      }
      if (delete_log_file(workspace, selected)) shiny::showNotification("Log excluído.", type = "message")
      if (identical(selected, shiny::isolate(selected_log()))) selected_log(character())
      refresh_log_history()
    }, ignoreNULL = TRUE)
    shiny::observeEvent(input$clear_logs, {
      keep <- if (script_active()) current_log_relative() else character()
      removed <- delete_all_log_files(workspace, keep)
      if (!length(keep)) selected_log(character())
      refresh_log_history()
      message <- if (length(keep)) paste0(removed, " log(s) excluído(s). O log da execução atual foi preservado.") else paste0(removed, " log(s) excluído(s).")
      shiny::showNotification(message, type = "message")
    })

    output$status <- shiny::renderText({ input$run_request; input$stop_request; if (script_active()) shiny::invalidateLater(1000, session); paste(runner$status, if (!is.null(runner$exit_status)) paste("(código", runner$exit_status, ")") else "") })
    output$duration <- shiny::renderText({ input$run_request; input$stop_request; if (script_active()) shiny::invalidateLater(1000, session); if (is.null(runner$started_at)) return("Duração: -"); end <- if (is.null(runner$finished_at)) Sys.time() else runner$finished_at; paste("Duração:", round(as.numeric(difftime(end, runner$started_at, units = "secs")), 1), "s") })
    output$log <- shiny::renderText({
      log_revision(); input$run_request; input$stop_request
      if (script_active()) shiny::invalidateLater(1000, session)
      selected <- selected_log()
      if (shiny::isTruthy(selected) && file.exists(log_history_path(workspace, selected))) return(read_log_history(workspace, selected))
      script_runner_log(runner)
    })

    output$results_panel <- shiny::renderUI({
      results_revision()
      artifacts <- list_artifacts(workspace)
      tables <- table_artifacts(workspace)
      asset_artifacts <- artifacts[!grepl("\\.(csv|tsv)$", artifacts$caminho, ignore.case = TRUE), , drop = FALSE]
      table_section <- if (nrow(tables)) {
        bslib::card(class = "artifact-card", bslib::card_header(shiny::tagList(shiny::icon("table"), "Tabela")), shiny::selectInput(session$ns("table"), NULL, choices = NULL), DT::DTOutput(session$ns("table_view")), shiny::downloadButton(session$ns("download_table"), label = shiny::tagList(shiny::icon("download"), "Baixar tabela"), class = "btn-ghost"))
      } else shiny::div(class = "result-hint", shiny::icon("table"), shiny::span("Nenhuma tabela gerada"))
      asset_section <- if (nrow(asset_artifacts)) {
        bslib::card(class = "artifact-card", bslib::card_header(shiny::tagList(shiny::icon("image"), "Imagem ou arquivo")), shiny::selectInput(session$ns("asset"), NULL, choices = NULL), shiny::uiOutput(session$ns("asset_preview")), shiny::downloadButton(session$ns("download_asset"), label = shiny::tagList(shiny::icon("download"), "Baixar arquivo"), class = "btn-ghost"))
      } else shiny::div(class = "result-hint", shiny::icon("image"), shiny::span("Nenhuma imagem gerada"))
      files_card <- if (nrow(artifacts)) bslib::card(class = "artifact-card files-artifact-card", bslib::card_header(shiny::tagList(shiny::icon("file"), "Arquivos gerados")), DT::DTOutput(session$ns("files"))) else NULL
      shiny::div(class = "results-grid", files_card, table_section, asset_section)
    })
    output$files <- DT::renderDT({ results_revision(); DT::datatable(list_artifacts(workspace), options = list(pageLength = 8, scrollX = TRUE, responsive = TRUE), rownames = FALSE) })
    output$table_view <- DT::renderDT({ shiny::req(input$table); value <- tryCatch(read_result_table(workspace, input$table), error = function(e) data.frame(Erro = conditionMessage(e))); DT::datatable(value, options = list(pageLength = 8, scrollX = TRUE, responsive = TRUE), rownames = FALSE) })
    output$download_table <- shiny::downloadHandler(filename = function() basename(input$table), content = function(file) file.copy(artifact_path(workspace, input$table), file))
    output$asset_preview <- shiny::renderUI({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); ext <- tolower(tools::file_ext(path)); if (ext %in% c("png", "jpg", "jpeg")) return(shiny::imageOutput(session$ns("asset_image"), height = "auto")); if (ext %in% c("txt", "log", "json", "html", "htm")) return(shiny::verbatimTextOutput(session$ns("asset_text"))); shiny::p("Pré-visualização indisponível; use o download.", class = "text-muted") })
    output$asset_image <- shiny::renderImage({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); list(src = path, contentType = paste0("image/", tools::file_ext(path)), alt = input$asset) }, deleteFile = FALSE)
    output$asset_text <- shiny::renderText({ shiny::req(input$asset); tail_result_file(workspace, input$asset) })
    output$download_asset <- shiny::downloadHandler(filename = function() basename(input$asset), content = function(file) file.copy(artifact_path(workspace, input$asset), file))
  })
}
