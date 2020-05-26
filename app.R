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
                        fileInput("file", label = h3("File input")),
                        checkboxGroupInput("terms",
                                           label = h3("terms"),
                                           choices = "")
                    ),
                    mainPanel(
                        plotlyOutput('chart'),
                        dataTableOutput('table')
                    )
                )  
            )})
    
    #######
    #prepare data
    df <- reactive({get_lst(input$file$datapath) })
    df_long <- reactive({df()%>% 
            pivot_longer(  -kper:-time)})
    df_filt <- reactive({df_long() %>% 
        filter(name %in% input$terms )})
    
    df_types <- reactive({df_long() %>% 
            distinct(name) %>% 
            pull(name)})
    
    #update input for names
    observe({
        req(input$file)
        updateCheckboxGroupInput(session, "terms",
                          choices = df_types()
        )})
    
    
    ###########
    #oputputs
    output$table <- renderDataTable({
        req(input$file)
        df_filt()})
    
    output$chart <- renderPlotly({
        req(input$file)
        chart <- df_filt() %>% 
                ggplot(aes(totim,value,col = name)) +
            geom_line()
        ggplotly(chart)
    })

}

# Run the application 
shinyApp(ui = ui, server = server)
