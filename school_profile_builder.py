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

import csv
import json


def address_2010_2012(row):
  school = {
      "name": row[3],
      "address": row[4],
      "city": row[5],
      "zipcode": row[7],
      "phone": row[2]
  }
  return row[1], school

def address_2011(row):
  school = {
    "name": row[1],
    "address": row[2],
    "city": row[3],
    "zipcode": row[5],
    "phone": row[6]
  }
  return row[0], school

def enrollment(row):
  total = int(row[4])
  enrollmentinfo = {
    "total": total,
    "indian": int(round(float(row[5]) * total)),
    "asian": int(round(float(row[6]) * total)),
    "black": int(round(float(row[7]) * total)),
    "latino": int(round(float(row[8]) * total)),
    "white": int(round(float(row[9]) * total)),
    "hawaii": int(round(float(row[10]) * total)),
    "mixed": int(round(float(row[11]) * total))
  }
  return row[2], enrollmentinfo


def grade_meta_2010(row):
  school = {}
  level = school["level"] = {"elementary": False, "middle": False, "high": False}

  def _setlevel(l):
    if l == "E":
      level["elementary"] = True
    elif l == "M":
      level["middle"] = True
    elif l == "H":
      level["high"] = True

  if row[3] in ("E", "M", "H"):
    _setlevel(row[3])
  else:
    if row[4]:
      for c in row[4]:
        _setlevel(row[4])
    else:
      del school["level"]

  school["charter"] = "Charter" in row[7]
  school["online"] = "Online" in row[7]
  school["district"] = row[1]

  return row[5], school

def grade_meta_2011(row):
  school = {}
  level = school["level"] = {"elementary": False, "middle": False, "high": False}

  def _setlevel(l):
    if l == "E":
      level["elementary"] = True
    elif l == "M":
      level["middle"] = True
    elif l == "H":
      level["high"] = True

  if row[3] in ("E", "M", "H"):
    _setlevel(row[3])
  else:
    if row[4]:
      for c in row[4]:
        _setlevel(row[4])
    else:
      del school["level"]
  school["charter"] = row[7] == "1"
  school["online"] = row[8] == "1"
  school["district"] = row[1]
  return row[6], school

def grade_meta_2012(row):
  school = {}
  level = school["level"] = {"elementary" : False, "middle" : False, "high": False}

  for c in row[6]:
    if c == "E":
      level["elementary"] = True
    elif c == "M":
      level["middle"] = True
    elif c == "H":
      level["high"] = True

  if not any(school.values()):
    del school["level"]

  school["district"] = row[1]
  return row[3], school

def frl(row):
  if not row[2]:
    return False, False
  return row[2], float(row[4][:-1]) / 100.0

school_address_handler = {
    "2010": address_2010_2012,
    "2011": address_2011,
    "2012": address_2010_2012
}

school_enrollment_handler = {
    "2010": enrollment,
    "2011": enrollment,
    "2012": enrollment
}

school_grade_meta_handler = {
    "2010": grade_meta_2010,
    "2011": grade_meta_2011,
    "2012": grade_meta_2012
}

def build_school_meta(jsonfile=None):
  schools = {}
  for year in ("2010", "2011", "2012"):
    with open("data/"+year+"_school_address.csv") as f:
      reader = csv.reader(f, delimiter=",")
      first = True
      for row in reader:
        if first:
          first = False
          continue
        id, d = school_address_handler[year](row)
        school = schools.setdefault(id, {})
        school.update(d)

    with open("data/"+year+"_enrl_working.csv") as f:
      reader = csv.reader(f, delimiter=",")
      first = True
      for row in reader:
        if first:
          first = False
          continue

        id, d = school_enrollment_handler[year](row)
        if id in schools:
          enrollment = schools[id].setdefault("enrollment", {})
          enrollment[int(year)] = d

    with open("data/"+year+"_final_grade.csv") as f:
      reader = csv.reader(f, delimiter=",")
      first = True
      for row in reader:
        if first:
          first = False
          continue

        id, d = school_grade_meta_handler[year](row)
        if id in schools:
          schools[id].update(d)

    with open("data/"+year+"_k_12_FRL.csv") as f:
      reader = csv.reader(f, delimiter=",")
      first = True
      for row in reader:
        if first:
          first = False
          continue

        id, f = frl(row)
        if not id:
          continue
        if id in schools:
          l = schools[id].setdefault("frl", {})
          l[year] = f

  # We really want frl to just a list because it is easy, so we just do some
  # extra work

  for id in schools:
    if "frl" not in schools[id]:
      schools[id]["frl"] = (None, None, None)
    else:
      schools[id]["frl"] = (schools[id]["frl"].get("2010"), schools[id]["frl"].get("2011"), schools[id]["frl"].get("2012"))

  with open("data/school_gps_coordinates.csv") as f:
    reader = csv.reader(f, delimiter=",")
    first = True
    for row in reader:
      if first:
        first = False
        continue

      coordinate = (float(row[2]), float(row[3]))
      if row[0] in schools:
        schools[row[0]]["coordinate"] = coordinate

  if jsonfile:
    json.dump(schools, jsonfile, indent=4, separators=(',', ': '))

  return schools

def build_districts():
  districts = {}
  for year in ("2010", "2011", "2012"):
    with open("data/"+year+"_final_grade.csv") as f:
      reader = csv.reader(f, delimiter=",")
      first = True
      for row in reader:
        if first:
          first = False
          continue

        districts[row[1]] = row[2].title()

  return districts

if __name__ == "__main__":
  if raw_input("Build school meta? [y/N] ") == "y":
    with open("jsondb/schools/meta.json", mode="w") as f:
      schools = build_school_meta(f)
      print "Built meta info for {0} schools".format(len(schools))

  print
  print

  with open("jsondb/schools/meta.json") as f:
    schools = json.load(f)

    try:
      gps_source2 = open("processed_data/school_coordinates.json")
      gps = json.load(gps_source2)
      gps_source2.close()
    except IOError:
      gps = {}

    changed = False
    print "Schools without GPS information:"
    for school in schools.itervalues():
      if "coordinate" not in school:
        if school["name"].upper() in gps:
          school["coordinate"] = gps[school["name"]]
          changed = True
        else:
          print "  - {0} ({1})".format(school["name"], school["address"])

    if changed:
      with open("jsondb/schools/meta.json", mode="w") as f:
        json.dump(schools, f, indent=4, separators=(",", ": "))

    print
    print "Schools without complete enrollment information:"
    for school in schools.itervalues():
      if "enrollment" not in school:
        print "  - {0}: No enrollment information".format(school["name"])
        continue

      missing = ""
      if "2010" not in school["enrollment"]:
        missing += " 2010"

      if "2011" not in school["enrollment"]:
        missing += " 2011"

      if "2012" not in school["enrollment"]:
        missing += " 2012"

      if missing:
        print "  - {0}: Missing enrollment data from".format(school["name"]) + missing

    print
    print "Schools without grade level information: "
    for school in schools.itervalues():
      if "level" not in school:
        print "  - {0}".format(school["name"])

    print
    print "Schools without charter/online information: "
    for school in schools.itervalues():
      if "charter" not in school or "online" not in school:
        print "  - {0}".format(school["name"])

    print
    print "Schools without frl data: "
    for school in schools.itervalues():
      if "frl" not in school:
        print "  - {0}".format(school["name"])
      elif len(school["frl"]) != 3:
        print "  - {0} (PARTIAL {1})".format(school["name"], len(school["frl"]))

  if raw_input("Build district data? [y/N] ") == "y":
    with open("jsondb/schools/districts.json", "w") as f:
      districts = build_districts()
      json.dump(districts, f, indent=4, separators=(',', ': '))
    print "Build {0} districts".format(len(districts))