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

# --- Shared visual identity (keep in sync with ../RGWheads_oct-quad) ---------
# Both RGW apps use the SAME vapor base + palette + CSS so they are (a) vivid,
# matching the Crayfisher website's "vapor" theme, and (b) identical to each
# other.
CF_PRIMARY   <- "#00bc8c" # teal-green (site h1/h2 + buttons)
CF_ACCENT    <- "#32fbe2" # neon-teal (hover / highlight)
CF_SECONDARY <- "#6f42c1" # vapor purple
CF_BG        <- "#1a0933" # deep purple page background (vapor)
CF_PANEL     <- "#241046" # card / plot panel
CF_FG        <- "#ece7f7" # light lavender text
CF_MUTED     <- "#a99fce" # muted lavender (secondary text)
app_theme <- bs_theme(
  bootswatch = "vapor",
  primary = CF_PRIMARY,
  secondary = CF_SECONDARY,
  success = CF_PRIMARY,
  info = CF_ACCENT,
  base_font = font_google("Inter"),
  heading_font = font_google("Outfit"),
  bg = CF_BG,
  fg = CF_FG
)

# Shared CSS (identical to RGWheads) + a few RGWchart-specific extras appended.
custom_css <- "
  body { background: radial-gradient(circle at 20% 0%, #2a0f52 0%, #1a0933 55%) !important; }
  /* bslib's page-sidebar title bar derives its background + text colour from
     these two CSS vars; vapor sets them to pink bg / dark text. Pin both to the
     dark palette so the top bar is dark navy with readable teal text. */
  :root { --bslib-page-sidebar-title-bg: #150726 !important; --bslib-page-sidebar-title-color: #00bc8c !important; }
  .navbar, .bslib-page-sidebar > .navbar { background-color: #150726 !important; background-image: none !important; color: #00bc8c !important; border-bottom: 1px solid rgba(50,251,226,0.18) !important; box-shadow: none !important; position: relative; }
  .navbar .bslib-page-title { color: #00bc8c !important; font-weight: 700; }
  .navbar-brand { color: #00bc8c !important; font-weight: 700 !important; letter-spacing: 0.3px; text-shadow: 0 0 12px rgba(0,188,140,0.45); }
  /* Back-to-site link pinned to the right of the top bar; explicit bright colour
     so it's readable at rest (outline-info rendered too dark on the dark bar). */
  .app-back-btn { position: absolute !important; right: 16px; top: 50%; transform: translateY(-50%); z-index: 5; color: #32fbe2 !important; border-color: #32fbe2 !important; background: rgba(50,251,226,0.08) !important; }
  .app-back-btn:hover { background: #32fbe2 !important; color: #150726 !important; box-shadow: 0 0 14px rgba(50,251,226,0.5) !important; }
  h1, h2, h3, h4 { color: #00bc8c; }
  .card {
    background: #241046 !important;
    border: 1px solid rgba(255,255,255,0.08) !important;
    border-radius: 14px !important;
    box-shadow: 0 8px 26px rgba(0,0,0,0.4) !important;
    transition: border-color 0.3s ease, box-shadow 0.3s ease;
  }
  .card:hover { border-color: #32fbe2 !important; box-shadow: 0 14px 30px rgba(50,251,226,0.18) !important; }
  .card-header { background: rgba(0,0,0,0.25) !important; border-bottom: 1px solid rgba(255,255,255,0.08) !important; color: #00bc8c !important; font-weight: 600 !important; }
  .sidebar { background: #150726 !important; border-right: 1px solid rgba(50,251,226,0.12) !important; }
  .accordion-button { background: #241046 !important; color: #ece7f7 !important; }
  .accordion-button:not(.collapsed) { background: #2d1657 !important; color: #00bc8c !important; box-shadow: inset 3px 0 0 #00bc8c; }
  .value-box { border-radius: 14px !important; border: 1px solid rgba(255,255,255,0.08) !important; }
  /* Buttons: pill shape + neon hover glow, matching the website cards. */
  .btn { border-radius: 30px !important; font-weight: 600 !important; transition: all 0.2s ease; }
  .btn-primary, .btn-success { background: #00bc8c !important; border: 1px solid #00bc8c !important; color: #04130e !important; }
  .btn-primary:hover, .btn-success:hover, .btn-info:hover { box-shadow: 0 0 16px rgba(0,188,140,0.55) !important; transform: translateY(-1px); }
  .btn-info { color: #04130e !important; }
  .btn-secondary { color: #ece7f7 !important; }
  /* Outline buttons (e.g. Remove): keep text visible on the dark bg, not only on hover. */
  .btn-danger { color: #fff !important; }
  .btn-outline-danger { color: #ff7088 !important; border-color: #ff7088 !important; }
  .btn-outline-danger:hover { background: #ff7088 !important; color: #1a0933 !important; }
  .form-control, .form-select, .selectize-input, .selectize-dropdown { background: rgba(0,0,0,0.25) !important; border-color: rgba(255,255,255,0.12) !important; color: #ece7f7 !important; }
  a { color: #00bc8c; }
  a:hover { color: #32fbe2; }
  /* --- RGWchart-specific --- */
  .accordion-item { background: #241046 !important; border: 1px solid rgba(255,255,255,0.08) !important; border-radius: 10px !important; }
  .sidebar-right-header { display: flex; justify-content: space-between; margin-bottom: 15px; border-bottom: 1px solid rgba(255,255,255,0.12); padding-bottom: 8px; }
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track { background: #150726; }
  ::-webkit-scrollbar-thumb { background: #3a2560; border-radius: 4px; }
  ::-webkit-scrollbar-thumb:hover { background: #4a3070; }
"

ui <- page_sidebar(
  # Compile custom CSS into the theme so it reliably lands in <head>.
  theme = bs_add_rules(app_theme, custom_css),
  title = tagList(
    "R GW Chart - MODFLOW budget viewer",
    tags$a("← crayfisher.com", href = "https://crayfisher.com",
           class = "btn btn-outline-info btn-sm app-back-btn")
  ),
  
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
    
    hr(style = "border-color: rgba(255,255,255,0.12);"),
              
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
      hr(style = "border-color: rgba(255,255,255,0.12);"),
      checkboxGroupInput("terms_out", "Terms OUT", choices = ""),
      hr(style = "border-color: rgba(255,255,255,0.12);"),
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
          hr(style = "border-color: rgba(255,255,255,0.12); margin-top: 20px; margin-bottom: 20px;"),
          
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

# --- Login gate (disabled) --------------------------------------------------
# Login is intentionally disabled to make the app publicly accessible (linked
# from the Crayfisher website), matching RGWheads. Bot/abuse protection is
# handled at the edge via Cloudflare. To re-enable the shinymanager gate,
# uncomment the line below and the matching `secure_server(...)` block.
# ui <- secure_app(ui)

server <- function(input, output, session) {

  # res_auth <- secure_server(
  #   check_credentials = check_credentials(credentials)
  # )
  
  # Reactive registry of loaded files
  files_registry <- reactiveVal(list())
  file_counter <- reactiveVal(0)
  
  # Parse and append uploaded files with unique ID generation
  observeEvent(input$files, {
    req(input$files)
    # Server-side type check: `accept=` is only a client hint, and this app is
    # public (no login), so reject anything that isn't a listing-file extension
    # and skip empty files before parsing.
    allowed_ext <- c("lst", "list", "txt", "out")
    exts <- tolower(tools::file_ext(input$files$name))
    bad <- input$files$name[!(exts %in% allowed_ext) |
                              is.na(input$files$size) | input$files$size <= 0]
    if (length(bad) > 0) {
      showNotification(
        paste0("Rejected (allowed: .lst .list .txt .out): ",
               paste(bad, collapse = ", ")),
        type = "error", duration = NULL)
      req(FALSE)
    }
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
        style = "border: 1px solid rgba(255,255,255,0.12); padding: 12px; border-radius: 8px; margin-bottom: 12px; background-color: #241046; position: relative;",
        
        p(f$filename, style = "font-weight: bold; font-family: monospace; font-size: 0.85rem; margin-bottom: 8px; color: #00bc8c; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; padding-right: 60px;"),
        
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
    # Empty-state placeholder styled to the dark theme (plotly_empty defaults to a
    # white paper/plot background, which flashed as an ugly white box pre-load).
    empty_plot <- function(msg) {
      plotly_empty(type = "scatter", mode = "markers") %>%
        layout(
          title = list(text = msg, y = 0.5, font = list(color = "#a99fce")),
          plot_bgcolor = "#241046",
          paper_bgcolor = "#241046",
          font = list(color = "#ece7f7")
        )
    }
    registry <- files_registry()
    if (is.null(registry) || length(registry) == 0) {
      return(empty_plot("Please upload one or more MODFLOW listing files in the sidebar on the left"))
    }

    if (length(df_types_sel()) == 0) {
      return(empty_plot("Please select at least one budget term in the sidebar on the right"))
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
    
    # Styled theme to match the shared Crayfisher (vapor) palette.
    p <- p + labs(x = isolate(input$radio_time_unit), y = "Value", col = "Legend") +
      theme_minimal(base_family = "Inter") +
      theme(
        plot.background = element_rect(fill = "#241046", color = NA),
        panel.background = element_rect(fill = "#241046", color = NA),
        text = element_text(color = "#ece7f7"),
        axis.text = element_text(color = "#a99fce"),
        panel.grid.major = element_line(color = "#3a2560"),
        panel.grid.minor = element_line(color = "#2d1657"),
        legend.background = element_rect(fill = "#241046", color = NA),
        legend.text = element_text(color = "#ece7f7")
      )

    ggplotly(p, dynamicTicks = TRUE) %>%
      layout(
        plot_bgcolor = "#241046",
        paper_bgcolor = "#241046",
        font = list(color = "#ece7f7")
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
