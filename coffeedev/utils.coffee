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

exports = namespace "utils"

class BetterArrowFormatter
  constructor: (options={}) ->
    @base = options.base or 0
    @uparrow = options.uparrow or "/static/img/uparrow.png"
    @downarrow = options.downarrow or "/static/img/downarrow.png"
    @flat = options.flat or "/static/img/flat.png"

  format: (dt, column) ->
    for i in [0..dt.getNumberOfRows()-1]
      v = dt.getValue(i, column)
      if v > @base
        arrow = @uparrow
      else if v < @base
        arrow = @downarrow
      else
        arrow = @flat

      html = "<img src=\"#{arrow}\" />"
      dt.setFormattedValue(i, column, html)

# Writing like Java!
# Kinda sickening.
# I understand that you can use another way to do this, but since the entire
# google visualization/map api looks like Java, why don't we join the party?

# Just realized this, doing this means that everytime i format more than 1 column,
# I'm running through every row that many times.

class BooleanUnknownFormatter
  constructor: (options={}) ->
    @yes = options.yes or "&#x2713;"
    @no = options.no or "&#x2717;"
    @unknown = options.unknown or "Unknown"

  format: (dt, column) ->
    for i in [0..dt.getNumberOfRows()-1]
      v = dt.getValue(i, column)
      if v == true
        fv = @yes
      else if v == false
        fv = @no
      else if v == null or v == undefined
        fv = @unknown
      else
        throw "Error: BooleanUnknown can only be true, false, null, or undefined!"

      dt.setFormattedValue(i, column, fv)

class PercentFormatter
  constructor: (options={}) ->
    @precision = options.precision or 3

  format: (dt, column) ->
    for i in [0..dt.getNumberOfRows()-1]
      v = dt.getValue(i, column)
      if v or v == 0
        v *= 100
        v = v.toPrecision(@precision)
        dt.setFormattedValue(i, column, "#{v}%")
      else
        dt.setFormattedValue(i, column, "N/A")


class GradeCurveFormatter

  mapper: ["Error", "F", "D-", "D", "D+", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A+"]

  format: (dt, column) ->
    for i in [0..dt.getNumberOfRows()-1]
      v = dt.getValue(i, column)
      dt.setFormattedValue(i, column, @mapper[v])

exports["BetterArrowFormatter"] = BetterArrowFormatter
exports["BooleanUnknownFormatter"] = BooleanUnknownFormatter
exports["PercentFormatter"] = PercentFormatter
exports["GradeCurveFormatter"] = GradeCurveFormatter
