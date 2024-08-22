library(shiny)
library(bslib)
library(leaflet)
library(dplyr)
library(gapminder)
library(httr)
library(pins)
library(vetiver)
library(rnaturalearth)
library(sf)
library(stringdist)
library(ggplot2)

# Setup ---------------------------------------------------------

# Read in data
board <- pins::board_connect()
gapminder <- pin_read(board, "ryjohnson09/gapminder")

# Create vetiver endpoint
api_url <- "https://pub.conf.posit.team/public/gapminder_model_rf"
endpoint <- vetiver_endpoint(paste0(api_url, "/predict"))

# Grab Connect API Key
api_key <- Sys.getenv("CONNECT_API_KEY")

# Load country data with geographic information
world_data <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf") %>% 
  mutate(name = name_long)

# Function to get latitude and longitude for a country name
get_country_coords <- function(country_name) {
  # Extract the list of country names from the dataset
  country_names <- world_data$admin
  
  # Find the closest match for the input country name using stringdist
  closest_match <- country_names[which.min(stringdist::stringdist(country_name, country_names, method = "jaccard", q = 3))]
  
  # Filter the dataset for the closest match
  country_info <- world_data %>%
    filter(admin == closest_match) %>%
    st_centroid() %>%
    st_coordinates()
  
  if (nrow(country_info) > 0) {
    return(data.frame(
      country = closest_match,
      latitude = country_info[2],
      longitude = country_info[1]
    ))
  } else {
    return(data.frame(
      country = country_name,
      latitude = NA,
      longitude = NA
    ))
  }
}


# UI ----------------------------------------------
ui <- page_sidebar(
  title = "Gapminder - Life Expectancy Predictor",
  sidebar = sidebar(
    
    
    # Country Input
    selectInput(
      "country", 
      "Select a country:", 
      choices = unique(gapminder$country),
      selected = "United States"
      ),
    
    # Population Input
    numericInput(
      "pop",
      HTML(
        "Select Population Size<br><span style='font-size: 10px; 
        color: grey;'>Defaults to last known population size</span>"
      ),
      min = 60000,
      max = 1500000000,
      value = NULL,
      step = 100000
      ),
    
    # GDP Input
    numericInput(
      "gdp",
      HTML(
        "Select GDP Per-Capita<br><span style='font-size: 10px; 
        color: grey;'>Defaults to last known gdp per-capita</span>"
      ),
      min = 200,
      max = 120000,
      value = NULL,
      step = 100
      )
    ),
  
  
  card(
    leafletOutput("map")
    ),
  card(
    plotOutput("lifeexp_plot")
  )
)


server <- function(input, output, session) {
  
  # Infer Continent from Country
  country <- reactive({
    gapminder %>% 
      select(country, continent) %>% 
      unique() %>% 
      filter(country == input$country) %>% 
      pull(continent)
  })
  
  # Obtaion last known pop size
  last_pop <- reactive({
    gapminder %>% 
      select(country, year, pop) %>% 
      filter(country == input$country) %>% 
      filter(year == max(year)) |> 
      pull(pop)
  })
  
  # Obtaion last gdp
  last_gdp <- reactive({
    gapminder %>% 
      select(country, year, gdpPercap) %>% 
      filter(country == input$country) %>% 
      filter(year == max(year)) |> 
      pull(gdpPercap)
  })
  
  # Update pop input default value to last known pop value
  observeEvent(input$country, {
    updateNumericInput(session, "pop", value = last_pop())
  })
  
  # Update gdp input default value to last known gdp value
  observeEvent(input$country, {
    updateNumericInput(session, "gdp", value = last_gdp())
  })
  
  # LifeExp ggplot
  output$lifeexp_plot <- renderPlot({
    ggplot(gapminder, aes(x = year, y = lifeExp, group = country)) +
      geom_line(aes(color = ifelse(country == input$country, input$country, "Other")),
                linewidth = ifelse(gapminder$country == input$country, 1.5, 0.7), 
                alpha = ifelse(gapminder$country == input$country, 1, 0.3)) +
      scale_color_manual(values = setNames(c("gray", "#EE6331"), c("Other", input$country))) +
      labs(title = paste("Life Expectancy of", input$country, "Compared to Other Countries"),
           x = "Year",
           y = "Life Expectancy",
           color = "Country") +
      theme_minimal() +
      theme(
        legend.position = "none"
      )
  })
  
  # Leaflet Map
  output$map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = 0, lat = 0, zoom = 2)  # Initial view (world)
  })
  
  # Observe input for country and update map
  observeEvent(input$country, {
    
    # Get country Info
    country_data <- world_data %>% 
      filter(admin == get_country_coords(input$country)$country)
    
    bbox <- st_bbox(country_data)
    
    leafletProxy("map") %>%
      clearShapes() %>% 
      addPolygons(data = country_data, color = "#EE6331") %>% 
      setView(lng = get_country_coords(input$country)$longitude, 
              lat = get_country_coords(input$country)$latitude, zoom = 2.5)
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
