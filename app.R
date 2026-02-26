#
# This is a shiny app for reading modflow listing files
#created by Pawel Rakowski
# sept 2020

#


library(reticulate)

# virtualenv_create(envname = "python_environment", python= "python3")
# virtualenv_remove(envname = "python_environment", packages = "pip")
# virtualenv_install("python_environment", packages = c('pip'))
# virtualenv_install("python_environment", packages = c('pandas', 'flopy'))
# reticulate::use_virtualenv("python_environment", required = TRUE)


library(shiny)
library(plotly)
library(DT)
library(tidyverse)
library(lubridate)


source("scripts/flopy_r.R")
# Define UI for application 
#file size up to 1000MB
options(shiny.maxRequestSize = 1000*1024^2)

fun_get_lst_multi <- function(fn,i){get_lst(fn) %>%
        mutate(file = fn,
               index = i)}

ui <- fluidPage(
    uiOutput('page_content')
)


server <- function(input, output, session) {
    output$page_content <- renderUI({
            tagList(
                titlePanel("R GW chart"),
                sidebarLayout(
                    sidebarPanel(
                      radioButtons("incr_cum", label = "Rate/Cumulative",
                                   choices = list("Rate" = "incr",
                                                  "Cumulative" = "cum"), 
                                   selected = "incr"),
                      radioButtons("include_zero", label = "Include zero?",
                                   choices = list("yes" = 1,
                                                  "no" = 0), 
                                   selected = 1),
                      # radioButtons("radio", label = "Input type",
                      #                choices = list("Single file" = 1,
                      #                               "Up to 3 files" = 2,
                      #                               "Upload file with addressess" = 3), 
                      #                selected = 1),
                      radioButtons("radio_unit", label = "units",
                                     choiceNames = c("m3/d","L/s","GL/a"),
                                     choiceValues	= c(1,0.011574074,0.0003650000), 
                                     selected = 1),
                      #multiplier
                      numericInput("mult",
                                   label = "Muliplier (e.g. cross-sectional models etc)",
                                   value = 1),
                      radioButtons("radio_time_unit", label = "time units",
                                   choiceNames = c("days","date", "SP"),
                                   choiceValues	= c("days","date","SP"), 
                                   selected = "days"),
                      dateInput(inputId = "start_date",
                                label = "start time",
                                value = "2019-06-01",
                                weekstart = 1),
                      fileInput("file1",
                                  label = NULL),
                      fileInput("file2",
                                  label = NULL),
                      fileInput("file3",
                                  label = NULL),
                      fileInput("file4",
                                label = NULL),
                      fileInput("file5",
                                label = NULL),
                      fileInput("file6",
                                label = NULL),
                      checkboxGroupInput("terms_in",
                                           label = "Terms IN",
                                           choices = ""),
                      checkboxGroupInput("terms_out",
                                           label = "Terms OUT"),
                      checkboxGroupInput("terms_other",
                                           label = "Terms other",
                                           choices = ""),
                    ),
                    mainPanel(
                        plotlyOutput('chart'),
                        dataTableOutput("table"),
                        downloadButton("download_data", label = "Download Data"),
                        radioButtons("radio_download_long_wide", label = h4("Data format"),
                                     choices = list("Long format" = 1, "Wide Format (for excel etc)" = 2), 
                                     selected = 1,
                                     inline = T),
                        radioButtons("radio_download_what", label = h4("Which data"),
                                     choices = list("All Data" = 1, "Selected Data" = 2), 
                                     selected = 2,
                                     inline = T),
                        conditionalPanel(condition = "input.radio_download_what == 1",
                                         radioButtons("radio_download_unit", label = h4("Which units"),
                                                      choices = list("original units" = 1, "selected Units" = 2), 
                                                      selected = 2,
                                                      inline = T))
                    )
                )  
            )})
    
    
    # output$value <- renderPrint({
    #     str(input_files())
    # })
    
    #######
    #prepare data
    input_files <- reactive({
        c(input$file1$datapath,
          input$file2$datapath,
          input$file3$datapath,
          input$file4$datapath,
          input$file5$datapath,
          input$file6$datapath)
        
        #files_sel <- files_sel[!is.null(files_sel)]
        
    })
    df <- reactive({
        imap_dfr(input_files(),fun_get_lst_multi)
        #get_lst(input$file$datapath) 
        })
    #as.numeric(unlist(switch(input$radio_unit,1,0.011574074,0.0003650000)))
    #unit_conv_fact <- reactive({ })#m3/d,L/s,GL/a
    df_long <- reactive({df()%>% 
            pivot_longer(   cols =c(-kper:-time,-file,-index,-type_incr_cum)) %>% 
            mutate(file2 = str_glue("file {index}")) })
            #pivot_longer(   cols =c(-kper:-time))})
    #this is to filter out terms that only have zero values (e.g. rech_out)
    remove_flag <- reactive({
        df_long() %>% 
        group_by(name,file,file2,index) %>% 
        summarise(value_min = min(value),
                  value_max = max(value)) %>% 
        mutate( remove = ifelse((value_min == 0) & (value_max == 0),
                                0,1))
    })
    
    df_long2 <- reactive({
        left_join(df_long(),remove_flag()) %>% 
        filter(remove == 1)
    })
    
    df_filt <- reactive({df_long2() %>% 
        filter(name %in% df_types_sel(),
               type_incr_cum == input$incr_cum) %>% 
        mutate(value = ifelse(name != "PERCENT_DISCREPANCY",
                              value * as.numeric(input$radio_unit)*input$mult,
                              value),
               time_date = as_datetime(input$start_date + duration(totim,"days")))})

    df_filt2 <- reactive({
      if(input$radio_time_unit == "date"){
        df_filt() %>% 
          mutate(time2 = time_date )
      }else if (input$radio_time_unit == "days"){
        df_filt() %>% 
          mutate(time2 = totim )
      }else if (input$radio_time_unit == "SP"){
        df_filt() %>% 
          mutate(time2 = kper )
      }
     
        
        
      
    })
    #attempting to set plot limits to include zero
    #doesnt work for sime reason
    #ymax <- reactive({max(max(df_filt()$value),0)})
    #ymin <- reactive({min(min(df_filt()$value),0)})
    
    df_print <- reactive({
      if (input$radio_download_what == 1){
        if(input$radio_download_unit == 1){
          df_print <- df_long()
        }else{
          df_print <- df_long() %>% 
            mutate(value = ifelse(name != "PERCENT_DISCREPANCY",
                                  value * as.numeric(input$radio_unit),
                                  value))
        }
        if(input$radio_download_long_wide == 2){
          df_print <- df_print %>% pivot_wider()
        }
        
      }else{
        df_print <- df_filt()
        if(input$radio_download_long_wide == 2){
          df_print <- df_print %>% pivot_wider()
        }
      }
      
    })
    
    df_types <- reactive({df_long2() %>% 
            distinct(name) %>% 
            mutate(type2 = case_when(str_detect(name,"_IN$")  ~ "IN", 
                                     str_detect(name,"_OUT$")  ~ "OUT",
                                     TRUE ~ "other"))
            })
    
    # df_types_all <- reactive({c(df_types_in(),
    #                             df_types_out(),
    #                             df_types_other())})
    df_types_sel <- reactive({c(input$terms_in,
                      input$terms_out,
                      input$terms_other)})
    
    df_types_in <- reactive({df_types() %>% 
            filter(type2 == "IN") %>% 
            pull(name)})
    
    df_types_out <- reactive({df_types() %>% 
            filter(type2 == "OUT") %>% 
            pull(name)})
    df_types_other <- reactive({df_types() %>% 
            filter(type2 == "other") %>% 
            pull(name)})
        

    
    #update input for names
    observe({
        req(input$file1)
        updateCheckboxGroupInput(session, "terms_in",choices = df_types_in())
        updateCheckboxGroupInput(session, "terms_out",choices = df_types_out())
        updateCheckboxGroupInput(session, "terms_other",choices = df_types_other())
        })
    
    
    ###########
    #oputputs
    output$table <- renderDataTable({
      df_filt()
    })

      output$chart <- renderPlotly({
          req(input$file1)
          if(length(df_types_sel()) == 1){
            if(input$include_zero == 1){
              chart <- df_filt2() %>% 
                ggplot(aes(time2,value,col = file2)) +
                geom_line()+
                #scale_y_continuous(limits =c(ymin(),ymax()))+ 
                expand_limits(y=0) #
              ggplotly(chart)
            }else{
              chart <- df_filt2() %>% 
                ggplot(aes(time2,value,col = file2)) +
                geom_line()
                #scale_y_continuous(limits =c(ymin(),ymax()))
              ggplotly(chart,dynamicTicks =T)
            }
            
             
                }else{
            if(input$include_zero == 1){
              chart <- df_filt2() %>% 
                ggplot(aes(time2,value,col = name)) +
                geom_line() +
                facet_wrap(~file2,ncol =1)+
                expand_limits(y=0)
              ggplotly(chart)
            }else{
              chart <- df_filt2() %>% 
                ggplot(aes(time2,value,col = name)) +
                geom_line() +
                facet_wrap(~file2,ncol =1)
              ggplotly(chart,dynamicTicks =T)
            }
            
              }
          
      })
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
