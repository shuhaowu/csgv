from __future__ import division
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


# I'm sorry.
# This code sucks and it's not my fault!
# well... it is my fault as I wrote it.
# But i don't really want to rewrite this one time, 2 week long project.
# The only well written code here is under jsondb/mostimproved.py

from math import e, ceil, log
import data

from flask import Flask, render_template, abort, request
from settings import DEBUG, DEPLOY_PORT, MAPS_KEY
from scipy.spatial import cKDTree as KDTree
import ujson

app = Flask(__name__)

# ujson for both speed and compactness
def jsonify(**params):
  response = app.make_response(ujson.dumps(params))
  response.mime_type = "application/json"
  return response

# We can permacache data as the data is not huge
with open("jsondb/schools/meta.json") as f:
  school_metas = ujson.load(f)

with open("jsondb/schools/grades.json") as f:
  school_grades = ujson.load(f)

with open("jsondb/analysis/simple.json") as f:
  simple_analysis = ujson.load(f)

with open("jsondb/analysis/mostimproved.json") as f:
  mostimproved = ujson.load(f)["improved"]

def build_most_improved():
  # We want to make most improved ready for that table in charts
  # and not have to run around to fetch it.
  global simple_analysis

  analysis_improved = simple_analysis["improved"] = []
  with open("jsondb/schools/districts.json") as f:
    districts = ujson.load(f)
  for id, distance in mostimproved:
    real_id = id.split("-")[0]
    school_meta = school_metas[real_id]
    school_grade = school_grades[id]
    analysis_improved.append((
      id,
      school_meta["name"].title(),
      districts[school_meta["district"]] if school_meta["district"] else None,
      school_meta["city"].title(),
      school_meta.get("enrollment", {}).get("2010", {}).get("total"),
      school_meta.get("enrollment", {}).get("2012", {}).get("total"),
      school_grade.get("2010", {}).get("rank"),
      school_grade.get("2012", {}).get("rank"),
      distance
    ))


build_most_improved()

del build_most_improved

school_coordinates = data.get_all_school_coordinates(school_metas)
school_coordinates_json = ujson.dumps(school_coordinates)

# For the kd tree of similar schools calculations

enrollment_kd_list = {
  "2012": {"H": [], "M": [], "E": []},
  "2011": {"H": [], "M": [], "E": []},
  "2010": {"H": [], "M": [], "E": []}
}


grades_kd_list = {
  "2012": {"H": [], "M": [], "E": []},
  "2011": {"H": [], "M": [], "E": []},
  "2010": {"H": [], "M": [], "E": []}
}

enrollment_kd_metas = {
  "2012": {"H": [], "M": [], "E": []},
  "2011": {"H": [], "M": [], "E": []},
  "2010": {"H": [], "M": [], "E": []}
}

grades_kd_metas = {
  "2012": {"H": [], "M": [], "E": []},
  "2011": {"H": [], "M": [], "E": []},
  "2010": {"H": [], "M": [], "E": []}
}

enrollment_kd = {
  "2012": {},
  "2011": {},
  "2010": {}
}

grades_kd = {
  "2012": {},
  "2011": {},
  "2010": {}
}


veryfar_if_none = lambda x: -5000000 if x is None else x
zero_if_none = lambda x: 0 if x is None else x

year_to_i = {"2012": 2, "2011": 1, "2010": 0}

def build_enrollment_vector(id, year, level):
  real_id = id.split("-")[0]
  if real_id not in school_metas:
    return None

  # Enrollment vector
  enrollment = school_metas[real_id]["enrollment"].get(year)
  if not enrollment:
    enrollment_vector = None
  else:
    total = enrollment["total"]
    enrollment_vector = (
      total / 5000,
      enrollment["asian"] / total, # This is not the best algorithm
      enrollment["black"] / total, # reason is it is not normalized
      enrollment["latino"] / total,# asian will have a max value of 0.2
      enrollment["white"] / total  # while white could have like 1.0
    )
  return enrollment_vector

def build_grades_vector(id, year, level):
  school = school_grades[id].get(year, {})
  if "rank" not in school or \
    "school_grade" not in school or \
    "achievement" not in school or \
    "growth" not in school:
    grades_vector = None
  else:
    grades_vector = (
      veryfar_if_none(school["rank"]),
      veryfar_if_none(school["school_grade"]),
      zero_if_none(school["achievement"]["overall"]),
      zero_if_none(school["achievement"]["read"]),
      zero_if_none(school["achievement"]["math"]),
      zero_if_none(school["achievement"]["write"]),
      zero_if_none(school["achievement"]["science"]),
      zero_if_none(school["growth"]["overall"]),
      zero_if_none(school["growth"]["read"]),
      zero_if_none(school["growth"]["write"]),
      zero_if_none(school["growth"]["math"]),
    )

  return grades_vector


def get_id_level(id):
  _temp = id.split("-")
  real_id = _temp[0]
  if len(_temp) > 1:
    level = _temp[1]
  else:
    level = school_grades[id].get("2012", school_grades[id].get("2011", school_grades[id].get("2010", {}))).get("level")

  return real_id, level

def generate_kd():
  # order is important, so this will take longer to ensure indexes are correct

  # Although capable of doing "2010" and "2011" data, but there is no point
  # as details view shows 2010 - 2012 data in 1 screen. Furthermore, combining
  # everything will result into huge dimensions.
  # average won't work too too well as there are missing data points and
  # require too much time.
  # since this is an estimate, it doesn't matter that much.
  for year in ("2012", ):
    for level in ("E", "H", "M"):
      for id in school_grades:

        real_id, current_level = get_id_level(id)

        if current_level != level:
          continue

        vector = build_enrollment_vector(id, year, level)
        if vector:
          enrollment_kd_list[year][level].append(vector)
          enrollment_kd_metas[year][level].append(id)

        vector = build_grades_vector(id, year, level)
        if vector:
          grades_kd_list[year][level].append(vector)
          grades_kd_metas[year][level].append(id)


      enrollment_kd[year][level] = KDTree(enrollment_kd_list[year][level])
      grades_kd[year][level] = KDTree(grades_kd_list[year][level])


generate_kd()
del generate_kd

school_names_to_id_json = ujson.dumps(data.get_all_school_names(school_metas))
school_enrollments_json = ujson.dumps(data.get_enrollment(school_metas, "2012", "total"))

@app.before_request
def before_request():
  app.jinja_env.globals["MAPS_KEY"] = MAPS_KEY

@app.route("/")
def mainapp():
  return render_template("visualizer.html",
      school_coordinates=school_coordinates_json,
      school_names=school_names_to_id_json,
      school_enrollments=school_enrollments_json)

def get_info_from_grades(school_id, attribute):
  possible_ids = (school_id, school_id+"-H", school_id+"-M", school_id+"-E")
  r = {}
  for id in possible_ids:
    if id in school_grades:
      school = school_grades[id]
      i = []
      for year in ("2010", "2011", "2012"):
        i.append(school.get(year, {}).get(attribute))

      r[id] = i
  return r

@app.route("/schools/info/<school_id>")
def get_school_info(school_id):
  try:
    info = {"rank": {}}
    school_id = school_id.split("-")[0]
    r = get_info_from_grades(school_id, "rank")
    for key, ranks in r.iteritems():
      if key[-1] in "EMH":
        info["rank"][key[-1]] = ranks[-1]
      else:
        info["rank"][school_grades[key].get("2012", school_grades[key].get("2011", school_grades[key].get("2010", {}))).get("level", "U")] = ranks[-1]

    info.update(school_metas[school_id])
    return jsonify(**info)
  except KeyError:
    return abort(404)


# THis is very hacked together as i didn't have this before
# server performance will suffer! :D
def _make_stuff_leveled(from_db):
  parsed = {}
  for key, stuffs in from_db.iteritems():
    if key[-1] in "EMH":
      parsed[key[-1]] = stuffs
    else:
      s = school_grades[key]
      level = s.get("2012", s.get("2011", s.get("2010"))).get("level", "U")
      parsed[level] = stuffs

  return parsed

def merge_stuff(origin, from_db, attribute):
  for k, values_for_years in from_db.iteritems():
    d = origin.setdefault(k, {})
    d[attribute] = values_for_years

@app.route("/schools/details/<school_id>")
def get_school_details(school_id):
  # Get info for the overall chart on the top left
  school_id = school_id.split("-")[0]
  try:
    achievement_from_db = _make_stuff_leveled(get_info_from_grades(school_id, "achievement"))
    growth_from_db = _make_stuff_leveled(get_info_from_grades(school_id, "growth"))
    grades_from_db = _make_stuff_leveled(get_info_from_grades(school_id, "school_grade"))
    rank_from_db = _make_stuff_leveled(get_info_from_grades(school_id, "rank"))
    achievementchange = _make_stuff_leveled(get_info_from_grades(school_id, "achievementchange"))
    growthchange = _make_stuff_leveled(get_info_from_grades(school_id, "growthchange"))
    scorechange = _make_stuff_leveled(get_info_from_grades(school_id, "scorechange"))
    meta = school_metas[school_id]
    coact = _make_stuff_leveled(get_info_from_grades(school_id, "coact"))
  except KeyError:
    return abort(404)
  else:
    info = {}
    merge_stuff(info, achievement_from_db, "achievements")
    merge_stuff(info, growth_from_db, "growth")
    merge_stuff(info, grades_from_db, "grades")
    merge_stuff(info, rank_from_db, "rank")
    merge_stuff(info, achievementchange, "achievementchange")
    merge_stuff(info, growthchange, "growthchange")
    merge_stuff(info, scorechange, "scorechange")
    merge_stuff(info, coact, "coact")
    info["meta"] = meta

    return jsonify(**info)

@app.route("/schools/enrollment/<attribute>/<year>")
def get_schools_enrollment(attribute, year):
  return jsonify(**data.get_enrollment(school_metas, year, attribute))

@app.route("/schoolmarkers")
def get_school_markers():
  bottomleft = (float(request.args["bottomleftlat"]), float(request.args["bottomleftlong"]))
  topright = (float(request.args["toprightlat"]), float(request.args["toprightlong"]))
  zoomlevel = float(request.args["zoomlevel"])

  def criteria(school):
    if "enrollment" not in school or "2012" not in school["enrollment"]:
      return False
    else:
      return data.school_big_enough(school["enrollment"]["2012"]["total"], zoomlevel)

  def d(school):
    if "level" not in school:
      return "skipme"
    else:
      if school["level"]["high"]:
        return "H"
      else:
        return "M"

  return jsonify(**data.get_schools_within_viewport(school_metas, criteria, d, topright, bottomleft, zoomlevel, school_metas))

with open("jsondb/schools/datainfo.json") as f:
  schools_datainfo = ujson.load(f)

rank_scale_h = lambda x: 17.0 / (1 + e**(-((schools_datainfo["ranked_highschools_2012"]+1-x)-230.0)/20.0)) + 3
rank_scale_em = lambda x: 17.0 / (1 + e**(-((schools_datainfo["ranked_emschools_2012"]+1-x)-1200.0)/80.0)) + 3

max_rank_h = lambda x: (340.0 / (1 + e**(-0.8*(x-12.3)))) + 1.0
max_rank_em = lambda x: (1325.0 / (1 + e**(-0.8*(x-14.3)))) + 1.0

@app.route("/rankview")
def get_rankview_markers():
  bottomleft = (float(request.args["bottomleftlat"]), float(request.args["bottomleftlong"]))
  topright = (float(request.args["toprightlat"]), float(request.args["toprightlong"]))
  zoomlevel = float(request.args["zoomlevel"])

  def criteria(school):
    if "2012" not in school or "rank" not in school["2012"] or school["2012"]["rank"] is None or "level" not in school["2012"]:
      return False
    else:
      max_rank = max_rank_h(zoomlevel) if school["2012"]["level"] == "H" else max_rank_em(zoomlevel)
      return school["2012"]["rank"] <= max_rank

  markers = {}
  for id, school in school_grades.iteritems():
    real_id = id.split("-")[0]
    if real_id not in school_metas:
      continue

    coordinate = school_metas[real_id]["coordinate"]
    if criteria(school) and data.in_viewport(topright, bottomleft, coordinate):
      if school["2012"]["level"] == "H":
        markers[id] = {"level": "H", "scale": rank_scale_h(school["2012"]["rank"]), "real_id": real_id}
      else:
        markers[id] = {"level": "M", "scale": rank_scale_em(school["2012"]["rank"]), "real_id": real_id}

  return jsonify(**markers)

reversezoomlevel_rank_high = lambda rank: ceil((log(340.0 / (rank)) - 1) / -0.8 + 12.3) + 1
reversezoomlevel_rank_middle = lambda rank: ceil((log(1325.0 / (rank)) - 1) / -0.8 + 14.3) + 1

# try to accomodate most scenarios..
@app.route("/reverserank/<id>")
def reverserank(id):
  if id in school_grades:
    grades = school_grades[id].get("2012", {})
    reversezoom = reversezoomlevel_rank_high if grades.get("level") == "H" else reversezoomlevel_rank_middle
  elif id+"-H" in school_grades:
    grades = school_grades[id+"-H"].get("2012", {})
    reversezoom = reversezoomlevel_rank_high
  elif id+"-M" in school_grades:
    grades = school_grades[id+"-M"].get("2012", {})
    reversezoom = reversezoomlevel_rank_middle
  elif id+"-E" in school_grades:
    grades = school_grades[id+"-E"].get("2012", {})
    reversezoom = reversezoomlevel_rank_middle
  else:
    return abort(404)

  rank = grades.get("rank")
  if not rank:
    return abort(404)

  return str(int(reversezoom(rank)))

YEAR_MAP_TO_POS = {"2010": 0, "2011": 1, "2012": 2}
@app.route("/tabular/<level>/<year>")
def get_tabular_data(level, year):
  table = []
  if level not in "EMH" and year not in YEAR_MAP_TO_POS:
    return abort(404)
  for id, school in school_metas.iteritems():
    if "level" in school and \
       "enrollment" in school and \
       year in school["enrollment"] and \
       ((level == "H" and school["level"]["high"]) or \
          (level == "M" and (school["level"]["middle"] or school["level"]["elementary"]))):

      enrollment = school["enrollment"][year]
      grades = school_grades.get(id+"-"+level, school_grades.get(id, {}))
      rank = grades.get(year, {}).get("rank", None)
      if not rank:
        continue


      row = [
          id,
          school["name"].title(),
          enrollment["total"],
          enrollment["asian"] / enrollment["total"],
          enrollment["black"] / enrollment["total"],
          enrollment["latino"] / enrollment["total"],
          enrollment["white"] / enrollment["total"],
          (enrollment["hawaii"] + enrollment["indian"] + enrollment["mixed"]) // enrollment["total"],
          rank,
          grades.get(year, {}).get("school_grade"),
          grades.get(year, {}).get("achievement", {}).get("overall"),
          grades.get(year, {}).get("achievement", {}).get("read"),
          grades.get(year, {}).get("achievement", {}).get("math"),
          grades.get(year, {}).get("achievement", {}).get("write"),
          grades.get(year, {}).get("achievement", {}).get("science"),
          school["frl"][YEAR_MAP_TO_POS[year]]
      ]
      if level == "H":
        row.append(grades.get(year, {}).get("graduation_rate"))
      else:
        row.append(None)

      table.append(row)

  return jsonify(data=table)

@app.route("/charts/<attr>")
def get_chart_stuff(attr):
  if attr not in simple_analysis:
    return abort(404)

  # theoretical security risk on "improved"
  # but we don't care as go ahead and steal public data.
  response = app.make_response(ujson.dumps(simple_analysis[attr]))
  response.mime_type = "application/json"
  return response

@app.route("/rankheat")
def rank_heat_map():
  heatmap = []
  for id, school in school_grades.iteritems():
    _temp = id.split("-")

    rank = school.get("2012", {}).get("rank")
    if rank is None:
      continue

    if len(_temp) > 1:
      level = _temp[1]
    else:
      level = school.get("2012", {}).get("level")
      if not level:
        continue

    weight = rank_scale_h(rank) if level == "H" else rank_scale_em(rank)

    heatmap.append({"id": _temp[0], "weight": weight})

  return jsonify(data=heatmap)

@app.route("/improvedheat")
def improved_heat_map():

  # we need to reverse the theme where smallest distance is best,
  # here we need high weight to show up on the map
  # also, we should make everything quadratic so that we can show more
  # contrast.
  heatmap = []
  i = 0
  for id, distance in mostimproved:
    if i == 200:
      break
    # flips max to min and min to max
    # also i want min to be at 1, so.
    distance = mostimproved[-1][1] + mostimproved[0][1] - distance - (mostimproved[0][1] - 1)
    heatmap.append({"id": id.split("-")[0], "weight": distance**2})
    i += 1

  return jsonify(data=heatmap)

@app.route("/similar/<id>/<level>/<type>")
def similar_schools(id, level, type):
  year = "2012" # again, disabled multi years
  if type not in ("enrollment", "grades"):
    return abort(404)
  try:
    if type == "grades":
      kdtree = grades_kd[year][level]
      metas = grades_kd_metas[year][level]
      vector = grades_kd_list[year][level]
      build_vector = build_grades_vector
      if id not in school_grades and len(id.split("-")) == 1:
        id += "-" + level
    else:
      kdtree = enrollment_kd[year][level]
      metas = enrollment_kd_metas[year][level]
      vector = enrollment_kd_list[year][level]
      build_vector = build_enrollment_vector
  except KeyError:
    return abort(404)
  else:

    indexes = kdtree.query(build_vector(id, year, level), 6)[1]

    results = []
    for i in indexes:
      real_id, level = get_id_level(metas[i])
      if real_id == id:
        continue

      results.append({"id": metas[i], "data": [school_metas[real_id]["name"].title()] + list(vector[i])})

    return jsonify(schools=results)

if __name__ == "__main__":
  if DEBUG == True:
    app.run(debug=True, host="")
  else:
    from gevent.wsgi import WSGIServer
    http_server = WSGIServer(("127.0.0.1", DEPLOY_PORT), app)
    http_server.serve_forever()
