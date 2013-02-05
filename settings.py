# This file is not copyrighted.
# EXCLUDED FROM GPL
DEBUG = True
DEPLOY_PORT = 8429

MAPS_KEY = "GET YOUR OWN!"

if MAPS_KEY == "GET YOUR OWN!":
  raise Exception("You need a gmaps api key in settings.py")
  # remove this when you got your own api key