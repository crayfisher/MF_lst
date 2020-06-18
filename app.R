#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(plotly)
library(DT)
library(tidyverse)
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




# Define server logic required to draw a histogram
server <- function(input, output, session) {
    output$page_content <- renderUI({
            tagList(
                titlePanel("R GW chart"),
                sidebarLayout(
                    sidebarPanel(
                        radioButtons("radio", label = h3("Input type"),
                                     choices = list("Single file" = 1,
                                                    "Up to 3 files" = 2,
                                                    "Upload file with addressess" = 3), 
                                     selected = 1),
                        radioButtons("radio_unit", label = h3("units"),
                                     choiceNames = c("m3/d","L/s","GL/a"),
                                     choiceValues	= c(1,0.011574074,0.0003650000), 
                                     selected = 1),
                        fileInput("file1",
                                  label = h3("File input")),
                        fileInput("file2",
                                  label = h3("File input")),
                        fileInput("file3",
                                  label = h3("File input")),
                        checkboxGroupInput("terms_in",
                                           label = h3("Terms IN"),
                                           choices = ""),
                        checkboxGroupInput("terms_out",
                                           label = h3("Terms OUT")),
                        checkboxGroupInput("terms_other",
                                           label = h3("Terms other"),
                                           choices = ""),
                    ),
                    mainPanel(
                        plotlyOutput('chart')
                    )
                )  
            )})
    
    
    output$value <- renderPrint({
        str(input_files())
    })
    
    #######
    #prepare data
    input_files <- reactive({
        c(input$file1$datapath,input$file2$datapath,input$file3$datapath)
        
        #files_sel <- files_sel[!is.null(files_sel)]
        
    })
    df <- reactive({
        imap_dfr(input_files(),fun_get_lst_multi)
        #get_lst(input$file$datapath) 
        })
    #as.numeric(unlist(switch(input$radio_unit,1,0.011574074,0.0003650000)))
    #unit_conv_fact <- reactive({ })#m3/d,L/s,GL/a
    df_long <- reactive({df()%>% 
            pivot_longer(   cols =c(-kper:-time,-file,-index)) %>% 
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
        filter(name %in% df_types_sel() ) %>% 
        mutate(value = ifelse(name != "PERCENT_DISCREPANCY",
                              value * as.numeric(input$radio_unit),
                              value))})
    
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

      output$chart <- renderPlotly({
          req(input$file1)
          if(length(df_types_sel()) == 1){
              chart <- df_filt() %>% 
                  ggplot(aes(totim,value,col = file2)) +
                  geom_line()}else{
            chart <- df_filt() %>% 
                ggplot(aes(totim,value,col = name)) +
                geom_line() +
                facet_wrap(~file2,ncol =1)
              }
          ggplotly(chart)
      })
  


}

# Run the application 
shinyApp(ui = ui, server = server)
