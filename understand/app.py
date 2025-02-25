from vetiver import VetiverModel, VetiverAPI
import pins

pin_model_name = "____"

b = pins.board_connect(server_url='https://pub.workshop.posit.team/', allow_pickle_read=True)
v = VetiverModel.from_pin(b, pin_model_name)

vetiver_api = VetiverAPI(v)
app = vetiver_api.app

