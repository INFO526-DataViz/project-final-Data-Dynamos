# GETTING THE LIBRARIES
if (!require("pacman"))
  install.packages("pacman")

if (!require("rnaturalearthdata"))
  install.packages("rnaturalearthdata")

pacman::p_load(tidyverse,
               here,
               ggpubr,
               janitor,
               colorspace,
               magick,
               hexbin,
               dplyr,
               janitor,
               sf,
               leaflet,
               ggplot2,
               rnaturalearth,
               rworldmap,
               dlookr,
               IRdisplay,
               ggmap,
               shiny,
               shinydashboard,
               shinythemes
)

theme_set(theme_minimal(base_size = 11))

# setting theme for ggplot2
ggplot2::theme_set(ggplot2::theme_minimal(base_size = 14))

# setting width of code output
options(width = 70)

# setting figure parameters for knitr
knitr::opts_chunk$set(
  fig.width = 12,        # 7" width
  fig.asp = 0.618,      # the golden ratio
  fig.retina = 4,       # dpi multiplier for displaying HTML output on retina
  fig.align = "center", # center align figures
  dpi = 500             # higher dpi, sharper image
)

#install.packages("shinythemes")
library(shinythemes)

# Read meteorite data
meteorite <- read_csv("https://raw.githubusercontent.com/INFO526-DataViz/project-final-Data-Dynamos/main/data/Meteorite_Landings.csv")

# Rename columns using dplyr::rename
meteorite <- na.omit(meteorite) %>%
  clean_names() %>%
  rename(mass = mass_g, class = recclass)

# Selecting columns where mass > 1 gram
meteorite <- subset(meteorite, mass >= 1)

# Drop unnecessary columns
meteorite <- meteorite[, !(names(meteorite) %in% c("nametype", "fall"))]

# Create the 'decade' column
meteorite <- meteorite %>%
  mutate(decade = case_when(
    year < 1950 ~ "Before 1950",
    between(year, 1951, 1960) ~ "Decade 1951-1960",
    between(year, 1961, 1970) ~ "Decade 1961-1970",
    between(year, 1971, 1980) ~ "Decade 1971-1980",
    between(year, 1981, 1990) ~ "Decade 1981-1990",
    between(year, 1991, 2000) ~ "Decade 1991-2000",
    between(year, 2001, 2010) ~ "Decade 2001-2010",
    between(year, 2011, 2020) ~ "Decade 2011-2020",
    TRUE ~ "NA"  # Default case if none of the conditions are met
  ))

# Create a world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# Define UI for the Shiny app
ui <- fluidPage(
  theme = shinytheme("darkly"),
  titlePanel("Meteorite Impact Visualization"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("year_range", "Select Year Range:",
                  min = min(meteorite$year), max = max(meteorite$year),
                  value = c(min(meteorite$year), max(meteorite$year)),
                  step = 1),
      sliderInput("mass_range", "Select Mass Range (g):",
                  min = min(meteorite$mass), max = max(meteorite$mass),
                  value = c(min(meteorite$mass), max(meteorite$mass)),
                  step = 1),
      selectInput("plot_type", "Select Plot Type:",
                  choices = c("Point Plot", "Thermal Density Map", "Bubble Plot"),
                  selected = "Point Plot")
    ),
    mainPanel(
      plotOutput("meteor_map")
    )
  )
)

# Server for Shiny app
server <- function(input, output) {
  # Filter data based on user input
  filtered_data <- reactive({
    meteorite %>%
      filter(year >= input$year_range[1], year <= input$year_range[2],
             mass >= input$mass_range[1], mass <= input$mass_range[2])
  })
  
  # Function to create Point Plot
  create_point_plot <- function(data) {
    ggplot() +
      geom_sf(data = world, fill = "lightgrey") +
      geom_point(data = data, aes(x = reclong, y = reclat), color = "red", size = 1, alpha = 0.5) +
      labs(title = "World Map: Meteorite Impacts\n",
           x = "Longitude",
           y = "Latitude") +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14),
        axis.text = element_text(size = 8)
      )
  }
  
  # Function to create Thermal Density Map
  create_density_map <- function(data) {
    ggplot() +
      geom_sf(data = world, fill = "lightgrey") +
      geom_density_2d(data = data, aes(x = reclong, y = reclat), color = "red") +
      labs(title = "Thermal Map: Meteorite Impacts Density",
           x = "Longitude",
           y = "Latitude") +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14),
        axis.text = element_text(size = 8)
      )
  }
  
  # Function to create Bubble Plot
  create_bubble_plot <- function(data) {
    ggplot() +
      geom_sf(data = world, fill = "lightgrey") +
      geom_point(data = data, aes(x = reclong, y = reclat, size = mass), color = "blue", alpha = 0.5) +
      labs(title = "Bubble Map of Meteorite Mass",
           x = "Longitude",
           y = "Latitude") +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14),
        axis.text = element_text(size = 8)
      ) +
      scale_size_continuous(labels = function(x)
        scales::number_format(scale = 1e-6,
                              suffix = "M (g)")(x) |>
          str_replace_all("\\.", ","))
  }
  
  # Define the reactive plot
  output$meteor_map <- renderPlot({
    data <- filtered_data()
    plot_type <- input$plot_type
    
    if (plot_type == "Point Plot") {
      create_point_plot(data)
    } else if (plot_type == "Thermal Density Map") {
      create_density_map(data)
    } else if (plot_type == "Bubble Plot") {
      create_bubble_plot(data)
    }
  })
}

# Run the Shiny app
shinyApp(ui, server)
