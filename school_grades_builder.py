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

with open("jsondb/schools/meta.json") as f:
  metas = json.load(f)

def csvdata(filename):
  with open(filename) as f:
    reader = csv.reader(f, delimiter=",")
    first = True
    for row in reader:
      if first:
        first = False
        continue
      yield row

FINAL_GRADE = "data/{year}_final_grade.csv"
COACT = "data/{year}_COACT.csv"
CHANGE = "data/{year}_1YR_3YR_change.csv"
REMDIATION = "data/{year}_remediation_HS.csv"

def float_or_none(x):
  try:
    return float(x)
  except ValueError:
    return None

def grade_2012(row):
  data = {
      "level": row[5],
      "rank": int(row[10]) if row[10] else None,
      "school_grade": float_or_none(row[9]),
      "achievement": {
        "overall": float_or_none(row[11]),
        "read": float_or_none(row[12]),
        "math": float_or_none(row[13]),
        "write": float_or_none(row[14]),
        "science": float_or_none(row[15]),
      },
      "growth": {
        "overall": float_or_none(row[16]),
        "read": float_or_none(row[17]),
        "math": float_or_none(row[18]),
        "write": float_or_none(row[19]),
        "science": None
      },
      "graduation_rate": float(row[21]) / 100 if float_or_none(row[21]) is not None else None
  }
  return row[3], data, row[5]

def grade_2011(row):
  level = row[3]
  if row[3] == "A":
    if row[4]:
      level = row[4][-1]

  data = {
      "level": level,
      "rank": int(row[15]) if row[15] else None,
      "school_grade": float_or_none(row[14]),
      "achievement": {
        "overall": float_or_none(row[16]),
        "read": float_or_none(row[17]),
        "math": float_or_none(row[18]),
        "write": float_or_none(row[19]),
        "science": float_or_none(row[20]),
      },
      "growth": {
        "overall": float_or_none(row[21]),
        "read": float_or_none(row[22]),
        "math": float_or_none(row[23]),
        "write": float_or_none(row[24]),
        "science": None
      },
      "graduation_rate": float(row[25]) / 100 if float_or_none(row[25]) is not None else None
  }
  return row[5], data, level

def grade_2010(row):
  data = {
      "level": row[3],
      "rank": int(row[16]) if row[16] else None,
      "school_grade": float_or_none(row[15]),
      "achievement": {
        "overall": float_or_none(row[17]),
        "read": float_or_none(row[18]),
        "math": float_or_none(row[19]),
        "write": float_or_none(row[20]),
        "science": float_or_none(row[21])
      },

      "growth": {
          "overall": float_or_none(row[22]),
          "read": float_or_none(row[23]),
          "math": float_or_none(row[24]),
          "write": float_or_none(row[25]),
          "science": None # WTF? no data
      },

      "graduation_rate": float(row[26]) / 100 if float_or_none(row[26]) is not None else None
  }
  return row[5], data, row[3]


def coact_yn(x):
  if x:
    if x == "1":
      return True
    else:
      return False
  else:
    return None

def coact_2011(row):
  data = {
      "coact": {
        "write": coact_yn(row[4]),
        "math": coact_yn(row[5]),
        "read": coact_yn(row[6]),
        "science": coact_yn(row[7])
      }
  }
  return row[3], data, "H"

def coact_2010(row):
  data = {
      "coact": {
        "write": coact_yn(row[3]),
        "math": coact_yn(row[4]),
        "read": coact_yn(row[5]),
        "science": coact_yn(row[6])
      }
  }
  return row[2], data, "H"

def arrow(x):
  if x == "3":
    return "up"
  elif x == "2":
    return "flat"
  elif x == "1":
    return "down"
  else:
    return None

def change_2012(row):
  data = {
      "scorechange": arrow(row[9]),
      "achievementchange": arrow(row[7]),
      "growthchange": arrow(row[8])
  }
  return row[3], data, row[5]

def change_2010(row):
  if not row[3]:
    return False, False, False
  data = {
      "scorechange": arrow(row[8]),
      "achievementchange": arrow(row[6]),
      "growthchange": arrow(row[7])
  }
  return row[5], data, row[3]

def remediation_2012(row):
  pass

def remediation_2011(row):
  pass

def remediation_2010(row):
  pass

grades_processors = {
  "2012" : grade_2012,
  "2011" : grade_2011,
  "2010" : grade_2010
}

coact_processors = {
  "2012": coact_2011,
  "2011": coact_2011,
  "2010": coact_2010
}

change_processors = {
  "2012": change_2012,
  "2011": change_2010,
  "2010": change_2010
}

remediation_processors = {
  "2012": remediation_2012,
  "2011": remediation_2011,
  "2010": remediation_2010
}

def build_anything(fileprocessor):
  intermediate = {}
  for year in ("2010", "2011", "2012"):
    for f, processor in fileprocessor:
      for row in csvdata(f.format(year=year)):
        if not "".join(row).strip():
          continue
        id, data, level = processor[year](row)
        if not id:
          continue
        d = intermediate.setdefault(id, {})
        l = d.setdefault(level, {})
        y = l.setdefault(year, {})
        y.update(data)

  anything = {}
  for key, value in intermediate.iteritems():
    if len(value) > 1: # This is the wtf case.
      for level, actual in value.iteritems():
        if level not in "EMH":
          # These are all "A", disregard them as they don't have data associated
          # with them anyway.
          continue
        anything[key+"-"+level] = actual
    else:
      anything[key] = value[value.keys()[0]]

  return anything

def build_school_grades():
  return build_anything([
    (FINAL_GRADE, grades_processors),
    (COACT, coact_processors),
    (CHANGE, change_processors),
    # (REMEDIATION, remediation_processors)
  ])

if __name__ == "__main__":
  if raw_input("Build school grades? [y/N] ") == "y":
    grades = build_school_grades()
    with open("jsondb/schools/grades.json", "w") as f:
      json.dump(grades, f, indent=4, separators=(',', ': '))

    print "Built grades for {0} schools".format(len(grades))

    print

  print "Verifications..."

  with open("jsondb/schools/grades.json") as f:
    grades = json.load(f)

  with open("jsondb/schools/meta.json") as f:
    meta = json.load(f)

  def get(schooldata, key, year=None):
    if year is None:
      return schooldata.get("2012", schooldata.get("2011", schooldata.get("2010", {}))).get(key)
    else:
      return schooldata.get(year, {}).get(key)

  def get_highest_level(school):
    if school not in meta:
      return None
    if "level" in meta[school]:
      if meta[school]["level"]["high"]:
        return "H"
      elif meta[school]["level"]["middle"]:
        return "M"
      elif meta[school]["level"]["elementary"]:
        return "E"

    return None

  # highschool, middle/elementary
  missing2012 = [[], [], []]
  missing2011 = [[], [], []]
  missing2010 = [[], [], []]
  missinglevel = []
  partiallevel = []
  levelmapper = {"H": 1, "E": 0, "M": 0, "A": 2}

  # Last one is for the stupid A and other garbage. We will ignore that
  total = {"2012": [0, 0, 0], "2011": [0, 0, 0], "2010": [0, 0, 0]}

  max2012rank = 0
  for id, school in grades.iteritems():
    level = [school.get(year, {}).get("level") for year in ("2010", "2011", "2012")]
    if not any(level):
      missinglevel.append(id)
    if not all(level):
      partiallevel.append(id)

    if "2012" not in school or get(school, "rank", "2012") is None:
      missing2012[levelmapper.get(level[2], 2)].append(id)

    if "2012" in school:
      total["2012"][levelmapper.get(level[2], 2)] += 1

    if "2011" not in school or get(school, "rank", "2011") is None:
      missing2011[levelmapper.get(level[1], 2)].append(id)

    if "2011" in school:
      total["2011"][levelmapper.get(level[1], 2)] += 1

    if "2010" not in school or get(school, "rank", "2010") is None:
      missing2010[levelmapper.get(level[0], 2)].append(id)

    if "2010" in school:
      total["2010"][levelmapper.get(level[0], 2)] += 1


  print "Max 2012 rank: " + str(max2012rank)
  print "{0} schools are missing level".format(len(missinglevel))
  print "{0} schools have partial levels".format(len(partiallevel))

  print "{0}/{1} elementary/middle schools are missing 2012 stats (rank stats minimum)".format(len(missing2012[0]), total["2012"][0])
  print "{0}/{1} highschools are missing 2012 stats (rank stats minimum)".format(len(missing2012[1]), total["2012"][1])


  print "{0}/{1} elementary/middle schools are missing 2011 stats (rank stats minimum)".format(len(missing2011[0]), total["2011"][0])
  print "{0}/{1} highschools are missing 2011 stats (rank stats minimum)".format(len(missing2011[1]), total["2011"][1])

  print "{0}/{1} elementary/middle schools are missing 2010 stats (rank stats minimum)".format(len(missing2010[0]), total["2010"][0])
  print "{0}/{1} highschools are missing 2010 stats (rank stats minimum)".format(len(missing2010[1]), total["2010"][1])

  datainfo = {
      "ranked_emschools_2012": total["2012"][0] - len(missing2012[0]),
      "ranked_highschools_2012": total["2012"][1] - len(missing2012[1]),
      "ranked_emschools_2011": total["2011"][0] - len(missing2011[0]),
      "ranked_highschools_2011": total["2011"][1] - len(missing2011[1]),
      "ranked_emschools_2010": total["2010"][0] - len(missing2010[0]),
      "ranked_highschools_2010": total["2010"][1] - len(missing2010[1])
  }

  print datainfo

  with open("jsondb/schools/datainfo.json", "w") as f:
    json.dump(datainfo, f, indent=4, separators=(',', ': '))
