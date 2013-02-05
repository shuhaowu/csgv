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

require "views.mapview"
require "views.chartview"
require "views.tabularview"
require "views.htmlview"

# I'm sorry.
# This code sucks and it's not my fault!
# well... it is my fault as I wrote it.
# But i don't really want to rewrite this one time, 2 week long project.
# The only well written code here is under jsondb/mostimproved.py

$(document).ready(
  () ->
    statusmsg.setup()
    $.ajaxSetup(
      traditional: true
    )
    class App extends Backbone.Router
      routes:
        "": "display_map"
        "map" : "display_map"
        "map/:mode": "display_map"
        "map/details/:schoolid": "display_school_details_on_map"
        "tabular": "display_tabular"
        "tabular/:level/:year": "display_tabular"
        "p/:page": "display_page"
        "charts": "display_charts"
        "charts/:type": "display_charts"
        "charts/:type/:subtype": "display_charts"

      initialize: () ->
        @currentview = null
        @currentmode = null
        @mapview = new views.mapview.MapView({app: this})
        @chartview = new views.chartview.ChartView({app: this})
        @tabularview = new views.tabularview.TabularView({app: this})
        @htmlview = new views.htmlview.HtmlView()

        that = this
        nameslist = (k for k, v of window["SCHOOL_NAMES"])
        $(".search-query").typeahead(
          source: nameslist
          updater: (item) ->
            if that.currentview.search and window["SCHOOL_NAMES"][item]
              that.currentview.search(window["SCHOOL_NAMES"][item])

            item
        )

      switch_view: (page, view, mode) ->

        if @currentview and @currentview.on_view_change
          @currentview.on_view_change()

        @currentview = view
        @currentmode = mode

        $(".navbar .nav li").each((i) ->
          if $(this).attr("data-name") == page
            $(this).addClass("active")
          else
            if $(this).hasClass("active")
              $(this).removeClass("active")
        )

        if @currentview.search
          $(".search-query").show()
        else
          $(".search-query").hide()

      check_for_current_view: (view, mode) ->
        if @currentview != null and @currentview == view
          if @currentmode != mode
            @currentview.switch(mode)
            @currentmode = mode
            return 1 # Hack, but for page it is import lol
          return true
        return false

      wait_for_template_load: (view, on_template_load) ->
        statusmsg.display("Loading page...")

        if not view.template_request
          view.load_template()

        view.template_request.done(() ->
          on_template_load()
          statusmsg.close()
        )

        view.template_request.fail((xhr) ->
          statusmsg.close()
          statusmsg.display("Error loading page (#{xhr.status} #{xhr.statusText})", true)
        )

      display_tabular: (level="H", year="2012") ->
        mode = "#{level}/#{year}"

        if @check_for_current_view(@tabularview, mode)
          return

        render_tabularview = _.bind((() ->
          $("#main").empty().append(@tabularview.el) # TODO: haha, inconsistent style for rendering pages
          @tabularview.render()
          @tabularview.switch(mode)
          @switch_view("tabular", @tabularview, mode)
        ), this)

        @wait_for_template_load(@tabularview, render_tabularview)

      display_page: (page) ->
        status = @check_for_current_view(@htmlview, page)

        if status == 1
          @switch_view(page, @htmlview, page)
          return
        else if status
          return

        @htmlview.switch(page)
        $("#main").empty().append(@htmlview.el)
        @switch_view(page, @htmlview, page)

      display_map: (mode="default") ->
        if @check_for_current_view(@mapview, mode)
          return

        render_mapview = _.bind((() ->
          @mapview.render()
          @mapview.initialize_map(mode)
          @switch_view("map", @mapview, mode)
        ), this)

        @wait_for_template_load(@mapview, render_mapview)

      display_school_details_on_map: (schoolid) ->

        if @check_for_current_view(@mapview, @mapview.currentmode or "enrollment-default")
          @mapview.show_details(schoolid)
          return

        render_mapview_and_details = _.bind((() ->
          @mapview.render()
          @mapview.initialize_map("enrollment-default")
          @switch_view("map", @mapview, "enrollment-default")
          @mapview.show_details(schoolid)
        ), this)

        @wait_for_template_load(@mapview, render_mapview_and_details)

      display_charts: (type="onlinecharter", subtype="") ->
        if subtype
          mode = "#{type}/#{subtype}"
        else
          mode = type

        if @check_for_current_view(@chartview, mode)
          return

        render_chartview = _.bind((() ->
          @chartview.render()
          @chartview.switch(type, subtype)
          $("#main").empty().append(@chartview.el)
          @switch_view("charts", @chartview, mode)
        ), this)

        @wait_for_template_load(@chartview, render_chartview)

    app = new App()
    Backbone.history.start()
)
