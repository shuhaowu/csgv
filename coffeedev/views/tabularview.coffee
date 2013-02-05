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

exports = namespace "views.tabularview"
require "views.boringview"
require "utils"

class TabularView extends views.boringview.BoringView
  tagName: "div"

  template_name: "tabularview.html"

  events:
    "click a.year-switcher": "on_switch_clicked"
    "click a.level-switcher": "on_switch_clicked"
    "click a.open-details" : "on_open_details_clicked"

  initialize: () ->
    super()
    @app = @options.app
    @datacache = {}
    @details_view = new views.detailsview.DetailsView({app: @app, tabularview: @})
    @details_view.load_template()

  on_open_details_clicked: (e) ->
    e.preventDefault()
    @details_view.show($(e.target).attr("data-id"), $("#details-view", @el))

  switch: (mode) ->
    do_switching = _.bind(((data) ->

      @datatable.removeRows(0, @datatable.getNumberOfRows())
      @datatable.addRows((row.slice(1, row.length) for row in data))

      # Must be before sort
      for i in [0..@datatable.getNumberOfRows()-1]
        v = @datatable.getValue(i, 0)
        html = "<a href=\"#\" class=\"open-details\" data-id=\"#{data[i][0]}\">#{v}</a>"
        @datatable.setFormattedValue(i, 0, html)


      @datatable.sort([{column: 7, desc: false}])

      percentformatter = new utils.PercentFormatter()
      percentformatter.format(@datatable, 2)
      percentformatter.format(@datatable, 3)
      percentformatter.format(@datatable, 4)
      percentformatter.format(@datatable, 5)
      percentformatter.format(@datatable, 6)
      percentformatter.format(@datatable, 14)
      percentformatter.format(@datatable, 15)

      gradeformatter = new utils.GradeCurveFormatter()
      gradeformatter.format(@datatable, 8)
      gradeformatter.format(@datatable, 9)
      gradeformatter.format(@datatable, 10)
      gradeformatter.format(@datatable, 11)
      gradeformatter.format(@datatable, 12)
      gradeformatter.format(@datatable, 13)

      @table.draw(@datatable, {allowHtml: true, page: "enable", pageSize: 20})

      countp = $(document.createElement("p"))
      countp.addClass("pull-right")
      countp.text("Total Records: #{@datatable.getNumberOfRows()}")
      $(".google-visualization-table-div-page").append(countp)

      @app.navigate("tabular/#{mode}", {trigger: false})
      $(".level-switcher", @el).each((i, element) ->
        $(element).parent().removeClass("active")
        if $(element).attr("data-type") == mode[0]
          $(element).parent().addClass("active")
      )

      $(".year-switcher", @el).each((i, element) ->
        $(element).parent().removeClass("active")
        if $(element).text() == mode.slice(2, 6)
          $(element).parent().addClass("active")
      )
    ), this)

    if @datacache[mode]
      do_switching(@datacache[mode])
    else
      that = this
      statusmsg.display("Loading data...")
      request = $.getJSON("/tabular/#{mode}")
      request.done((data) ->
        that.datacache[mode] = data.data
        do_switching(data.data)
        statusmsg.close()
      )
      request.fail((xhr) ->
        statusmsg.close()
        statusmsg.display("Error loading page: #{xhr.status}", true)
      )

  on_switch_clicked: (e) ->
    e.preventDefault()
    current = @get_mode()
    if $(e.target).attr("class") == "level-switcher"
      mode = $(e.target).attr("data-type") + "/" + current.slice(2, 6)
    else
      mode = current[0] + "/" + $(e.target).text()
    @switch(mode)

  get_mode: () ->
    mode = ""
    $(".level-switcher", @el).each((i, element) ->
      if $(element).parent().hasClass("active")
        mode += $(element).attr("data-type")
        return false
    )
    mode += "/"
    $(".year-switcher", @el).each((i, element) ->
      if $(element).parent().hasClass("active")
        mode += $(element).text()
        return false
    )
    mode

  render: () ->
    @el.innerHTML = @template()

    mode = @get_mode()

    if not @datatable
      @datatable = new google.visualization.DataTable()
      @datatable.addColumn("string", "School")
      @datatable.addColumn("number", "Enrollment")
      @datatable.addColumn("number", "Asian")
      @datatable.addColumn("number", "Black")
      @datatable.addColumn("number", "Latino")
      @datatable.addColumn("number", "White")
      @datatable.addColumn("number", "Other")
      @datatable.addColumn("number", "Rank")
      @datatable.addColumn("number", "Grade")
      @datatable.addColumn("number", "Overall")
      @datatable.addColumn("number", "Reading")
      @datatable.addColumn("number", "Math")
      @datatable.addColumn("number", "Writing")
      @datatable.addColumn("number", "Science")
      @datatable.addColumn("number", "F.S.L.")
      @datatable.addColumn("number", "Grad Rate")

    @table = new google.visualization.Table(document.getElementById("tabular-data"))
    @delegateEvents()
    @

  on_view_change: () ->
    @undelegateEvents()

exports["TabularView"] = TabularView
