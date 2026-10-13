library(shiny)
library(bslib)
library(dplyr)
library(ggplot2)
library(lubridate)
library(scales)

source("R/data_prep.R")

data_path <- file.path("data", "processed", "dc_311_2025.rds")
requests <- if (file.exists(data_path)) readRDS(data_path) else NULL

theme_set(theme_minimal(base_size = 13) + theme(
  plot.title = element_text(face = "bold", color = "#15263D"),
  plot.subtitle = element_text(color = "#64748B"),
  panel.grid.minor = element_blank(),
  axis.title = element_text(color = "#475569")
))

ui <- page_sidebar(
  title = "DC 311 | Service Operations",
  theme = bs_theme(version = 5, bootswatch = "flatly", primary = "#135D66", base_font = "system-ui"),
  sidebar = sidebar(
    width = 300,
    h5("Explore the data"),
    p("Filter requests to compare workload and turnaround patterns."),
    dateRangeInput("dates", "Request date range", start = as.Date("2025-01-01"), end = as.Date("2025-12-31"), min = as.Date("2025-01-01"), max = as.Date("2025-12-31")),
    selectInput("service", "Service type", choices = "All service types"),
    selectInput("ward", "Ward", choices = "All wards"),
    hr(),
    p(class = "small text-secondary", "Requests are grouped by the date they were opened. Turnaround uses elapsed calendar days from opening to resolution.")
  ),
  div(class = "container-fluid px-1",
      p(class = "lead", "A business intelligence view of demand, service turnaround, and due-date performance across DC 311 requests opened in 2025."),
      uiOutput("data_status"),
      navset_card_tab(
        nav_panel("Overview",
          layout_column_wrap(
            value_box("Requests", textOutput("total_requests", inline = TRUE), theme = "primary"),
            value_box("Resolved", textOutput("resolved_share", inline = TRUE), theme = "success"),
            value_box("Median turnaround", textOutput("median_days", inline = TRUE), theme = "warning"),
            value_box("Met due date", textOutput("on_time_share", inline = TRUE), theme = "info"),
            width = 1/4
          ),
          layout_columns(card(card_header("Monthly request volume"), plotOutput("monthly_plot", height = 330)), card(card_header("Requests by service type"), plotOutput("service_plot", height = 330)), col_widths = c(7, 5)),
          card(card_header("How to read this dashboard"), p("Use the filters to compare demand and turnaround patterns. Due-date performance is calculated only for requests with both a due date and a resolution date. These measures describe observed patterns; they do not explain the cause of delays."))
        ),
        nav_panel("Turnaround", layout_columns(card(card_header("Typical turnaround by service type"), plotOutput("turnaround_plot", height = 480)), card(card_header("Resolution time distribution"), plotOutput("distribution_plot", height = 480)), col_widths = c(7, 5))),
        nav_panel("Ward view", layout_columns(card(card_header("Request volume by ward"), plotOutput("ward_plot", height = 440)), card(card_header("Ward summary"), tableOutput("ward_table")), col_widths = c(7, 5))),
        nav_panel("Data & definitions", card(
          h4("Source and scope"),
          p("DC 311 City Service Requests in 2025, published by the District of Columbia Office of Unified Communications."),
          p(tags$a(href = "https://catalog.data.gov/dataset/311-city-service-requests-in-2025", "Open the dataset record", target = "_blank"), " · Licensed under Creative Commons Attribution 4.0."),
          h4("Metric definitions"),
          tags$ul(
            tags$li(strong("Request volume:"), " count of records by request opening month."),
            tags$li(strong("Resolved share:"), " requests with a recorded resolution date divided by all filtered requests."),
            tags$li(strong("Turnaround:"), " calendar days between add date and resolution date; median is shown for resolved requests with nonnegative elapsed time."),
            tags$li(strong("Met due date:"), " resolved requests completed on or before the service due date, among records with both dates."),
            tags$li(strong("Ward:"), " ward recorded in the source data; blank or unavailable values are excluded from the ward chart.")
          ),
          h4("Limitations"),
          p("The dataset represents requests received through several channels and includes only fields provided by the District. Missing dates and records still open at the end of the period affect the metrics. A due date is treated as the source's operational target, not an independently validated service-level agreement. Ward comparisons are descriptive and should not be interpreted as measures of resident need or agency effort."),
          downloadButton("download_data", "Download filtered rows")
        ))
      )
  )
)

server <- function(input, output, session) {
  if (is.null(requests)) {
    output$data_status <- renderUI(div(class = "alert alert-warning", strong("Data file not found."), " Run `Rscript scripts/refresh_data.R` from the project folder, then restart the app."))
  } else {
    updateSelectInput(session, "service", choices = c("All service types", sort(unique(requests$service_type))), selected = "All service types")
    updateSelectInput(session, "ward", choices = c("All wards", sort(unique(na.omit(requests$ward)))), selected = "All wards")
    output$data_status <- renderUI(div(class = "alert alert-light border", paste("Showing", comma(nrow(requests)), "requests · Source year 2025 · Data refreshed", format(file.info(data_path)$mtime, "%b %d, %Y"))))
  }

  filtered <- reactive({
    req(!is.null(requests), input$dates)
    x <- requests |> filter(request_date >= as.Date(input$dates[1]), request_date <= as.Date(input$dates[2]))
    if (!is.null(input$service) && input$service != "All service types") x <- x |> filter(service_type == input$service)
    if (!is.null(input$ward) && input$ward != "All wards") x <- x |> filter(ward == input$ward)
    x
  })

  output$total_requests <- renderText(if (is.null(requests)) "—" else comma(nrow(filtered())))
  output$resolved_share <- renderText({ x <- filtered(); if (!nrow(x)) "—" else percent(mean(!is.na(x$resolution_date)), accuracy = 0.1) })
  output$median_days <- renderText({ x <- filtered(); d <- x$turnaround_days[!is.na(x$turnaround_days) & x$turnaround_days >= 0]; if (!length(d)) "—" else paste0(number(median(d), accuracy = 0.1), " days") })
  output$on_time_share <- renderText({ x <- filtered(); eligible <- x |> filter(!is.na(resolution_date), !is.na(due_date)); if (!nrow(eligible)) "—" else percent(mean(eligible$resolution_date <= eligible$due_date), accuracy = 0.1) })

  output$monthly_plot <- renderPlot({
    x <- filtered() |> mutate(month = floor_date(request_date, "month")) |> count(month)
    ggplot(x, aes(month, n)) + geom_col(fill = "#135D66", width = 25) + scale_y_continuous(labels = comma) + scale_x_date(date_breaks = "1 month", date_labels = "%b") + labs(x = NULL, y = "Requests", subtitle = "Count by request opening date")
  })
  output$service_plot <- renderPlot({
    x <- filtered() |> count(service_type, sort = TRUE) |> slice_head(n = 10) |> mutate(service_type = reorder(service_type, n))
    ggplot(x, aes(n, service_type)) + geom_col(fill = "#3C8D93") + scale_x_continuous(labels = comma) + labs(x = "Requests", y = NULL, subtitle = "Top 10 service types in the current selection")
  })
  output$turnaround_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(turnaround_days), turnaround_days >= 0) |> group_by(service_type) |> summarise(median_days = median(turnaround_days), requests = n(), .groups = "drop") |> filter(requests >= 10) |> slice_max(median_days, n = 15, with_ties = FALSE) |> mutate(service_type = reorder(service_type, median_days))
    ggplot(x, aes(median_days, service_type)) + geom_col(fill = "#D08C4B") + labs(x = "Median calendar days", y = NULL, subtitle = "Top 15 median turnaround times; categories need at least 10 resolved requests")
  })
  output$distribution_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(turnaround_days), turnaround_days >= 0, turnaround_days <= quantile(turnaround_days, .99, na.rm = TRUE))
    ggplot(x, aes(turnaround_days)) + geom_histogram(bins = 30, fill = "#557A95", color = "white") + scale_x_continuous(labels = label_number()) + labs(x = "Calendar days to resolution (up to 99th percentile)", y = "Requests", subtitle = "Extreme values above the 99th percentile are omitted for readability")
  })
  output$ward_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(ward), ward != "") |> count(ward, sort = TRUE)
    ggplot(x, aes(reorder(ward, n), n)) + geom_col(fill = "#135D66") + coord_flip() + scale_y_continuous(labels = comma) + labs(x = "Ward", y = "Requests", subtitle = "Counts reflect request volume, not population-adjusted rates")
  })
  output$ward_table <- renderTable({
    filtered() |> filter(!is.na(ward), ward != "") |> group_by(ward) |> summarise(Requests = n(), `Resolved share` = percent(mean(!is.na(resolution_date)), accuracy = 0.1), `Median days` = { d <- turnaround_days[!is.na(turnaround_days) & turnaround_days >= 0]; if (length(d)) round(median(d), 1) else NA_real_ }, .groups = "drop") |> arrange(ward)
  }, striped = TRUE, bordered = FALSE, spacing = "s")
  output$download_data <- downloadHandler(filename = function() paste0("dc-311-filtered-", Sys.Date(), ".csv"), content = function(file) write.csv(filtered(), file, row.names = FALSE, na = ""))
}

shinyApp(ui, server)
