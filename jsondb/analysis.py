from __future__ import division

import json
import numpy as np
from scipy import stats

with open("schools/meta.json") as f:
  metas = json.load(f)

with open("schools/grades.json") as f:
  grades = json.load(f)

# Erm. Online Charter vs School Grades. Piece of cake?
# Starting time: 23:31 Jan 10th 2012
# Things we are suppose to do here:
#   Take the averages of online only, charter online, both, and neither for
#   school ranks, school grades, achievements for different subjects
#
#   Take the above and repeat for different years, then graph the trend.

def real_id(id):
  return id.split("-")[0]

def online_charter_analysis():

  # Setup
  analysisresults = {}

  schools = {}
  schools["charter"] = {"H": set(), "M": set()}
  schools["online"] = {"H": set(), "M": set()}
  schools["both"] = {"H": set(), "M": set()}
  schools["neither"] = {"H": set(), "M": set()}
  schools["everything"] = {"H": set(), "M": set()}

  for id, school in grades.iteritems():
    if real_id(id) not in metas:
      continue

    if id[-1] == "H":
      level = "H"
    elif id[-1] in "EM":
      level = "M"
    else:
      level = school.get("2012", school.get("2011", school.get("2010", {}))).get("level")
      if not level and "level" in metas[real_id(id)]:
        if metas[real_id(id)]["level"]["high"]:
          level = "H"
        elif metas[real_id(id)]["level"]["middle"] or metas[real_id(id)]["level"]["elementary"]:
          level = "M"

    if not level:
      continue
    elif level == "H":
      online = schools["online"]["H"]
      charter = schools["charter"]["H"]
      both = schools["both"]["H"]
      neither = schools["neither"]["H"]
      everything = schools["everything"]["H"]
    elif level in "EM":
      online = schools["online"]["M"]
      charter = schools["charter"]["M"]
      both = schools["both"]["M"]
      neither = schools["neither"]["M"]
      everything = schools["everything"]["M"]

    online_school = metas[real_id(id)].get("online", False)
    charter_school = metas[real_id(id)].get("charter", False)

    if online_school and charter_school:
      both.add(id)
    elif online_school and not charter_school:
      online.add(id)
    elif not online_school and charter_school:
      charter.add(id)
    else:
      neither.add(id)

    everything.add(id)

  # Rank analysis section
  def analyse_rank(year, schools): # returns mean
    ranksum = 0
    total = 0
    ranks = []
    maxrank = 0
    for id in schools:
      if id not in grades:
        print "WARNING: " + id + " not in grades!"
        continue

      if year not in grades[id]:
        continue

      if "rank" not in grades[id][year] or grades[id][year]["rank"] is None:
        continue

      rank = grades[id][year]["rank"]
      ranks.append(rank)
      ranksum += rank
      if rank > maxrank:
        maxrank = rank
      total += 1

    return ranksum / total if total > 0 else None, total, ranks, maxrank

  analysisresults["mean_rank"] = mean_rank = {
      "H": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      },



      "M": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      } # lol, inconsistent style with schools
  }

  analysisresults["amount"] = amount = {
      "H": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      },
      "M": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      }
  }

  analysisresults["histogram"] = h = {
      "H": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      },
      "M": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      }
  }

  analysisresults["maxranks"] = maxranks = {
      "H": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      },
      "M": {
        "charter": {},
        "online": {},
        "neither": {},
        "both": {},
        "everything": {}
      }
  }

  for year in ("2010", "2011", "2012"):
    for t in ("charter", "online", "neither", "both", "everything"):
      for l in ("H", "M"):
        avgrank, total, ranks, maxrank = analyse_rank(year, schools[t][l])
        ranks.sort()
        histogram, bins = np.histogram(ranks, 15)

        mean_rank[l][t][year] = avgrank
        amount[l][t][year] = total
        h[l][t][year] = (list(histogram), list(bins))
        maxranks[l][t][year] = maxrank



  return analysisresults



# YAY
# A NEW SECTION
# WTF.


def frl_analysis():
  analysisresults = {
    "frl_to_grades": {
      "2010": [],
      "2011": [],
      "2012": []
    },
    "correlation": {
    }
  }

  # for correlation coefficient
  x2010 = []
  y2010 = []
  x2011 = []
  y2011 = []
  x2012 = []
  y2012 = []
  for id, school in metas.iteritems():
    if "frl" not in school:
      continue

    if id not in grades:
      continue

    g = grades[id]

    if school["frl"][0] and "2010" in g and "school_grade" in g["2010"] and g["2010"]["school_grade"] != None:
      analysisresults["frl_to_grades"]["2010"].append((id, school["frl"][0], g["2010"]["school_grade"]))
      x2010.append(school["frl"][0])
      y2010.append(g["2010"]["school_grade"])

    if school["frl"][1] and"2011" in g and "school_grade" in g["2011"] and g["2011"]["school_grade"] != None:
      analysisresults["frl_to_grades"]["2011"].append((id, school["frl"][1], g["2011"]["school_grade"]))
      x2011.append(school["frl"][1])
      y2011.append(g["2011"]["school_grade"])

    if school["frl"][2] and "2012" in g and "school_grade" in g["2012"] and g["2012"]["school_grade"] != None:
      analysisresults["frl_to_grades"]["2012"].append((id, school["frl"][2], g["2012"]["school_grade"]))
      x2012.append(school["frl"][2])
      y2012.append(g["2012"]["school_grade"])


  analysisresults["correlation"]["2010"] = stats.pearsonr(x2010, y2010)[0]
  analysisresults["correlation"]["2011"] = stats.pearsonr(x2011, y2011)[0]
  analysisresults["correlation"]["2012"] = stats.pearsonr(x2012, y2012)[0]

  return analysisresults



if __name__ == "__main__":
  dumpallowed = True

  everything = {}
  if raw_input("Analyse online charter relations? [y/N] ") == "y":
    everything["online_charter"] = results = online_charter_analysis()

    for t, v in results["mean_rank"]["H"].iteritems():
      for year, rank in v.iteritems():
        print "Average high school rank for {0} in {1} is {2}".format(t, year, rank)

    for t, v in results["mean_rank"]["M"].iteritems():
      for year, rank in v.iteritems():
        print "Average elementary/middle school rank for {0} in {1} is {2}".format(t, year, rank)

  else:
    dumpallowed = False

  print
  print

  if raw_input("Analyse FRL? [y/N] ") == "y":
    everything["frl"] = results = frl_analysis()
    for year, r in results["correlation"].iteritems():
      print "{0} has a correlation coefficient of {1}".format(year, r)
  else:
    dumpallowed = False

  if dumpallowed and raw_input("dump to json file? [y/N] ") == "y":
    print "dumping..."
    with open("analysis/simple.json", "w") as f:
      json.dump(everything, f, indent=4, separators=(",", ": "))

    print "dumped"
