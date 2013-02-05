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

from math import e
# Data transformation functions, maybe memcache these due to the fact that
# they don't change and could be expensive.

def get_all_school_coordinates(school_metas):
  coordinates = {}
  for i, school in school_metas.iteritems():
    # Although the importer detects if the secondary source is not available,
    # the server needs to be as fast as we can get it to be, so we won't even
    # perform the O(1) operation of checking if `"coordinate" in school`
    coordinates[i] = school["coordinate"]

  return coordinates

def get_all_school_names(school_metas):
  names = {}
  for i, school in school_metas.iteritems():
    names[school["name"].title()] = i

  return names

def get_enrollment(school_metas, year, attribute):
  e = {}
  for i, school in school_metas.iteritems():
    if "enrollment" in school and year in school["enrollment"]:
      e[i] = school["enrollment"][year][attribute]
  return e

def map_data_multiple(data, ms):
  l = len(ms)
  results = [[] for i in xrange(l)]
  for k, v in data:
    for i in xrange(l):
      value = ms[i](k, v)
      if value:
        results[i].append(value)

  return results

def in_viewport(topright, bottomleft, point):
  return bottomleft[0] < point[0] < topright[0] and bottomleft[1] < point[1] < topright[1]

def school_big_enough(enrollment, zoomlevel):
  if zoomlevel >= 13:
    return True
  else:
    return enrollment > (3500 // (1 + e**(zoomlevel-9)))

def get_ranks_list(schools, year):
  ranks = {"H": [], "M": []}
  for i, school in schools.iteritems():
    info = school.get(year)
    if info:
      rank = info.get("rank")
      level = info.get("level")
      if rank and level in ("E", "M", "H"):
        if level == "H":
          ranks["H"].append((i, rank))
        else:
          ranks["M"].append((i, rank))
  get_rank = lambda x: x[1]
  ranks["H"].sort(key=get_rank)
  ranks["M"].sort(key=get_rank)
  return ranks

def get_schools_within_viewport(schools, criteria, data, topright, bottomleft, zoomlevel, schoolsmeta):
  s = {}
  for i, school in schools.iteritems():
    _temp = i.split("-") # hack hack hck!
    if len(_temp) > 1:
      i = _temp[0]
    if criteria(school) and in_viewport(topright, bottomleft, schoolsmeta[i]["coordinate"]):
      d = data(school)
      if d == "skipme": # HACK ALERT!
        continue
      s[i] = d

  return s
