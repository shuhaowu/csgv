# This file is part of CSGV.
#
# CSGV is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# CSGV is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with CSGV.  If not, see <http://www.gnu.org/licenses/>.

import requests
import json
from datetime import datetime

YAHOO_APP_ID = "GET_ID_FROM_YAHOO"

DATA_FILES = ["data/" + year + "_school_address.csv" for year in ("2010", "2012")]

coordinate_json_file = "processed_data/school_coordinates.json"
coordinate_error_file = "processed_data/school_coordinates_error.json"

school_address_table = {
  "2010" : {},
  "2011" : {},
  "2012" : {}
}

for filename in DATA_FILES:
  # who needs the CSV module?
  with open(filename) as f:
    lookuptable = school_address_table[filename[5:9]]
    # we need to resave the data file as it uses \r as file endings

    # we also don't care about the headings
    f.readline()
    line = f.readline().strip()
    while line:
      line = line.split(",")
      organization_code = line[0]
      school_code = line[1]
      phone = line[2]
      name = line[3]
      address = line[4]
      city = line[5]
      state = line[6]
      zipcode = line[7]

      lookuptable[name.upper()] = "{0}, {1}, {2} {3}".format(address, city, state, zipcode)
      line = f.readline().strip()


# 2011 has a different format
with open("data/2011_school_address.csv") as f:
  first = True
  lookuptable = school_address_table["2011"]
  f.readline()
  line = f.readline().strip()
  while line:
    line = line.split(",")
    name = line[1]
    address = line[2]
    city = line[3]
    state = line[4]
    zipcode = line[5]

    lookuptable[name.upper()] = "{0}, {1}, {2} {3}".format(address, city, state, zipcode)
    line = f.readline().strip()


if raw_input("Get coordinates from yahoo? [y/N] ").lower() == "y":
  school_coordinate_table = {
  }

  error_list = []
  for year, table in school_address_table.iteritems():
    for school, location in table.iteritems():
      if school in school_coordinate_table:
        continue

      r = requests.get("http://where.yahooapis.com/geocode", params={"location": location, "appid" : YAHOO_APPID, "flags": "JC"})

      print datetime.now().ctime(), "PROCESSING", school, "at", location, "....",
      if r.status_code == 200:
        r = r.json()
        if int(r[u"ResultSet"][u"Error"]) != 0:
          error_list.append((school, location, "error code {0}".format(r[u"ResultSet"][u"Error"])))
          print "Error!", error_list[-1]
          continue
        if int(r[u"ResultSet"][u"Found"]) != 1:
          error_list.append((school, location, "found {0} results".format(r[u"ResultSet"][u"Found"])))
          print "Error!", error_list[-1]
          continue

        school_coordinate_table[school] = r[u"ResultSet"][u"Results"][0][u"latitude"], r[u"ResultSet"][u"Results"][0][u"longitude"]
        print school_coordinate_table[school]
      else:
        error_list.append((school, location, "request error"))
        print "Error!", error_list[-1]

  print school_coordinate_table
  print
  print error_list
  print
  print "Dumping to file"

  with open(coordinate_json_file, mode="w") as f:
    json.dump(school_coordinate_table, f)

  with open(coordinate_error_file, mode="w") as f:
    json.dump({"errors" : error_list}, f)

with open(coordinate_json_file) as f:
  school_coordinate_table = json.load(f)

with open(coordinate_error_file) as f:
  error_list = json.load(f)["errors"]

print "There are {0} schools with set coordinates".format(len(school_coordinate_table))
print "There are {0} errors".format(len(error_list))

print

print "Errors"

checkdups = {school for school, location, error in error_list}

for school, location, error in error_list:
  try:
    checkdups.remove(school)
  except KeyError:
    print "!!!!!!!!!", school, "is a duplicate!!!!!!!!!"

  if school in school_coordinate_table:
    print school, "already in table, but still errored? {0}".format(school_coordinate_table[school])
    print "==========="
  print school, location, error

floated = {}
# conversion to float because i forgot..
for school, coordinate in school_coordinate_table.iteritems():
  floated[school] = (float(coordinate[0]), float(coordinate[1]))

with open(coordinate_json_file, mode="w") as f:
  json.dump(floated, f)
