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

exports = namespace "views.chartview"
require "views.boringview"

charter_online_readable_map =
  H:
    both: "Charter and online high schools"
    charter: "Charter high schools"
    online: "Online high schools"
    neither: "Traditional high schools"
    everything: "All high schools"

  M:
    both: "Charter and online elementary/middle schools"
    charter: "Charter elementary/middle schools"
    online: "Online elementary/middle schools"
    neither: "Traditional elementary/middle schools"
    everything: "All elementary/middle schools"


# This file is a mess. IT needs to be massively refactored

class MeanRanksPanel
  constructor: (data, panel) ->
    @panel = panel
    @data = data

    # We transform the data by converting the data to relative form.
    # Reason: easier comparison
    rows = []
    for year in ["2010", "2011", "2012"]
      current_row = [year]
      rows.push(current_row)
      for level in ["H", "M"]
        for type in ["charter", "online", "both", "neither"]
          meanrank = data["mean_rank"][level][type][year]
          maxrank = data["maxranks"][level][type][year]
          if meanrank != null and maxrank != null
            # max + 1 - rank < this flips a rank of 1 to max and vice versa.
            current_row.push(Math.round((maxrank + 1 - meanrank) / maxrank * 1000)/10)
          else
            current_row.push(null)


    @datatable = new google.visualization.DataTable()
    @datatable.addColumn("string", "Year")
    @datatable.addColumn("number", "Charter High Schools")
    @datatable.addColumn("number", "Online High Schools")
    @datatable.addColumn("number", "Charter & Online High Schools")
    @datatable.addColumn("number", "Tradition High Schools")
    @datatable.addColumn("number", "Charter Middle/Elementary Schools")
    @datatable.addColumn("number", "Online Middle/Elementary Schools")
    @datatable.addColumn("number", "Charter & Online Middle/Elementary Schools")
    @datatable.addColumn("number", "Tradition Middle/Elementary Schools")
    @datatable.addRows(rows)

    @chart = new google.visualization.LineChart(@panel[0])
    @panel.empty()
    @redraw()

    @resize_event_callback = _.bind(@redraw, this)
    $(window).on("resize", @resize_event_callback)

  unhook_events: () ->
    $(window).off("resize", @resize_event_callback)

  redraw: () ->
    options =
      title: "Online, charter, traditional schools vs their mean ranks"
      width: parseInt(@panel.css("width"))
      height: 300
      chartArea:
        width: "60%"
        height: "80%"
      titleTextStyle:
        fontSize: 15
      legend:
        position: "right"
      hAxis:
        title: "Year"
      vAxis:
        title: "Mean Ranks"
      interpolateNulls: true
      pointSize: 8
    @chart.draw(@datatable, options)

class RanksHistogramPanel
  constructor: (data, panel) ->
    @data = data
    @panel = panel

    @currentyear = "2012"
    @currentlevel = "H"
    @currenttype = "everything"
    @lastyear = null
    @lastlevel = null
    @lasttype = null

    @datatable = new google.visualization.DataTable()
    @datatable.addColumn("string", "Range")
    @datatable.addColumn("number", "Count")

    @panel.empty()

    @controlarea = $(document.createElement("div"))
    @panel.append(@controlarea)
    @chartarea = $(document.createElement("div"))
    @panel.append(@chartarea)

    @chart = new google.visualization.ColumnChart(@chartarea[0])

    that = this
    @controlarea.load("/static/chartview/onlinecharterhistogram.html?"+Math.random(), () ->
      $("a.dropdown-toggle", that.controlarea).dropdown()
      $("a.online-charter-histogram-switch", that.controlarea).on("click", (e) ->
        e.preventDefault()

        d = $(this).attr("data-data")
        that["current"+$(this).attr("data-what")] = d

        $("a.online-charter-histogram-switch", $(this).parent().parent()).each((i, a) ->
          $(a).parent().removeClass("active")
          if $(a).attr("data-data") == d
            $(a).parent().addClass("active")
        )
        that.redraw()
      )
    )
    @redraw()
    @navbar_buttons = []

    $(document.createElement("a")).addClass("btn")

    @resize_event_callback = _.bind(@redraw, this)
    $(window).on("resize", @resize_event_callback)

  unhook_events: () ->
    $(window).off("resize", @resize_event_callback)
    $("a.online-charter-histogram-switch", @controlarea).off("click")

  redraw: () ->
    if @currentyear != @lastyear or @currentlevel != @lastlevel or @currenttype != @lasttype
      @lastyear = @currentyear
      @lastlevel = @currentlevel
      @lasttype = @currenttype

      rows = []
      histogram = @data["histogram"][@currentlevel][@currenttype][@currentyear][0]
      bins = @data["histogram"][@currentlevel][@currenttype][@currentyear][1]
      for v, i in histogram
        if i < histogram.length-1
          bin_label = Math.round(bins[i]) + "-" + Math.round(bins[i+1])
        else
          bin_label = Math.round(bins[i]) + "+"
        rows.push([bin_label, v])

      @datatable.removeRows(0, @datatable.getNumberOfRows())
      @datatable.addRows(rows)

      options =
        title: "#{charter_online_readable_map[@currentlevel][@currenttype]} rank histogram"
        width: parseInt(@panel.css("width"))
        height: 300
        chartArea:
          width: "80%"
          height: "80%"
        bar:
          groupWidth: "100%"
        titleTextStyle:
          fontSize: 15
        legend:
          position: "none"
        hAxis:
          title: "Ranks"
        vAxis:
          title: "Count"

      @chart.draw(@datatable, options)

class OnlineCharterTablePanel
  constructor: (data, panel) ->
    @data = data
    @panel = panel

    heading1 = $(document.createElement("h4")).text("Mean Ranks (High Schools)")
    highschool_meanranksdiv = $(document.createElement("div"))
    heading2 = $(document.createElement("h4")).text("Mean Ranks (Elementary/Middle Schools)")
    emschool_meanranksdiv = $(document.createElement("div"))
    heading3 = $(document.createElement("h4")).text("Number of high schools in each category")
    highschool_amountdiv = $(document.createElement("div"))
    heading4 = $(document.createElement("h4")).text("Number of elementary/middle schools in each category")
    em_amountdiv = $(document.createElement("div"))
    @panel.empty()
    @panel.append(heading1).append(highschool_meanranksdiv).append(heading2).append(emschool_meanranksdiv).append(heading3).append(highschool_amountdiv).append(heading4).append(em_amountdiv)

    @highschool_ranks_datatable = new google.visualization.DataTable()
    @highschool_ranks_datatable.addColumn("string", "Year")
    @highschool_ranks_datatable.addColumn("number", "Charter")
    @highschool_ranks_datatable.addColumn("number", "Online")
    @highschool_ranks_datatable.addColumn("number", "Charter and Online")
    @highschool_ranks_datatable.addColumn("number", "Traditional")
    @highschool_ranks_datatable.addColumn("number", "All")

    @emschool_ranks_datatable = new google.visualization.DataTable()
    @emschool_ranks_datatable.addColumn("string", "Year")
    @emschool_ranks_datatable.addColumn("number", "Charter")
    @emschool_ranks_datatable.addColumn("number", "Online")
    @emschool_ranks_datatable.addColumn("number", "Charter and Online")
    @emschool_ranks_datatable.addColumn("number", "Traditional")
    @emschool_ranks_datatable.addColumn("number", "All")

    @highschool_amount_datatable = new google.visualization.DataTable()
    @highschool_amount_datatable.addColumn("string", "Year")
    @highschool_amount_datatable.addColumn("number", "Charter")
    @highschool_amount_datatable.addColumn("number", "Online")
    @highschool_amount_datatable.addColumn("number", "Charter and Online")
    @highschool_amount_datatable.addColumn("number", "Traditional")
    @highschool_amount_datatable.addColumn("number", "All")

    @emschool_amount_datatable = new google.visualization.DataTable()
    @emschool_amount_datatable.addColumn("string", "Year")
    @emschool_amount_datatable.addColumn("number", "Charter")
    @emschool_amount_datatable.addColumn("number", "Online")
    @emschool_amount_datatable.addColumn("number", "Charter and Online")
    @emschool_amount_datatable.addColumn("number", "Traditional")
    @emschool_amount_datatable.addColumn("number", "All")

    for year in ["2012", "2011", "2010"]
      hrrow = [year] # High school ranks
      emrrow = [year] # E/M school ranks
      harow = [year] # High school amounts
      emarow = [year] # E/M school amounts
      for level in ["charter", "online", "both", "neither", "everything"]
        hrrow.push(Math.round(@data["mean_rank"]["H"][level][year] * 10) / 10)
        emrrow.push(Math.round(@data["mean_rank"]["M"][level][year] * 10) / 10)
        harow.push(@data["amount"]["H"][level][year])
        emarow.push(@data["amount"]["M"][level][year])

      @highschool_ranks_datatable.addRows([hrrow])
      @emschool_ranks_datatable.addRows([emrrow])
      @highschool_amount_datatable.addRows([harow])
      @emschool_amount_datatable.addRows([emarow])

    @highschool_ranks_table = new google.visualization.Table(highschool_meanranksdiv[0])
    @emschool_ranks_table = new google.visualization.Table(emschool_meanranksdiv[0])
    @highschool_amount_table = new google.visualization.Table(highschool_amountdiv[0])
    @emschool_amount_table = new google.visualization.Table(em_amountdiv[0])

    options =
      width: "100%"
    @highschool_ranks_table.draw(@highschool_ranks_datatable, options)
    @emschool_ranks_table.draw(@emschool_ranks_datatable, options)
    @highschool_amount_table.draw(@highschool_amount_datatable, options)
    @emschool_amount_table.draw(@emschool_amount_datatable, options)

class FRLRawScatterPanel
  constructor: (data, panel) ->
    @data = data
    @panel = panel

    @panel.empty()
    @controlarea = $(document.createElement("div"))
    @chartarea = $(document.createElement("div"))
    @panel.append(@controlarea).append(@chartarea)

    that = this
    @controlarea.load("/static/chartview/frlrawscatterctrl.html?"+Math.random(), () ->
      that.switch_nav()
      $(".nav-pills a", that.controlarea).click((e) ->
        e.preventDefault()
        that.currentyear = $(this).text()
        that.redraw()
      )
    )

    @datatable = new google.visualization.DataTable()
    @datatable.addColumn("number", "FRL")
    @datatable.addColumn("number", "Grades")

    @chart = new google.visualization.ScatterChart(@chartarea[0])

    @currentyear = "2012"
    @lastyear = null

    @redraw()

    @resize_event_callback = _.bind(@redraw, this)
    $(window).on("resize", @resize_event_callback)

  unhook_events: () ->
    $(window).off("resize", @resize_event_callback)

  switch_nav: () ->
    that = this
    $(".nav-pills a", @controlarea).each((i, e) ->
      $(e).parent().removeClass("active")
      if $(e).text() == that.currentyear
        $(e).parent().addClass("active")
    )

  redraw: () ->
    if @currentyear != @lastyear
      rows = []
      for d in @data["frl_to_grades"][@currentyear]
        rows.push([d[1], d[2]])

      @datatable.removeRows(0, @datatable.getNumberOfRows())
      @datatable.addRows(rows)

      gradecurveformatter = new utils.GradeCurveFormatter()
      gradecurveformatter.format(@datatable, 1)

      percentformatter = new utils.PercentFormatter()
      percentformatter.format(@datatable, 0)

      @lastyear = @currentyear
      @switch_nav()

    options =
      title: "#{@currentyear} free/subsidised lunch percentage vs grades"
      width: parseInt(@panel.css("width"))
      height: 400
      chartArea:
        width: "80%"
        height: "80%"
      bar:
        groupWidth: "100%"
      titleTextStyle:
        fontSize: 15
      legend:
        position: "none"
      hAxis:
        title: "Percent of the students of a school with free/subsidised lunch"
      vAxis:
        title: "School grade (higher is better)"

    @chart.draw(@datatable, options)


class MostImprovedTablePanel
  constructor: (data, panel) ->
    @data = data
    @panel = panel
    @panel.empty()

    @datatable = new google.visualization.DataTable()
    @datatable.addColumn("string", "School")
    @datatable.addColumn("string", "District")
    @datatable.addColumn("string", "City")
    @datatable.addColumn("number", "2010 Enrollment")
    @datatable.addColumn("number", "2012 Enrollment")
    @datatable.addColumn("number", "2010 Rank")
    @datatable.addColumn("number", "2012 Rank")
    @datatable.addColumn("number", "Index")

    @datatable.addRows((d.slice(1, d.length) for d in @data))

    for i in [0..@datatable.getNumberOfRows()-1]
      v = @datatable.getValue(i, 0)
      @datatable.setFormattedValue(i, 0, "<a href=\"\" class=\"school-details\" data-id=\"#{@data[i][0]}\">#{v}</a>")

    options =
      width: "100%"
      allowHtml: true
      page: "enable"

    @table = new google.visualization.Table(@panel[0])
    @table.draw(@datatable, options)

    google.visualization.events.addListener(@table, "page", _.bind(@hook_school_details, this))
    google.visualization.events.addListener(@table, "sort", _.bind(@hook_school_details, this))

    @details_view = new views.detailsview.DetailsView({app: @app, tabularview: @})
    @details_view.load_template()

    @hook_school_details()

  hook_school_details: () ->
    $("a.school-details", @panel).click(_.bind(((e) ->
      e.preventDefault()
      @details_view.show($(e.target).attr("data-id"), $("#details-view"))
    ), this))

  unhook_events: () ->
    $("a.school-details").off("click")
    google.visualization.events.removeAllListeners(@table)


class ChartView extends views.boringview.BoringView
  tagName: "div"
  template_name: "chartview.html"

  render: () ->
    @el.innerHTML = @template()
    @

  loading: (panel) ->
    panel.empty()

    loadingbar = $(document.createElement("div")).attr("id", "loading-bar")
    loadingbar.append($(document.createElement("img")).attr("src", "/static/img/ajax-loader.gif"))
    panel.append(loadingbar)
    panel.show()

  loading_failed: (panel, reason) ->
    panel.empty()

    loadingfailure = $(document.createElement("h3")).addClass("text-center").text("Loading Failed #{reason}")
    panel.append(loadingfailure)

  add_row_span10: () ->
    row = $(document.createElement("div")).addClass("row")
    span10 = $(document.createElement("div")).addClass("span10")
    well = $(document.createElement("div")).attr("class", "well chartpanel")
    span10.append(well)
    row.append(span10)
    $(".span10.content", @el).append(row)
    well

  render_onlinecharter: () ->
    @render()

    first = $(".firstmiddle", @el)
    second = $(".secondmiddle", @el)
    third = $(".thirdmiddle", @el)
    fourth = @add_row_span10()

    @loading(first)
    @loading(second)
    @loading(third)
    @loading(fourth)
    first.load("/static/chartview/onlinecharter.html?"+Math.random())

    response = $.getJSON("/charts/online_charter")
    response.done(_.bind(((data) ->
      @mean_ranks_panel = new MeanRanksPanel(data, second)
      @ranks_histogram_panel = new RanksHistogramPanel(data, third)
      @ranks_table_panel = new OnlineCharterTablePanel(data, fourth)
    ), this))

    response.fail(_.bind(((xhr) ->
      @loading_failed(second, xhr.status)
      @loading_failed(third, xhr.status)
      @loading_failed(fourth, xhr.status)
    ), this))

  render_frl: () ->
    @render()

    first = $(".firstmiddle", @el)
    second = $(".secondmiddle", @el)
    @loading(first)
    @loading(second)

    response = $.getJSON("/charts/frl")
    response.done(_.bind(((data) ->
      @frl_scatter_panel = new FRLRawScatterPanel(data, second)
    ), this))

    response.fail(_.bind(((xhr) ->
      @loading_failed(second, xhr.status)
    ), this))

    first.load("/static/chartview/moneyvsgrades.html?"+Math.random())

  render_improved: () ->
    @render()

    first = $(".firstmiddle", @el)
    second = $(".secondmiddle", @el)

    @loading(first)
    @loading(second)

    first.load("/static/chartview/improved.html?"+Math.random())

    response = $.getJSON("/charts/improved")
    that = this
    response.done((data) ->
      that.most_improved_table_panel = new MostImprovedTablePanel(data, second)
    )

    response.fail((xhr) ->
      that.loading_failed(second, xhr.status)
    )

  switch: (mode) ->
    @["render_"+mode]()
    $(".nav.nav-list a", @el).each((i, element) ->
      $(element).parent().removeClass("active")
      if $(element).attr("href").split("/")[1] == mode
        $(element).parent().addClass("active")
    )

    @unhook_panel_events()

  unhook_panel_events: () ->
    if @mean_ranks_panel
      @mean_ranks_panel.unhook_events()

    if @ranks_histogram_panel
      @ranks_histogram_panel.unhook_events()

    if @frl_scatter_panel
      @frl_scatter_panel.unhook_events()

    if @most_improved_table_panel
      @most_improved_table_panel.unhook_events()

  on_view_changed: () ->
    @undelegateEvents()
    @unhook_panel_events()



exports["ChartView"] = ChartView
