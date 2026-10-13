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
            value_box("Median / P90 (days)", textOutput("turnaround_summary", inline = TRUE), theme = "warning"),
            value_box("Met due date", textOutput("on_time_share", inline = TRUE), theme = "info"),
            width = 1/2
          ),
          layout_columns(card(card_header("Monthly request volume"), plotOutput("monthly_plot", height = 330)), card(card_header("Requests by service type"), plotOutput("service_plot", height = 330)), col_widths = c(7, 5)),
          card(card_header("How to read this dashboard"), p("Use the filters to compare demand and turnaround patterns. Due-date performance is calculated only for requests with both a due date and a resolution date. These measures describe observed patterns; they do not explain the cause of delays."))
        ),
        nav_panel("Findings", card(
          h4("2025 operating picture"),
          p("These observations update with the date, service type, and ward filters. They describe this extract; they do not identify causes."),
          uiOutput("findings"),
          plotOutput("monthly_sla_plot", height = 300),
          hr(),
          h5("Suggested operational follow-up"),
          p("Start by validating the service category and due-date definitions with the owning agencies. Then review high-volume categories and the long tail of resolution times with their operational teams before proposing process changes.")
        )),
        nav_panel("Turnaround", layout_columns(card(card_header("Typical turnaround by service type"), plotOutput("turnaround_plot", height = 480)), card(card_header("Resolution time distribution"), plotOutput("distribution_plot", height = 480)), col_widths = c(7, 5))),
        nav_panel("Ward view", layout_columns(card(card_header("Request volume by ward"), plotOutput("ward_plot", height = 440)), card(card_header("Ward summary"), tableOutput("ward_table")), col_widths = c(7, 5))),
        nav_panel("Definitions", card(
          h4("Source and scope"),
          p("DC 311 City Service Requests in 2025, published by the District of Columbia Office of Unified Communications."),
          p(tags$a(href = "https://catalog.data.gov/dataset/311-city-service-requests-in-2025", "Open the dataset record", target = "_blank"), " · Licensed under Creative Commons Attribution 4.0."),
          h4("Metric definitions"),
          tags$ul(
            tags$li(strong("Request volume:"), " distinct request identifiers by opening month."),
            tags$li(strong("Resolved share:"), " requests with a recorded resolution date divided by all filtered requests."),
            tags$li(strong("Turnaround:"), " calendar days between opening and resolution; median and percentiles exclude missing or negative elapsed times."),
            tags$li(strong("Met due date:"), " resolved requests completed on or before the service due date, among records with both dates."),
            tags$li(strong("Ward:"), " ward recorded in the source data; blank or unavailable values are excluded from the ward chart."),
            tags$li(strong("Service type:"), " source service-type description. The spelling variant 'Admistration' is grouped under 'Administration'; the original label is retained in the prepared data.")
          ),
          h4("Data quality checks"),
          tags$ul(
            tags$li("440,562 unique request IDs remain after restricting opening dates to 2025."),
            tags$li("3,796 records have no resolution date; 14 have no due date; 10 have no ward."),
            tags$li("No negative calendar-day turnaround values were found."),
            tags$li("24 source service labels are grouped into 23 analysis labels after correcting one documented spelling variant.")
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
  output$turnaround_summary <- renderText({ x <- filtered(); d <- x$turnaround_days[!is.na(x$turnaround_days) & x$turnaround_days >= 0]; if (!length(d)) "—" else paste0(number(median(d), accuracy = 0.1), " / ", number(unname(quantile(d, 0.9, type = 1)), accuracy = 0.1)) })
  output$on_time_share <- renderText({ x <- filtered(); eligible <- x |> filter(!is.na(resolution_date), !is.na(due_date)); if (!nrow(eligible)) "—" else percent(mean(eligible$resolution_date <= eligible$due_date), accuracy = 0.1) })
  output$findings <- renderUI({
    x <- filtered()
    if (!nrow(x)) return(p("No requests match the current filters."))
    top_service <- x |> count(service_type, sort = TRUE, name = "requests") |> slice_head(n = 1)
    month_counts <- x |> mutate(month = floor_date(request_date, "month")) |> count(month, name = "requests")
    peak <- month_counts |> slice_max(requests, n = 1, with_ties = FALSE)
    trough <- month_counts |> slice_min(requests, n = 1, with_ties = FALSE)
    durations <- x$turnaround_days[!is.na(x$turnaround_days) & x$turnaround_days >= 0]
    due <- x |> filter(!is.na(resolution_date), !is.na(due_date))
    by_service <- x |> filter(!is.na(turnaround_days), turnaround_days >= 0) |> group_by(service_type) |> summarise(requests = n(), median_days = median(turnaround_days), p90_days = unname(quantile(turnaround_days, 0.9)), .groups = "drop") |> filter(requests >= 100) |> slice_max(median_days, n = 1, with_ties = FALSE)
    findings <- list(
      tags$li(strong("Largest service group: "), top_service$service_type, " accounts for ", comma(top_service$requests), " of ", comma(nrow(x)), " filtered requests (", percent(top_service$requests / nrow(x), accuracy = 0.1), ")."),
      tags$li(strong("Monthly demand: "), format(peak$month, "%B %Y"), " is the highest-volume month (", comma(peak$requests), "); ", format(trough$month, "%B %Y"), " is the lowest (", comma(trough$requests), "). This is a within-year comparison, not evidence of a recurring seasonal pattern."),
      if (length(durations)) tags$li(strong("Turnaround has a long tail: "), "the median is ", number(median(durations), accuracy = 0.1), " days and the 90th percentile is ", number(unname(quantile(durations, 0.9, type = 1)), accuracy = 0.1), " days."),
      if (nrow(by_service)) tags$li(strong("Longest typical turnaround: "), by_service$service_type, " has a median of ", number(by_service$median_days, accuracy = 0.1), " days across ", comma(by_service$requests), " resolved requests; only groups with at least 100 resolved requests are compared."),
      if (nrow(due)) tags$li(strong("Due-date performance: "), comma(sum(due$resolution_date <= due$due_date)), " of ", comma(nrow(due)), " eligible resolved requests (", percent(mean(due$resolution_date <= due$due_date), accuracy = 0.1), ") were resolved on or before the source due date.")
    )
    tags$ul(findings)
  })
  output$monthly_sla_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(resolution_date), !is.na(due_date)) |> mutate(month = floor_date(request_date, "month")) |> group_by(month) |> summarise(eligible = n(), on_time = sum(resolution_date <= due_date), compliance = on_time / eligible, .groups = "drop")
    ggplot(x, aes(month, compliance)) + geom_line(color = "#135D66", linewidth = 1.1) + geom_point(aes(size = eligible), color = "#D08C4B", alpha = 0.9) + scale_y_continuous(labels = label_percent(), limits = c(0, 1)) + scale_x_date(date_breaks = "1 month", date_labels = "%b") + scale_size_continuous(labels = comma, name = "Eligible\nrequests") + labs(title = "Due-date compliance by request month", subtitle = "Resolved requests with both dates; point size reflects the denominator", x = NULL, y = "On or before source due date")
  })

  output$monthly_plot <- renderPlot({
    x <- filtered() |> mutate(month = floor_date(request_date, "month")) |> count(month)
    ggplot(x, aes(month, n)) + geom_col(fill = "#135D66", width = 25) + scale_y_continuous(labels = comma) + scale_x_date(date_breaks = "1 month", date_labels = "%b") + labs(x = NULL, y = "Requests", subtitle = "Count by request opening date")
  })
  output$service_plot <- renderPlot({
    x <- filtered() |> count(service_type, sort = TRUE, name = "requests") |> slice_head(n = 10) |> mutate(service_type = reorder(service_type, requests))
    ggplot(x, aes(requests, service_type)) + geom_col(fill = "#3C8D93") + scale_x_continuous(labels = comma) + labs(x = "Requests", y = NULL, subtitle = "Top 10 service types in the current selection")
  })
  output$turnaround_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(turnaround_days), turnaround_days >= 0) |> group_by(service_type) |> summarise(median_days = median(turnaround_days), requests = n(), .groups = "drop") |> filter(requests >= 100) |> slice_max(median_days, n = 15, with_ties = FALSE) |> mutate(service_type = reorder(service_type, median_days))
    ggplot(x, aes(median_days, service_type)) + geom_col(fill = "#D08C4B") + labs(x = "Median calendar days", y = NULL, subtitle = "Top 15 median turnaround times; categories need at least 100 resolved requests")
  })
  output$distribution_plot <- renderPlot({
    x <- filtered() |> filter(!is.na(turnaround_days), turnaround_days >= 0, turnaround_days <= quantile(turnaround_days, .99, type = 1, na.rm = TRUE))
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
