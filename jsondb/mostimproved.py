# -*- coding: utf-8 -*-
# This file is part of csgv.
#
# csgv is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# csgv is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with csgv.  If not, see <http://www.gnu.org/licenses/>.

# Author's note:
# Since all the code from this project has been a disaster so far in terms of
# readability and maintability. This will be an exception. I will try to write
# the code to be as nice as possible, with comments and rational to show that
# it is possible for me the write at least somewhat reasonably okay code.
#
# This file will be the only file that I'm responsible of in this project :D
# Everything else is just garbage and I'm not sure which idiot programmer
# wrote them.

# The analysis used here is very simple. All I did here is a K-nearest neighbor
# search with the straightforward euclidean distances.
#
# There are probably insufficient data here to find what caused these
# improvements and if they are improvements at all as all data
# are relative to each other instead of absolute data points.

from __future__ import division
import numpy as np
import json

def check_not_in(d, *attrs):
  """A short hand function to check if a bunch of attributes is not in
  a dictionary."""
  for attr in attrs:
    if attr not in d or d[attr] is None:
      return True

  return False

def is_school_valid(grade):
  """Make sure the school is valid as we need complete data to compute the
  growth and achievements. Schools failing this have insufficient (or rather,
  insufficient for my taste) amount of data for this analysis."""
  return not (check_not_in(grade, "2012", "2010") or \
     check_not_in(grade["2012"], "rank", "school_grade", "achievement", "growth") or \
     check_not_in(grade["2010"], "rank", "school_grade", "achievement", "growth") or \
     check_not_in(grade["2012"]["achievement"], "read", "write", "overall", "math", "science") or \
     check_not_in(grade["2010"]["achievement"], "read", "write", "overall", "math", "science") or \
     check_not_in(grade["2012"]["growth"], "read", "write", "overall", "math") or \
     check_not_in(grade["2011"]["growth"], "read", "write", "overall", "math") or \
     check_not_in(grade["2010"]["growth"], "read", "write", "overall", "math"))

mean = lambda x: sum(x) / len(x)

def build_vector(grade):
  """Builds an un-normalized vector for each school. This will later be
  normalized by the function `normalize_vectors`"""
  return np.array((
    grade["2012"]["achievement"]["overall"] - grade["2010"]["achievement"]["overall"],
    grade["2012"]["achievement"]["read"] - grade["2010"]["achievement"]["read"],
    grade["2012"]["achievement"]["math"] - grade["2010"]["achievement"]["math"],
    grade["2012"]["achievement"]["write"] - grade["2010"]["achievement"]["write"],
    grade["2012"]["achievement"]["science"] - grade["2010"]["achievement"]["science"],
    # Because going down is better, we reverse it so that it is positive
    # This is VERY VERY important as reversing that will screw up the sign and
    # since we normalize with max(abs(rank_data)), which is positive,
    # a negative value will screw up the calculation.
    grade["2010"]["rank"] - grade["2012"]["rank"],
    mean((grade["2012"]["growth"]["overall"], grade["2011"]["growth"]["overall"], grade["2010"]["growth"]["overall"])),
    mean((grade["2012"]["growth"]["read"], grade["2011"]["growth"]["read"], grade["2010"]["growth"]["read"])),
    mean((grade["2012"]["growth"]["math"], grade["2011"]["growth"]["math"], grade["2010"]["growth"]["math"])),
    mean((grade["2012"]["growth"]["write"], grade["2011"]["growth"]["write"], grade["2010"]["growth"]["write"]))
  ))

def normalize_vectors(vectors):
  """Normalize each entry of the vectors to from -1 to 1"""
  entry_max = [0 for i in xrange(10)]
  for vector in vectors:
    for i in xrange(10):
      if abs(vector[i]) > entry_max[i]:
        entry_max[i] = abs(vector[i])

  normalized_vectors = []
  for vector in vectors:
    a = [vector[i] / entry_max[i] for i in xrange(10)]
    normalized_vectors.append(np.array(a))

  return normalized_vectors

def find_neighbours(query_location, vectors, k=None):
  """Find nearest neighbour, if k is None then find all neighbours at
  ascending distances.

  Algorithm is O(nlogn) from O(n+nlogn) which is going through everything and
  sorting. The k is just a slice at the end. This is a bruteforce algorithm

  Since this function is offline, it doesn't really matter and our data set is
  not humongous.

  Returns:
    [(index, distance)]"""

  if k is None:
    k = len(vectors)

  d = []
  for i, vector in enumerate(vectors):
    d.append((i, np.linalg.norm(query_location - vector)))

  d.sort(key=lambda x: x[1])
  return d[:k]

def get_id_level(id, grade):
  """Shortcut function to get the id of the school (real) and its level"""
  _temp = id.split("-")
  real_id = _temp[0]
  if len(_temp) > 1:
    level = _temp[1]
  else:
    level = grade.get("2012", grade.get("2011", grade.get("2010", {}))).get("level")

  return real_id, level

if __name__ == "__main__":
  with open("schools/grades.json") as f:
    grades = json.load(f)

  # Just to keep track and see how many schools are actually included in the analysis.
  total = {"H": 0, "M": 0, "E": 0}
  valid = {"H": 0, "M": 0, "E": 0}

  vectors = []
  ids = []

  for id, grade in grades.iteritems():
    real_id, level = get_id_level(id, grade)
    amt = total.get(level, 0)
    total[level] = amt + 1

    if level in ("E", "M", "H") and is_school_valid(grade):
      valid[level] += 1
      vectors.append(build_vector(grade))
      ids.append(id)

  normalized_vectors = normalize_vectors(vectors)

  # This is the maximum possible score that any school can score in terms of
  # most improved. If we find the schools that are closest in the 10D space,
  # it will be the best in terms of improvements.
  perfect_most_improved = np.ones(10)
  improved = find_neighbours(perfect_most_improved, normalized_vectors)
  improved = [(ids[i], distance) for i, distance in improved]

  print "valid:", valid
  print "total:", total

  with open("analysis/mostimproved.json", "w") as f:
    json.dump({"improved": improved}, f, indent=4, separators=(",", ": "))