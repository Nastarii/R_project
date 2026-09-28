execution_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::layout_sidebar(sidebar = bslib::sidebar(shiny::selectInput(ns("script"), "Script R", choices = NULL), shiny::actionButton(ns("refresh_scripts"), "Atualizar scripts", class = "btn-outline-secondary w-100"), shiny::actionButton(ns("run"), "Executar", class = "btn-success w-100"), shiny::actionButton(ns("stop"), "Interromper", class = "btn-danger w-100"), shiny::hr(), shiny::strong("Estado"), shiny::textOutput(ns("status")), shiny::textOutput(ns("duration")), shiny::p("Scripts R executam código arbitrário. Execute somente arquivos confiáveis.", class = "text-muted small")), bslib::card(bslib::card_header("Log em tempo real"), shiny::verbatimTextOutput(ns("log"), placeholder = TRUE))),
    bslib::layout_columns(bslib::card(bslib::card_header("Arquivos gerados"), shiny::actionButton(ns("refresh_results"), "Atualizar resultados", class = "btn-outline-secondary"), DT::DTOutput(ns("files"))), bslib::card(bslib::card_header("Tabela"), shiny::selectInput(ns("table"), NULL, choices = NULL), DT::DTOutput(ns("table_view")), shiny::downloadButton(ns("download_table"), "Baixar tabela")), bslib::card(bslib::card_header("Imagem ou arquivo"), shiny::selectInput(ns("asset"), NULL, choices = NULL), shiny::uiOutput(ns("asset_preview")), shiny::downloadButton(ns("download_asset"), "Baixar arquivo")), col_widths = c(4, 4, 4))
  )
}

execution_server <- function(id, workspace, timeout_seconds) {
  shiny::moduleServer(id, function(input, output, session) {
    runner <- new_script_runner(workspace, timeout_seconds)
    script_active <- function() !is.null(runner$process) && runner$process$is_alive()
    update_scripts <- function() { scripts <- list_r_scripts(workspace); selected <- shiny::isolate(input$script); shiny::updateSelectInput(session, "script", choices = scripts, selected = if (shiny::isTruthy(selected) && selected %in% scripts) selected else if (length(scripts)) scripts[[1]] else character()) }
    update_results <- function() { artifacts <- list_artifacts(workspace); tables <- table_artifacts(workspace); table_values <- tables$caminho; asset_values <- artifacts$caminho; selected_table <- shiny::isolate(input$table); selected_asset <- shiny::isolate(input$asset); shiny::updateSelectInput(session, "table", choices = stats::setNames(table_values, tables$arquivo), selected = if (shiny::isTruthy(selected_table) && selected_table %in% table_values) selected_table else if (length(table_values)) table_values[[1]] else character()); shiny::updateSelectInput(session, "asset", choices = stats::setNames(asset_values, artifacts$arquivo), selected = if (shiny::isTruthy(selected_asset) && selected_asset %in% asset_values) selected_asset else if (length(asset_values)) asset_values[[1]] else character()) }
    observe({ update_scripts() }); observe({ update_results() }); observeEvent(input$refresh_scripts, { update_scripts() }); observeEvent(input$refresh_results, { update_results() })
    observe({
      input$run; input$stop
      if (!script_active()) return()
      shiny::invalidateLater(1000, session); old_status <- runner$status; script_runner_tick(runner)
      if (!identical(old_status, runner$status)) update_results()
    })
    observeEvent(input$run, { tryCatch(script_runner_start(runner, input$script), error = function(e) shiny::showNotification(conditionMessage(e), type = "error")) }); observeEvent(input$stop, { script_runner_stop(runner) })
    output$status <- shiny::renderText({ input$run; input$stop; if (script_active()) shiny::invalidateLater(1000, session); paste(runner$status, if (!is.null(runner$exit_status)) paste("(código", runner$exit_status, ")") else "") })
    output$duration <- shiny::renderText({ input$run; input$stop; if (script_active()) shiny::invalidateLater(1000, session); if (is.null(runner$started_at)) return("Duração: —"); end <- if (is.null(runner$finished_at)) Sys.time() else runner$finished_at; paste("Duração:", round(as.numeric(difftime(end, runner$started_at, units = "secs")), 1), "s") })
    output$log <- shiny::renderText({ input$run; input$stop; if (script_active()) shiny::invalidateLater(1000, session); script_runner_log(runner) })
    output$files <- DT::renderDT({ input$refresh_results; DT::datatable(list_artifacts(workspace), options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE) })
    output$table_view <- DT::renderDT({ shiny::req(input$table); value <- tryCatch(read_result_table(workspace, input$table), error = function(e) data.frame(Erro = conditionMessage(e))); DT::datatable(value, options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE) })
    output$download_table <- shiny::downloadHandler(filename = function() basename(input$table), content = function(file) file.copy(artifact_path(workspace, input$table), file))
    output$asset_preview <- shiny::renderUI({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); ext <- tolower(tools::file_ext(path)); if (ext %in% c("png", "jpg", "jpeg")) return(shiny::imageOutput(session$ns("asset_image"), height = "auto")); if (ext %in% c("txt", "log", "json", "html", "htm")) return(shiny::verbatimTextOutput(session$ns("asset_text"))); shiny::p("Pré-visualização indisponível; use o download.", class = "text-muted") })
    output$asset_image <- shiny::renderImage({ shiny::req(input$asset); path <- artifact_path(workspace, input$asset); list(src = path, contentType = paste0("image/", tools::file_ext(path)), alt = input$asset) }, deleteFile = FALSE)
    output$asset_text <- shiny::renderText({ shiny::req(input$asset); tail_result_file(workspace, input$asset) })
    output$download_asset <- shiny::downloadHandler(filename = function() basename(input$asset), content = function(file) file.copy(artifact_path(workspace, input$asset), file))
  })
}
