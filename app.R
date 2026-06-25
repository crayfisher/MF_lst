#
# This is a shiny app for reading modflow listing files
# created by Pawel Rakowski
# sept 2020 / updated June 2026
#

# Point reticulate to flopy_env Python
Sys.setenv(RETICULATE_PYTHON = "/home/pawel/miniforge3/envs/flopy_env/bin/python")

library(reticulate)
library(shiny)
library(plotly)
library(DT)
library(tidyverse)
library(lubridate)
library(bslib)
library(shinymanager)
source("scripts/flopy_r.R")

# Define UI for application 
# file size up to 1000MB
options(shiny.maxRequestSize = 1000*1024^2)

ui <- page_sidebar(
  theme = bs_theme(
    bootswatch = "darkly",
    primary = "#0d6efd"
  ),
  title = "R GW Chart - MODFLOW budget viewer",
  
  # Left Sidebar: Controls & File Uploads
  sidebar = sidebar(
    title = "Controls",
    position = "left",
    width = 340,
    
    fileInput("files", "Upload MODFLOW listing file(s)", 
              multiple = TRUE, 
              accept = c(".lst", ".list", ".txt", ".out")),
              
    uiOutput("loaded_files_list"),
    actionButton("clear_files", "Clear All Files", class = "btn-danger btn-sm w-100", style = "margin-bottom: 20px;"),
    
    hr(style = "border-color: #3d3d3d;"),
              
    radioButtons("incr_cum", "Rate / Cumulative",
                 choices = list("Rate" = "incr", "Cumulative" = "cum"), 
                 selected = "incr"),
                 
    radioButtons("include_zero", "Include Zero on Y-axis?",
                 choices = list("Yes" = 1, "No" = 0), 
                 selected = 1),
                 
    radioButtons("radio_unit", "Units",
                 choiceNames = c("m³/d", "L/s", "GL/a"),
                 choiceValues = c(1, 0.011574074, 0.0003650000), 
                 selected = 1),
                 
    numericInput("mult", "Multiplier (e.g. cross-section)", value = 1, min = 0.0001),
    
    radioButtons("radio_time_unit", "Time Units",
                 choiceNames = c("Days", "Date", "Stress Period (SP)"),
                 choiceValues = c("days", "date", "SP"), 
                 selected = "days")
  ),
  
  # Custom CSS to make it look even more premium
  tags$head(
    tags$style(HTML("
      .card {
        border-radius: 12px;
        border: 1px solid #2d2d2d;
        background-color: #1e1e1e !important;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.35);
        margin-bottom: 20px;
        transition: all 0.2s ease-in-out;
      }
      .card:hover {
        box-shadow: 0 6px 24px rgba(0, 0, 0, 0.45);
      }
      .card-header {
        background-color: #252525 !important;
        border-bottom: 1px solid #2d2d2d !important;
        font-weight: 600;
        color: #ffffff;
      }
      .sidebar {
        background-color: #161616 !important;
      }
      .sidebar-right-header {
        display: flex;
        justify-content: space-between;
        margin-bottom: 15px;
        border-bottom: 1px solid #3d3d3d;
        padding-bottom: 8px;
      }
      .btn-primary {
        background-color: #0d6efd;
        border-color: #0d6efd;
        border-radius: 6px;
        font-weight: 500;
        transition: all 0.2s ease;
      }
      .btn-primary:hover {
        background-color: #0b5ed7;
        border-color: #0a58ca;
        transform: translateY(-1px);
      }
      /* Custom scrollbars */
      ::-webkit-scrollbar {
        width: 8px;
        height: 8px;
      }
      ::-webkit-scrollbar-track {
        background: #1e1e1e;
      }
      ::-webkit-scrollbar-thumb {
        background: #3a3a3a;
        border-radius: 4px;
      }
      ::-webkit-scrollbar-thumb:hover {
        background: #4a4a4a;
      }
      .accordion-button {
        background-color: #1e1e1e !important;
        color: #ffffff !important;
        border: none !important;
        box-shadow: none !important;
      }
      .accordion-item {
        background-color: #1e1e1e !important;
        border: 1px solid #2d2d2d !important;
        border-radius: 8px !important;
      }
    "))
  ),
  
  # Right Sidebar & Main Content Area
  layout_sidebar(
    border = FALSE,
    padding = 0,
    
    # Right Sidebar: Budget Terms Selection
    sidebar = sidebar(
      title = "Budget Terms",
      position = "right",
      width = 300,
      open = "open",
      
      # Select/Unselect helpers
      tags$div(
        class = "sidebar-right-header",
        actionLink("select_all_terms", "Select All", style = "font-weight: 500; font-size: 0.9rem; text-decoration: none;"),
        actionLink("unselect_all_terms", "Unselect All", style = "color: #dc3545; font-weight: 500; font-size: 0.9rem; text-decoration: none;")
      ),
      
      checkboxGroupInput("terms_in", "Terms IN", choices = ""),
      hr(style = "border-color: #3d3d3d;"),
      checkboxGroupInput("terms_out", "Terms OUT", choices = ""),
      hr(style = "border-color: #3d3d3d;"),
      checkboxGroupInput("terms_other", "Terms OTHER", choices = "")
    ),
    
    # Main Panel display (Plot & Table) styled with Flexbox to fill the viewport
    tags$div(
      style = "display: flex; flex-direction: column; height: calc(100vh - 40px); gap: 10px;",
      
      # Card 1: Plot (takes up all available space)
      card(
        style = "flex: 1; min-height: 0; margin-bottom: 0;",
        full_screen = TRUE,
        card_header("Water Budget Plot"),
        card_body(
          style = "padding: 0; min-height: 0; height: 100%;",
          plotlyOutput('chart', height = "100%")
        )
      ),
      
      # Collapsible Panel: Table & Export Options (hugs the bottom of the screen)
      accordion(
        open = FALSE, # Starts collapsed by default
        accordion_panel(
          "Budget Table & Export",
          icon = icon("table"),
          DT::dataTableOutput("table"),
          hr(style = "border-color: #2d2d2d; margin-top: 20px; margin-bottom: 20px;"),
          
          # Clean integrated export block
          p(tags$strong("Export Data Options & Download"), style = "font-size: 1.1rem; margin-bottom: 15px; color: #a0a0a0;"),
          layout_columns(
            col_widths = c(3, 3, 3, 3),
            downloadButton("download_data", "Download CSV", class = "btn-primary w-100"),
            radioButtons("radio_download_long_wide", "Data Format",
                         choices = list("Long Format" = 1, "Wide Format" = 2), 
                         selected = 1, inline = TRUE),
            radioButtons("radio_download_what", "Which Data",
                         choices = list("All Data" = 1, "Selected Data" = 2), 
                         selected = 2, inline = TRUE),
            conditionalPanel(
              condition = "input.radio_download_what == 1",
              radioButtons("radio_download_unit", "Download Units",
                           choices = list("Original Units" = 1, "Selected Units" = 2), 
                           selected = 2, inline = TRUE)
            )
          )
        )
      )
    )
  )
)

# Credentials for shinymanager
env_pass <- Sys.getenv("RGWCHART_PASSWORD")
if (env_pass == "") {
  env_pass <- "password"
}
credentials <- data.frame(
  user = c("viewer"),
  password = c(scrypt::hashPassword(env_pass)),
  is_hashed_password = TRUE,
  stringsAsFactors = FALSE
)

ui <- secure_app(ui)

server <- function(input, output, session) {
  
  res_auth <- secure_server(
    check_credentials = check_credentials(credentials)
  )
  
  # Reactive registry of loaded files
  files_registry <- reactiveVal(list())
  file_counter <- reactiveVal(0)
  
  # Parse and append uploaded files with unique ID generation
  observeEvent(input$files, {
    req(input$files)
    withProgress(message = 'Parsing listing files...', value = 0, {
      n_files <- nrow(input$files)
      new_registry_entries <- list()
      counter <- file_counter()
      
      for (i in seq_len(n_files)) {
        path <- input$files$datapath[i]
        orig_name <- input$files$name[i]
        
        counter <- counter + 1
        file_id <- paste0("file_", counter)
        
        incProgress(1 / n_files, detail = orig_name)
        
        parsed_df <- tryCatch({
          get_lst(path)
        }, error = function(e) {
          showNotification(paste("Error reading file:", orig_name, "\nDetail:", e$message), 
                           type = "error", duration = NULL)
          NULL
        })
        
        if (!is.null(parsed_df)) {
          # Formulate a default alias. Check if we already have files with this name and append a count
          existing_count <- sum(purrr::map_chr(files_registry(), ~ .x$filename) == orig_name)
          default_alias <- if (existing_count > 0) {
            paste0(orig_name, " (", existing_count + 1, ")")
          } else {
            orig_name
          }
          
          new_registry_entries[[length(new_registry_entries) + 1]] <- list(
            id = file_id,
            filename = orig_name,
            data = parsed_df,
            default_alias = default_alias
          )
        }
      }
      
      file_counter(counter)
      
      if (length(new_registry_entries) > 0) {
        current_registry <- files_registry()
        files_registry(append(current_registry, new_registry_entries))
      }
    })
  })
  
  # Clear all files action
  observeEvent(input$clear_files, {
    files_registry(list())
    file_counter(0)
  })
  
  # Observe dynamic file-specific remove buttons
  observe({
    registry <- files_registry()
    req(registry)
    
    for (f in registry) {
      button_id <- paste0("remove_", f$id)
      if (!is.null(input[[button_id]]) && input[[button_id]] > 0) {
        isolate({
          updated_registry <- purrr::discard(files_registry(), ~ .x$id == f$id)
          files_registry(updated_registry)
        })
        break
      }
    }
  })
  
  # Render loaded files list in sidebar with alias and start date inputs
  output$loaded_files_list <- renderUI({
    registry <- files_registry()
    if (is.null(registry) || length(registry) == 0) {
      return(p("No files loaded yet. Click Browse to upload.", style = "color: #808080; font-style: italic; margin-top: 10px; margin-bottom: 10px;"))
    }
    
    lapply(registry, function(f) {
      # Render text inputs and date inputs initialized with defaults
      tags$div(
        style = "border: 1px solid #3d3d3d; padding: 12px; border-radius: 8px; margin-bottom: 12px; background-color: #222; position: relative;",
        
        p(f$filename, style = "font-weight: bold; font-family: monospace; font-size: 0.85rem; margin-bottom: 8px; color: #0d6efd; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; padding-right: 60px;"),
        
        tags$div(
          style = "position: absolute; top: 8px; right: 8px;",
          actionButton(paste0("remove_", f$id), "Remove", class = "btn-outline-danger btn-sm", style = "font-size: 0.75rem; padding: 2px 6px;")
        ),
        
        textInput(paste0("alias_", f$id), label = "Alias", value = f$default_alias, width = "100%"),
        dateInput(paste0("start_date_", f$id), label = "Start Date", value = as.Date("2019-06-01"), width = "100%")
      )
    })
  })
  
  # Process and combine all registry files into a single dataframe
  df <- reactive({
    registry <- files_registry()
    req(registry)
    if (length(registry) == 0) return(NULL)
    
    purrr::map_dfr(registry, function(f) {
      # Get current alias value from input, default to f$default_alias
      alias_val <- input[[paste0("alias_", f$id)]]
      if (is.null(alias_val)) alias_val <- f$default_alias
      
      # Get current start date value from input, default to 2019-06-01
      start_date_val <- input[[paste0("start_date_", f$id)]]
      if (is.null(start_date_val)) start_date_val <- as.Date("2019-06-01")
      
      f$data %>%
        mutate(
          file = f$id,
          filename = f$filename,
          alias = alias_val,
          file_start_date = start_date_val
        )
    })
  })
  
  # Pivot longer and create labels
  df_long <- reactive({
    req(df())
    df() %>% 
      pivot_longer(cols = c(-kper, -kstp, -totim, -time_kstp, -time, -file, -filename, -alias, -file_start_date, -type_incr_cum)) %>%
      mutate(file2 = alias)
  })
  
  # Filter out terms that only have zero values across the dataset
  remove_flag <- reactive({
    req(df_long())
    df_long() %>% 
      group_by(name, file, file2) %>% 
      summarise(value_min = min(value, na.rm = TRUE),
                value_max = max(value, na.rm = TRUE), 
                .groups = 'drop') %>% 
      mutate(remove = ifelse((value_min == 0) & (value_max == 0), 0, 1))
  })
  
  df_long2 <- reactive({
    req(df_long(), remove_flag())
    left_join(df_long(), remove_flag(), by = c("name", "file", "file2")) %>% 
      filter(remove == 1)
  })
  
  df_filt <- reactive({
    req(df_long2(), df_types_sel())
    df_long2() %>% 
      filter(name %in% df_types_sel(),
             type_incr_cum == input$incr_cum) %>% 
      mutate(value = ifelse(name != "PERCENT_DISCREPANCY",
                            value * as.numeric(input$radio_unit) * input$mult,
                            value),
             time_date = as_datetime(file_start_date + duration(totim, "days")))
  })

  df_filt2 <- reactive({
    req(df_filt())
    if (input$radio_time_unit == "date") {
      df_filt() %>% mutate(time2 = time_date)
    } else if (input$radio_time_unit == "days") {
      df_filt() %>% mutate(time2 = totim)
    } else if (input$radio_time_unit == "SP") {
      df_filt() %>% mutate(time2 = kper)
    }
  })
  
  # Data for downloading
  df_print <- reactive({
    req(df_long(), df_filt())
    if (input$radio_download_what == 1) {
      df_p <- df_long()
      if (input$radio_download_unit == 2) {
        df_p <- df_p %>% 
          mutate(value = ifelse(name != "PERCENT_DISCREPANCY",
                                value * as.numeric(input$radio_unit),
                                value))
      }
      if (input$radio_download_long_wide == 2) {
        df_p <- df_p %>% pivot_wider(names_from = name, values_from = value)
      }
      df_p
    } else {
      df_p <- df_filt()
      if (input$radio_download_long_wide == 2) {
        df_p <- df_p %>% pivot_wider(names_from = name, values_from = value)
      }
      df_p
    }
  })
  
  # Categorize budget terms (IN, OUT, other)
  df_types <- reactive({
    req(df_long2())
    df_long2() %>% 
      distinct(name) %>% 
      mutate(type2 = case_when(str_detect(name, "_IN$")  ~ "IN", 
                               str_detect(name, "_OUT$") ~ "OUT",
                               TRUE ~ "other"))
  })
  
  df_types_in <- reactive({
    req(df_types())
    df_types() %>% filter(type2 == "IN") %>% pull(name)
  })
  
  # Update selection choices when a file is added/removed, preserving current selections
  observeEvent(files_registry(), {
    registry <- files_registry()
    if (length(registry) == 0) {
      updateCheckboxGroupInput(session, "terms_in", choices = character(0), selected = character(0))
      updateCheckboxGroupInput(session, "terms_out", choices = character(0), selected = character(0))
      updateCheckboxGroupInput(session, "terms_other", choices = character(0), selected = character(0))
      return()
    }
    
    # Evaluate choices
    in_choices <- df_types_in()
    out_choices <- df_types_out()
    other_choices <- df_types_other()
    
    # Preserve current selections if they still exist in the new choices
    current_in <- input$terms_in
    current_out <- input$terms_out
    current_other <- input$terms_other
    
    new_selected_in <- intersect(current_in, in_choices)
    new_selected_out <- intersect(current_out, out_choices)
    new_selected_other <- intersect(current_other, other_choices)
    
    updateCheckboxGroupInput(session, "terms_in", choices = in_choices, selected = new_selected_in)
    updateCheckboxGroupInput(session, "terms_out", choices = out_choices, selected = new_selected_out)
    updateCheckboxGroupInput(session, "terms_other", choices = other_choices, selected = new_selected_other)
  }, ignoreNULL = FALSE)
  
  df_types_out <- reactive({
    req(df_types())
    df_types() %>% filter(type2 == "OUT") %>% pull(name)
  })
  
  df_types_other <- reactive({
    req(df_types())
    df_types() %>% filter(type2 == "other") %>% pull(name)
  })
  
  df_types_sel <- reactive({
    c(input$terms_in, input$terms_out, input$terms_other)
  })
  
  # Select All Terms Action
  observeEvent(input$select_all_terms, {
    req(df())
    updateCheckboxGroupInput(session, "terms_in", selected = df_types_in())
    updateCheckboxGroupInput(session, "terms_out", selected = df_types_out())
    updateCheckboxGroupInput(session, "terms_other", selected = df_types_other())
  })
  
  # Unselect All Terms Action
  observeEvent(input$unselect_all_terms, {
    req(df())
    updateCheckboxGroupInput(session, "terms_in", selected = character(0))
    updateCheckboxGroupInput(session, "terms_out", selected = character(0))
    updateCheckboxGroupInput(session, "terms_other", selected = character(0))
  })
  
  # Output Table
  output$table <- DT::renderDataTable({
    registry <- files_registry()
    if (is.null(registry) || length(registry) == 0) {
      return(NULL)
    }
    req(df_filt())
    DT::datatable(df_filt(), options = list(pageLength = 10, scrollX = TRUE))
  })

  # Output Chart
  output$chart <- renderPlotly({
    registry <- files_registry()
    if (is.null(registry) || length(registry) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
             layout(title = list(text = "Please upload one or more MODFLOW listing files in the sidebar on the left", y = 0.5)))
    }
    
    if (length(df_types_sel()) == 0) {
      return(plotly_empty(type = "scatter", mode = "markers") %>%
             layout(title = list(text = "Please select at least one budget term in the sidebar on the right", y = 0.5)))
    }
    
    req(df_filt2())
    p <- df_filt2() %>% 
      ggplot(aes(x = time2, y = value))
      
    if (length(df_types_sel()) == 1) {
      # Comparing single term across different files
      p <- p + geom_line(aes(col = file2), linewidth = 0.8)
    } else {
      # Comparing multiple terms, facet by file
      p <- p + geom_line(aes(col = name), linewidth = 0.8) + facet_wrap(~file2, ncol = 1)
    }
    
    if (input$include_zero == 1) {
      p <- p + expand_limits(y = 0)
    }
    
    # Styled theme to match darkly theme
    p <- p + labs(x = isolate(input$radio_time_unit), y = "Value", col = "Legend") +
      theme_minimal() +
      theme(
        plot.background = element_rect(fill = "#1e1e1e", color = NA),
        panel.background = element_rect(fill = "#1e1e1e", color = NA),
        text = element_text(color = "#e0e0e0"),
        axis.text = element_text(color = "#b0b0b0"),
        panel.grid.major = element_line(color = "#2d2d2d"),
        panel.grid.minor = element_line(color = "#252525"),
        legend.background = element_rect(fill = "#1e1e1e", color = NA),
        legend.text = element_text(color = "#e0e0e0")
      )
         
    ggplotly(p, dynamicTicks = TRUE) %>%
      layout(
        plot_bgcolor = "#1e1e1e",
        paper_bgcolor = "#1e1e1e"
      )
  })
  
  # Download handler
  output$download_data <- downloadHandler(
    filename = function() {
      paste("data-", Sys.Date(), ".csv", sep="")
    },
    content = function(file) {
      write_excel_csv(df_print(), file)
    }
  )
}

# Run the application 
shinyApp(ui = ui, server = server)
