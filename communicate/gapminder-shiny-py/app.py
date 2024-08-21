from shiny import App, render, ui
import os
import vetiver
import pandas as pd
from dotenv import load_dotenv
import pins

load_dotenv()

# Define endpoint for API and key
api_url = "_______"
endpoint = vetiver.vetiver_endpoint(api_url + "/predict")
api_key = os.getenv("CONNECT_API_KEY") 

# Get pinned gapminder data
server = os.getenv('CONNECT_SERVER')
board = pins.board_connect(server_url=server, api_key=api_key, allow_pickle_read=True)
gapminder = board.pin_read("ryjohnson09/gapminder")

# User Interface
app_ui = ui.page_sidebar(
    ui.sidebar(

        # Country
        ui.input_select("country", 
                        "Select Country:", 
                        choices=pd.DataFrame(gapminder)['country'].unique().tolist()),

        # Continent
        ui.input_select("continent", 
                        "Select Continent:", 
                        choices=pd.DataFrame(gapminder)['continent'].unique().tolist()),

        # Year
        ui.input_slider("year", 
                        "Select Year:", 
                        min=pd.to_datetime("1951-01-01"), 
                        max=pd.to_datetime("2025-01-01"), 
                        value=pd.to_datetime("2000-01-01"),
                        time_format="%Y"),

        # Population
        ui.input_slider("pop",
                        label="Select Population Size:",
                        min=round(pd.DataFrame(gapminder)['pop'].min(), -3),
                        max=round(pd.DataFrame(gapminder)['pop'].max(), -3),
                        value=700000000,
                        step=100),

        # GDP
        ui.input_slider("gdp",
                        label="Select GDP Per-Capita:",
                        min=round(pd.DataFrame(gapminder)['gdpPercap'].min(), -2),
                        max=round(pd.DataFrame(gapminder)['gdpPercap'].max(), -2),
                        value=57000)
    ),
    

    ui.output_text_verbatim("age")
)

# Server Function
def server(input, output, session):
    @render.text
    def age():
       
        # Add inputs as new data
        new_data = pd.DataFrame({
            'country': [input.country()], 
            'continent': [input.continent()], 
            'year': [input.year().year], 
            'pop': [input.pop()], 
            'gdpPercap': [input.gdp()]
        })

        # If needed, add authorization
        h = {"Authorization": f"Key {api_key}"}

        # Make a prediction
        response = vetiver.predict(endpoint=endpoint, data=new_data, headers=h).at[0, "predict"].round()

        # Return message
        return f"Predicted Life Expectancy at Birth: {response}"

# Create Shiny App
app = App(app_ui, server)