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

exports = namespace "views.detailsview"
require "views.boringview"
require "utils"

# Is this the most hacked together code I have every written? In short, yes.
# The long answer? Definitely, yes.
# I don't think I care enough to make it better! I have a time limit and I
# discovered a major problem with my database... So...
# I am so sorry.


racemap =
  latino: "Hispanic/Latino"
  hawaii: "Hawaiian/Pacific Islander"
  indian: "American Indian/Alaskan Native"
  black: "African American"
  asian: "Asian"
  mixed: "2 or more"
  white: "White"

overallmodemap =
  rank: "Ranks"
  grades: "School Grades"
  achievements: ["Overall", "Reading", "Math", "Writing", "Science"]
  growth: ["Overall", "Reading", "Math", "Writing"]

overall_vaxis_label =
  rank: "Ranks"
  grades: "School Grades (1-13 is F to A+)"
  achievements: "Academic Achievement Grades (1-13 is F to A+)"
  growth: "Academic Growth Grades (1-13 is F to A+)"

overallsubtitlemap =
  rank: "Lower is better"
  grades: "Higher is better, max 13"
  achievements: "Higher is better, max 13"
  growth: "Higher is better, max 13, science data missing"

levelsmap =
  H: "As high school"
  M: "As middle school"
  E: "As elementary school"

arrow =
  "up": 1
  "flat": 0
  "down": -1

years = ["2010", "2011", "2012"]

class DetailsView extends views.boringview.BoringView

  tagName: "div"

  template_name: "detailsview.html"

  events:
    "click a.enrollment-switch": "switch_enrollment"
    "click a.overall-switch": "switch_overall"
    "mouseover #details-level-control a.btn": "level_control_hover"
    "click #details-level-control a.btn": "level_control_clicked"
    "click .similar-school-switcher" : "on_similar_school_swicher_clicked"

  initialize: () ->
    super()
    @app = @options.app
    @overall_chart = null
    @enrollment_chart = null

  on_similar_school_swicher_clicked: (e) ->
    e.preventDefault()
    @modal.modal("hide")
    if @options.mapview
      @options.mapview.search($(e.target).attr("data-id"))
    else if @options.tabularview
      @options.tabularview.search($(e.target).attr("data-id"))

  level_control_hover: (e) ->
    $(e.target).tooltip({title: "Schools have multiple levels. This is to view different levels.", placement: "bottom"})

  fit_modal_body: () ->
    if @showing and @modal
      header = $(".modal-header", @modal)
      body = $(".modal-body", @modal)

      modalheight = parseInt(@modal.css("height"))
      headerheight = parseInt(header.css("height")) + parseInt(header.css("padding-top")) + parseInt(header.css("padding-bottom"))
      bodypaddings = parseInt(body.css("padding-top")) + parseInt(body.css("padding-bottom"))

      height = modalheight - headerheight - bodypaddings - 5 # fudge factor

      body.css("max-height", "#{height}px")

  show: (id, modal) ->
    that = this
    statusmsg.display("Loading school details...")
    @template_request.done(() ->
      request = $.getJSON("/schools/details/#{id}", (data) ->
        data.meta.name = data.meta.name.toLowerCase()
        that.data = data
        that["id"] = id

        # Process the data into appropriate format
        # HACK HACK HACK!

        for level, d of that.data
          if level == "meta"
            continue

          rows = []
          for year_data in d["achievements"]
            if not year_data
              year_data = {}
            row = [year_data["overall"], year_data["read"], year_data["math"], year_data["write"], year_data["science"]]
            rows.push(row)

          d["achievements"] = rows

          rows = []
          for year_data in d["growth"]
            if not year_data
              year_data = {}
            row = [year_data["overall"], year_data["read"], year_data["math"], year_data["write"]]
            rows.push(row)

          d["growth"] = rows

          rows = []
          for year_data in d["coact"]
            if not year_data
              year_data = {}
            row = [year_data["read"], year_data["math"], year_data["write"], year_data["science"]]
            rows.push(row)

          d["coact"] = rows

          rows = []
          for i in [0..2]
            row = [arrow[d["achievementchange"][i]], arrow[d["growthchange"][i]], arrow[d["scorechange"][i]]]
            rows.push(row)

          d["change"] = rows


        l = []
        for level, whatever of that.data
          if level == "meta"
            continue
          l.push({code: level, title: levelsmap[level]})

        that.data["meta"]["level"] = l

        that.render()
        modal.append(that.el)

        modal.modal("show")
        modal.on("shown", () ->
          that.fit_modal_body()
          modal.off("shown") # Unbind this event
        )
        that.showing = true
        that.modal = modal
        modal.on("hide", _.bind(that.close, that))

        # see if we have a level in id
        _temp = id.split("-")
        if _temp.length > 1
          that.change_level(_temp[1])
        else
          # this calls draw, code is for the level code
          # omg. this code needs to be refactored.. BIG TIME.
          that.change_level(l[l.length-1].code)

        that.delegateEvents()
        $(window).resize((e) ->
          that.fit_modal_body()
        )
        statusmsg.close()
      )

      request.fail((jqxhr, textstatus) ->
        statusmsg.close()
        statusmsg.display("Error loading school details: #{jqxhr.status} #{textstatus}", true)
      )
    )

  draw_charts: (last=false) -> # Defaults?
    @draw_enrollment_chart(if last then @current_enrollment_year else "2012")
    @draw_overall_chart(if last then @current_overall_mode else "rank")
    @draw_change_table()
    @get_similar_schools()
    if @data["H"] and @data["H"].coact and @currentlevel == "H"
      @draw_coact_table()
      $(".interchangeable-panel", @el).show()
    else
      $(".interchangeable-panel", @el).hide()

  level_control_clicked: (e) ->
    e.preventDefault()
    @change_level($(e.target).attr("data-level"))

  change_level: (level) ->
    @currentlevel = level
    $("#details-level-control a.btn", @el).each((i, btn) ->
      if $(btn).removeClass("active").attr("data-level") == level
        $(btn).addClass("active")
    )
    @draw_charts(true)

  switch_enrollment: (event) ->
    event.preventDefault()
    @draw_enrollment_chart($(event.target).attr("data-year"))

  switch_overall: (event) ->
    event.preventDefault()
    @draw_overall_chart($(event.target).attr("data-type"))

  draw_overall_chart: (mode="rank") ->
    data = []

    if $.type(overallmodemap[mode]) != "array"
      c = [overallmodemap[mode]]
    else
      c = overallmodemap[mode]
    data = [["Year"].concat(c)]

    d = @data[@currentlevel]

    for i in [0..2]
      if $.type(d[mode][i]) != "array"
        c = [d[mode][i]]
      else
        c = d[mode][i]

      data.push([years[i]].concat(c))

    data = google.visualization.arrayToDataTable(data)

    if mode != "rank" # such a hack
      formatter = new utils.GradeCurveFormatter()

      for i in [1..data.getNumberOfColumns()-1]
        formatter.format(data, i)

    title = if c.length == 1 then overallmodemap[mode].toLowerCase() else overallmodemap[mode].join(", ").toLowerCase()
    options =
      title: "3 year #{title} (#{overallsubtitlemap[mode]})"
      width: 500
      height: 300
      chartArea:
        width: "80%"
        height: "75%"
      titleTextStyle:
        fontSize: 15
      legend:
        position: if c.length == 1 then "none" else "bottom"
      hAxis:
        title: "Year"
      vAxis:
        title: overall_vaxis_label[mode]
      interpolateNulls: true
      pointSize: 8

    @overall_chart = new google.visualization.LineChart(document.getElementById("overall-chart"))
    @overall_chart.draw(data, options)

    @switch_chart_control($("a.overall-switch", @el), "data-type", mode)
    @current_overall_mode = mode

  draw_enrollment_chart: (year="2012") ->
    data = [["Race", "Numbers"]]
    for race, number of @data["meta"]["enrollment"][year]
      if race == "total"
        continue
      else
        if number > 0
          data.push([racemap[race], number])

    data = google.visualization.arrayToDataTable(data)
    options =
      title: "#{year} enrollment statistics"
      width: 500
      height: 300
      chartArea:
        width: "100%"
        height: "80%"
      legend:
        position: "right"
      titleTextStyle:
        fontSize: 16

    @enrollment_chart = new google.visualization.PieChart(document.getElementById("enrollment-chart"))
    @enrollment_chart.draw(data, options)

    @switch_chart_control($("a.enrollment-switch"), "data-year", year)
    @current_enrollment_year = year

  switch_chart_control: (controls, attribute, current) ->
    controls.each((i, s) ->
      if $(s).removeClass("active").attr(attribute) == current
        $(s).addClass("active")
    )

  draw_change_table: () ->
    data = new google.visualization.DataTable()
    data.addColumn("string", "Year")
    data.addColumn("number", "Achievement Change")
    data.addColumn("number", "Growth Change")
    data.addColumn("number", "Score Change")
    rows = []
    for change, i in @data[@currentlevel].change
      rows.push([years[i]].concat(change))
    data.addRows(rows)

    data.sort({column: 0, desc: true})

    arrowformatter = new utils.BetterArrowFormatter()
    arrowformatter.format(data, 1)
    arrowformatter.format(data, 2)
    arrowformatter.format(data, 3)

    @change_table = new google.visualization.Table(document.getElementById("change-table"))
    @change_table.draw(data, {allowHtml: true})

  draw_coact_table: () ->
    $(".interchangeable-panel h4").text("COACT")
    $(".interchangeable-panel p small").text("These stats shows if the average student in the school have a 75% chance of earning a C or above in a corresponding college course.")
    data = new google.visualization.DataTable()
    data.addColumn("string", "Year")
    data.addColumn("boolean", "Reading")
    data.addColumn("boolean", "Math")
    data.addColumn("boolean", "Writing")
    data.addColumn("boolean", "Science")

    rows = []
    for coact, i in @data.H.coact
      rows.push([years[i]].concat(coact))

    data.addRows(rows)

    data.sort({column: 0, desc: true})

    booleanformatter = new utils.BooleanUnknownFormatter()
    booleanformatter.format(data, 1)
    booleanformatter.format(data, 2)
    booleanformatter.format(data, 3)
    booleanformatter.format(data, 4)

    @coact_table = new google.visualization.Table(document.getElementById("coact-table"))
    @coact_table.draw(data)

  get_similar_schools: () ->
    results = $.getJSON("/similar/#{@id}/#{@currentlevel}/grades")
    that = this
    results.done((data) ->
      if data.schools.length == 0
        $("#grades-similar", that.el).html("No similar schools found.")
      else
        dt = new google.visualization.DataTable()
        dt.addColumn("string", "Name")
        dt.addColumn("number", "Rank")
        dt.addColumn("number", "Grade")
        dt.addColumn("number", "Overall")
        dt.addColumn("number", "Reading")
        dt.addColumn("number", "Math")
        dt.addColumn("number", "Writing")
        dt.addColumn("number", "Science")

        rows = []
        for v in data.schools
          rows.push(v.data.slice(0, 8))

        dt.addRows(rows)

        if that.options.parent_can_search
          for i in [0..dt.getNumberOfRows()-1]
            v = dt.getValue(i, 0)
            html = "<a href=\"#\" class=\"similar-school-switcher\" data-id=\"#{data.schools[i].id}\">#{v}</a>"
            dt.setFormattedValue(i, 0, html)

        gradeformatter = new utils.GradeCurveFormatter()
        gradeformatter.format(dt, 2)
        gradeformatter.format(dt, 3)
        gradeformatter.format(dt, 4)
        gradeformatter.format(dt, 5)
        gradeformatter.format(dt, 6)
        gradeformatter.format(dt, 7)

        table = new google.visualization.Table($("#grades-similar", that.el)[0])

        table.draw(dt, {allowHtml: true})
        that.delegateEvents()
    )
    results.fail((xhr) ->
      $("#grades-similar", that.el).html("<h5 class=\"text-center\">Error: #{xhr.status}</h5>")
    )

    results = $.getJSON("/similar/#{@id}/#{@currentlevel}/enrollment")
    results.done((data) ->
      if data.schools.length == 0
        $("#enrollment-similar", that.el).html("No similar schools found.")
      else
        dt = new google.visualization.DataTable()
        dt.addColumn("string", "Name")
        dt.addColumn("number", "Enrollment")
        dt.addColumn("number", "Asian")
        dt.addColumn("number", "Black")
        dt.addColumn("number", "Latino")
        dt.addColumn("number", "White")

        rows = []
        for v in data.schools
          v.data[1] = Math.round(5000 * v.data[1]) # Because this will be a huge weight otherwise, we normalize it
          rows.push(v.data)

        dt.addRows(rows)

        if that.options.parent_can_search
          for i in [0..dt.getNumberOfRows()-1]
            v = dt.getValue(i, 0)
            html = "<a href=\"#\" class=\"similar-school-switcher\" data-id=\"#{data.schools[i].id}\">#{v}</a>"
            dt.setFormattedValue(i, 0, html)

        percentformatter = new utils.PercentFormatter()
        percentformatter.format(dt, 2)
        percentformatter.format(dt, 3)
        percentformatter.format(dt, 4)
        percentformatter.format(dt, 5)

        table = new google.visualization.Table($("#enrollment-similar", that.el)[0])

        table.draw(dt, {allowHtml: true})
        that.delegateEvents()
    )
    results.fail((xhr) ->
      $("#enrollment-similar", that.el).html("<h5 class=\"text-center\">Error: #{xhr.status}</h5>")
    )

  render: () ->
    # use defer with this to make sure everything loads!
    @el.innerHTML = @template(@data.meta)
    @

  close: () ->
    if @modal and @showing
      @showing = false
      @undelegateEvents()
      @modal.off("hide")
      $(window).off("resize") # FIXME: DANGER DANGER DANGER!!

      if @options.mapview
        @app.navigate("/map", {trigger: false})

      @current_enrollment_year = undefined
      @current_overall_mode = undefined

exports["DetailsView"] = DetailsView
