library(tidyverse)
library(RSQLite)
library(lubridate)
library(shiny)
library(shinythemes)
library(plotly)

# set this file equal to db file created from create_db.py
db.file <- 'data.db'

# sqlite db connection
getdf.sqlite <- function(query) {
  conn <- dbConnect(
    SQLite(),
    db.file)
  df <- dbGetQuery(conn, query)
  dbDisconnect(conn)
  df
}

# Common mutations for various time computations
dfmutate <- function(df) {
  df %>%
    mutate(
      timepoint = as_datetime(timepoint),
      temp = as.numeric(temp),
      ymddate = date(timepoint),
      week.start = floor_date(timepoint, "weeks", week_start = 7),
      wday.label = wday(timepoint, label = T),
      hour = hour(timepoint),
      day = day(timepoint),
      week = week(timepoint),
      ymdinput = as_date(timepoint))
}

# Query Variables
dbquery <- "SELECT 
	      E.id,
	      E.timepoint,
	      E.cost,
	      E.kwh,
	      E.temp,
	      B.id AS billperiod
      FROM billperiods B
      INNER JOIN electricity E
	    ON B.startdate <= E.timepoint AND B.enddate >= E.timepoint
          ;"
datequery <- "SELECT DISTINCT DATE(timepoint) AS DayMonth FROM electricity ORDER BY DayMonth ASC"
billperiodquery <- "SELECT * FROM billperiods"

# Tables to display prior to DB download
billperioddf <- getdf.sqlite(billperiodquery)
daterange <- getdf.sqlite(datequery)

# App Code Start
ui <- fluidPage(
  # setting top bar and theme
  tags$style(type="text/css", "body {padding-top: 70px;}"),
  theme = shinytheme("cerulean"),
  navbarPage("Power Use Analysis", position = "fixed-top"),

  # Row for DB Downlaod button
  fluidRow(
    column(12, actionButton("getdata", "Load DB Data", class = "btn-lg btn-success")
  )),
  
  # Row for various input selections
  fluidRow(
    column(4,
      dateRangeInput(
        "daterangein", 
        "Select Date Range for Daily Graph",
        start = min(daterange$DayMonth),
        end = max(daterange$DayMonth),
        min = min(daterange$DayMonth),
        max = max(daterange$DayMonth))
    ),
    column(4,
      tableOutput("computedtbl")
    ),
    column(4, 
      selectInput("y", "Y Axis for Weekday Graphs", c("cost", "kwh"))
    )
  ),
    # Tabs for various graphs
    tabsetPanel(
    tabPanel("Daily Graph",
      fluidRow(
        plotlyOutput("dailygraph")
      )
    ),
    tabPanel("Weekday Bar Graph",
      fluidRow(
        plotlyOutput("dailybar")
      )
    ),
    tabPanel("Weekday Boxplot",
      fluidRow(
        plotlyOutput("boxplot")
      )
    ),
    tabPanel("Weekday Violin",
      fluidRow(
        plotlyOutput("violin")
      )
    ),
    tabPanel("kWh Rate",
      fluidRow(
        plotlyOutput("kWhrate")
      )
    ),
    tabPanel("Hourly Use",
      fluidRow(
        column(6, selectInput("yhourly", "Y axis", c("cost", "kwh", "temp"))),
        column(6, selectInput("daysplit", "Grouping", c("ymddate", "week.start", "billperiod")))
        ),
      fluidRow(plotlyOutput("hourlyplot"))
    )
  ),
  # Bottom row for tables
  fluidRow(
    column(6,
      tableOutput("billsummarytbl")
    ),
    column(6,
      dataTableOutput("powerusetbl")
    )
    
  )
  )


server <- function(input, output, session) {
  
  #Master df for use with reactive graphs
  poweruse <- eventReactive(input$getdata, getdf.sqlite(dbquery) %>% dfmutate())
  
  #Date selection df for day summary graph
  selected <- reactive(poweruse() %>% filter(ymdinput >= input$daterangein[1] & ymdinput <= input$daterangein[2]))
  
  # daily linegraph
  output$dailygraph <- renderPlotly({
    dfgraph <- selected() %>% 
      group_by(ymddate) %>% 
      summarise(
        cost = sum(cost),
        kwh = sum(kwh),
        high = max(temp),
        low = min(temp))

    plot_ly(dfgraph, x = ~ymddate) %>% 
      add_trace(y = ~high, name = "High", type = "scatter", mode = "lines+markers") %>% 
      add_trace(y = ~low, name = "Low", type = "scatter", mode = "lines+markers") %>% 
      add_bars(y = ~kwh, name = "kWh") %>% 
      add_trace(y = ~cost, name = "Cost", type = "scatter", mode = "markers") %>% 
      layout(
        hovermode = "x unified",
        title = list(text = "Daily Values"))
  })
  
  # daily bargraph
  output$dailybar <- renderPlotly({
    dfgraph <- poweruse() %>%
      arrange(week.start) %>%
      group_by(wday.label, day, week.start) %>%
      summarise(cost = sum(cost), kwh = sum(kwh))

    plot_ly(dfgraph, x = ~wday.label, y = ~get(input$y), type = "bar", color = ~ordered(week.start)) %>% 
      layout(
        title = list(
          text = "Amount per Day per Week"
        ),
        legend = list(
          traceorder = "reversed",
          title = list(text = "<b> Week of </b>")
        )
      )
  })
  
  # day of the week boxplot
  output$boxplot <- renderPlotly({
    dfgraph <- poweruse() %>% 
      group_by(wday.label, week.start, ymddate) %>% 
      summarise(cost = sum(cost), kwh = sum(kwh))

    plot_ly(dfgraph, x = ~wday.label, y = ~get(input$y)) %>% 
      add_boxplot(
        color = ~week.start,
        jitter = 0.4,
        boxpoints = "all",
        hovertext = ~paste0(month(ymddate), "/", day(ymddate), sep = ""),
        boxmean = T
      )
        
      
  })
  
  # day of the week violin plot
  output$violin <- renderPlotly({
    dfgraph <- poweruse() %>% 
      group_by(wday.label, week.start, ymddate) %>% 
      summarise(cost = sum(cost), kwh = sum(kwh))
    
    plot_ly(
      dfgraph,
      x = ~wday.label,
      y = ~get(input$y),
      split = ~wday.label,
      type = "violin",
      points = "all",
      box = list(
        visible = T
      ),
      meanline = list(
        visible = T
      )
    ) %>% 
    layout(
      legend = list(
        traceorder = "reversed"
      )
    )
  })
  
  # kwh rate line graph
  output$kWhrate <- renderPlotly({
    poweruse() %>% 
      mutate(kwrate = cost / kwh) %>% 
      plot_ly(x = ~timepoint) %>% 
      add_trace(y = ~kwrate, type = "scatter", mode = "lines+markers", color = ~ordered(billperiod)) %>%
      layout(
        legend = list(
          traceorder = "reversed"
        )
      )
  })
  
  # line graph by hour of the day
  output$hourlyplot <- renderPlotly({
    poweruse() %>% 
      plot_ly(
        x = ~hour,
        y = ~get(input$yhourly),
        type = "scatter",
        mode = "lines",
        split = ~ymddate
        )

  })
  
  # bill summary table at bottom of screen
  output$billsummarytbl <- renderTable({
    billperioddf %>% 
      mutate(period = id) %>% 
      select(
        period,
        startdate,
        enddate,
        billamount,
        servicecost,
        kwh
      )
      
  })
  
  # computed costs for selected date range at top center of screen
  output$computedtbl <- renderTable({
    selected() %>% 
      summarise(
        `Calculated Cost` = sum(cost),
        `Calculated kWh` = sum(kwh)
      )
  })
  
  # full data table with all electricity data at bottom right of screen
  output$powerusetbl <- renderDataTable(poweruse() %>% select(timepoint:billperiod, wday.label), options = list(pageLength = 10))

  }

shinyApp(ui, server)

