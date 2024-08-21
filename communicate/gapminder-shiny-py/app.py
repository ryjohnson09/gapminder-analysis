from shiny import App, render, ui
import os
import vetiver
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

# Define endpoint for API and key
api_url = "https://pub.conf.posit.team/public/gapminder_model_rf"
endpoint = vetiver.vetiver_endpoint(api_url + "/predict")
api_key = os.getenv("CONNECT_API_KEY") 

# User Interface
app_ui = ui.page_fluid(
    ui.input_slider("year", 
                    "Select Year:", 
                    min=pd.to_datetime("1950-01-01"), 
                    max=pd.to_datetime("2024-01-01"), 
                    value=pd.to_datetime("2000-01-01"),
                    time_format="%Y"),
    ui.output_text_verbatim("age")
)

# Server Function
def server(input, output, session):
    @render.text
    def age():
       
        # Add inputs as new data
        new_data = pd.DataFrame({
            'country': ["Zimbabwe"], 
            'continent': ["Africa"], 
            'year': input.year().year, 
            'pop': [11405000], 
            'gdpPercap': [800]
        })

        # If needed, add authorization
        h = {"Authorization": f"Key {api_key}"}

        # Make a prediction
        response = vetiver.predict(endpoint=endpoint, data=new_data, headers=h).at[0, "predict"].round()

        # Return message
        return f"Predicted Life Expectancy at Birth: {response}"

# Create Shiny App
app = App(app_ui, server)