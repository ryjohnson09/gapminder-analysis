from vetiver import VetiverModel, VetiverAPI
import pins

b = pins.board_connect(server_url='https://pub.ferryland.posit.team/', allow_pickle_read=True)
v = VetiverModel.from_pin(b, 'ryjohnson09/gapminder_model_rf')

vetiver_api = VetiverAPI(v)
app = vetiver_api.app

