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


# UI
ui <- fluidPage(
  titlePanel("Leaflet Map Focus by Country"),
  sidebarLayout(
    sidebarPanel(
      textInput("country", "Enter a country:", value = "United States")
    ),
    mainPanel(
      leafletOutput("map")
    )
  )
)


server <- function(input, output, session) {
  
  # Initial Leaflet Map
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
      addPolygons(data = country_data) %>% 
      setView(lng = get_country_coords(input$country)$longitude, 
              lat = get_country_coords(input$country)$latitude, zoom = 2.5)
  })
}

# Run the application 
shinyApp(ui = ui, server = server)
