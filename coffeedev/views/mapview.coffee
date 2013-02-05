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

exports = namespace "views.mapview"
require "views.boringview"
require "views.detailsview"

# reverse of the server calculations
zoomlevel_enrollment = (enrollment) ->
  Math.ceil(Math.log(3500.0 / enrollment - 1) + 9)

GRADIENT = [
  'rgba(0, 255, 255, 0)',
  'rgba(0, 255, 255, 1)',
  'rgba(0, 191, 255, 1)',
  'rgba(0, 127, 255, 1)',
  'rgba(0, 63, 255, 1)',
  'rgba(0, 0, 255, 1)',
  'rgba(0, 0, 223, 1)',
  'rgba(0, 0, 191, 1)',
  'rgba(0, 0, 159, 1)',
  'rgba(0, 0, 127, 1)',
  'rgba(63, 0, 91, 1)',
  'rgba(127, 0, 63, 1)',
  'rgba(191, 0, 31, 1)',
  'rgba(255, 0, 0, 1)'
]

jQuery ->
  class MapView extends views.boringview.BoringView

    el: $("div#main")

    template_name: "mapview.html"

    initialize: () ->
      super()
      @app = @options.app
      @details_view = new views.detailsview.DetailsView({app: @app, mapview: @, parent_can_search: true})
      @details_view.load_template()
      @infowindow = null

    search_show_info_window: (id) ->
      @_enrollment_search_tries = 0
      show_info_window = _.bind((() ->
        console.log "waiting.."
        if @_enrollment_search_tries > 600 # 60 seconds and still? Wow
          statusmsg.display("Something went wrong while trying to find school #{id}", true)
          return

        @_enrollment_search_tries++
        if not @all_markers[id] and not @all_markers[id+"-E"] and not @all_markers[id+"-M"] and not @all_markers[id+"-H"]
          setTimeout(show_info_window, 100)
        else
          console.log @_enrollment_search_tries
          @_enrollment_search_tries = 0
          @show_info_window(id)

      ), this)

      show_info_window()

    enrollment_search: (id) ->
      statusmsg.display("Loading...")
      if coordinate = window["SCHOOL_COORDINATES"][id]
        latlng = new google.maps.LatLng(coordinate[0], coordinate[1])
        @map.setCenter(latlng)
        zoomlevel = zoomlevel_enrollment(window["SCHOOL_ENROLLMENTS"][id])
        @map.setZoom(zoomlevel)

        @search_show_info_window(id)

    rank_search: (id) ->
      if coordinate = window["SCHOOL_COORDINATES"][id]
        latlng = new google.maps.LatLng(coordinate[0], coordinate[1])
        @map.setCenter(latlng)
        # We get zoom level from the server because we can.
        # Also because we don't have the rank data trololol.
        response = $.get("/reverserank/#{id}")
        that = this
        response.done((data) ->
          zoomlevel = Number(data)
          that.map.setZoom(zoomlevel)
          that.search_show_info_window(id)
        )
        response.fail((xhr) ->
          if xhr.status == 400
            statusmsg.display("That school doesn't have a rank. You could search it in enrollment view", true)
          else
            statusmsg.display("Something went wrong. This is a bug: #{xhr.status}")
        )


    search: (id) ->
      if @currentmode == "enrollment-heat"
        @switch("enrollment-default", _.bind((() ->
          @enrollment_search(id)
        ), this))
      else if @currentmode in ["enrollment-default", "default"]
        @enrollment_search(id)
      else if @currentmode == "rank-default"
        @rank_search(id)
      else
        statusmsg.display("Cannot search under this mode!", true)

    on_template_loaded: () ->
      if not @school_info_window_template
        root = document.createElement("div")
        root.innerHTML = @rawtemplate

        root.style.display = "none" # Some hacks to get the html

        templates = ["info_window_template"]

        document.body.appendChild(root)

        for id in templates
          node = document.getElementById(id)
          this[id] = Handlebars.compile(node.innerHTML)
          root.removeChild(node)

        @template = Handlebars.compile(root.innerHTML)

        root.parentNode.removeChild(root)

    events:
      "click #mapcontrols .mapnav" : "on_mapnav_clicked"

    initialize_map: (mode, lat=39.070379, lng=-105.545654, zoom=7) ->
      options =
        zoom: zoom
        center: new google.maps.LatLng(lat, lng)
        mapTypeId: google.maps.MapTypeId.ROADMAP

      @map = new google.maps.Map(document.getElementById("mapcanvas"), options)
      @currentmode = "enrollment-default"
      @last_bounds_change = 0
      @all_markers = {}

      @marker_image_em = new google.maps.MarkerImage("/static/img/school.png",
        new google.maps.Size(32, 37),
        new google.maps.Point(0, 0),
        new google.maps.Point(16, 0)
      )

      @marker_image_high = new google.maps.MarkerImage("/static/img/highschool.png",
        new google.maps.Size(32, 37),
        new google.maps.Point(0, 0),
        new google.maps.Point(16, 0)
      )

      @switch(mode or "default")

    show_info_window: (schoolid, marker=@all_markers[schoolid] or @all_markers[schoolid+"-E"] or @all_markers[schoolid+"-M"] or @all_markers[schoolid+"-H"], statusbox=true) ->
      if statusbox
        statusmsg.display("Loading...")
      $.getJSON("/schools/info/#{schoolid}", _.bind(((data) ->
        onlinecharter = ""

        if data["online"] and data["charter"]
          onlinecharter = "Online & Charter"
        else if data["online"]
          onlinecharter = "Online"
        else if data["charter"]
          onlinecharter = "Charter"
        else
          onlinecharter = "Neither"

        if not data["level"]
          level = "Unknown"
        else
          if data["level"]["elementary"]
            level = ", Elementary"

          if data["level"]["middle"]
            level = ", Intermediate"

          if data["level"]["high"]
            level = ", Secondary"

          level = level.slice(2, level.length)

        if @infowindow
          @infowindow.close()

        @infowindow = new google.maps.InfoWindow(
          content: @info_window_template(
            name: data["name"].toLowerCase()
            address: (data["address"] + ", " + data["city"]).toLowerCase() + ", CO " + data["zipcode"]
            onlinecharter: onlinecharter
            level: level
            enrollment: data["enrollment"]["2012"]["total"]
            rank: data["rank"]
            id: schoolid
            frl: Math.round(data["frl"][2] * 1000) / 10 + "%"
          )
        )

        @infowindow.open(@map, marker)
        statusmsg.close()
      ), this))

    redraw_schools: (schools, marker_icon) ->

      all_markers = {}
      $("#map-status").text("Redrawing...")

      totalnum = 0
      for id, data of schools

        if data["real_id"]
          coordinate = window["SCHOOL_COORDINATES"][data["real_id"]]
        else
          coordinate = window["SCHOOL_COORDINATES"][id]
        latlng = new google.maps.LatLng(coordinate[0], coordinate[1])

        icon = if typeof(marker_icon) == "function" then marker_icon(data) else marker_icon

        if id of @all_markers
          marker = @all_markers[id]
          delete @all_markers[id] # what's let will be the markers that no longer is on the map
        else
          marker = new google.maps.Marker(
            position: latlng
            map: @map
            icon: icon
          )

          that = this

          ((schoolid, marker) ->
            google.maps.event.addListener(marker, "click", () ->
              that.show_info_window(schoolid, marker)
            )
          )(id, marker)

        all_markers[id] = marker
        totalnum++

      @marker_cleanup()

      @all_markers = all_markers

      $("#map-status").text(totalnum)

    marker_cleanup: () ->
      for id, marker of @all_markers
        marker.setMap(null)
        google.maps.event.clearListeners(marker, "click")

      @all_markers = {}

    heat_cleanup: () ->
      if @heatmap
        @heatmap.setMap(null)
        @heatmap = null

    on_mapnav_clicked: (event) ->
      # This is such a hack!
      # So sue me.
      #
      # Actually don't sue me. It's 1:20AM, however
      # @switch(event.target.id.slice(0, event.target.id.length-4) + "default")
      # modified...

      mapmode = event.target.id.slice(0, event.target.id.length-4) + "default"
      @app.navigate("map/#{mapmode}", {trigger: true})

    get_viewport_schools_and_draw: (remote_url, marker_icon) ->
      boundary = @map.getBounds()
      topright = boundary.getNorthEast()
      bottomleft = boundary.getSouthWest()
      that = this # Because sometimes _.bind is too syntaxically (syntacitcally)
                  # ugly
      $.getJSON(remote_url, {
        toprightlat: topright.lat(), toprightlong: topright.lng(),
        bottomleftlat: bottomleft.lat(), bottomleftlong: bottomleft.lng(),
        zoomlevel: @map.getZoom()
      }, (data) ->
        that.redraw_schools(data, marker_icon)
      )

    switch: (mode, callback=null) ->
      @currentmode = mode
      if not @map.getBounds()
        that = this
        setTimeout((() -> that.switch(mode)), 100) # TODO: switch to Deferred
        return

      if @cleanup
        @cleanup()

      switch mode
        when "enrollment-heat"
          redraw = null

          data = new google.maps.MVCArray()
          for id, coordinate of window.SCHOOL_COORDINATES
            data.push(
              location: new google.maps.LatLng(coordinate[0], coordinate[1])
              weight: window.SCHOOL_ENROLLMENTS[id]
              dissipating: true
            )

          @heatmap = new google.maps.visualization.HeatmapLayer(
            map: @map
            data: data
            gradient: GRADIENT
          )

          @cleanup = @heat_cleanup
          @switch_button("enrollment", "Heat")

        when "rank-default" # RANK VIEW!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
          marker_icon = (data) ->
            if data["level"] == "M"
              color = "red"
            else
              color = "blue"

            circle =
              path: google.maps.SymbolPath.CIRCLE
              scale: data["scale"]
              fillColor: color
              strokeWeight: 0.5
              fillOpacity: 0.2

            return circle

          redraw = _.bind((() ->
            @get_viewport_schools_and_draw("/rankview", marker_icon)
          ), this)

          redraw()
          @cleanup = @marker_cleanup
          @switch_button("rank", "Rank")
          $("#map-status").text("Heat")

        when "rank-heat"

          statusmsg.display("Loading...")
          response = $.getJSON("/rankheat")
          response.done(_.bind(((data) ->

            heatdata = new google.maps.MVCArray()

            for d in data.data
              heatdata.push(
                location: new google.maps.LatLng(window.SCHOOL_COORDINATES[d["id"]][0], window.SCHOOL_COORDINATES[d["id"]][1])
                weight: d["weight"]
                radius: d["weight"]
              )

            @heatmap = new google.maps.visualization.HeatmapLayer(
              map: @map
              data: heatdata
              gradient: GRADIENT
            )

            @cleanup = @heat_cleanup
            @switch_button("rank", "Heat")
            statusmsg.close()
          ), this))

          response.fail((xhr) ->
            statusmsg.display("Failed to get rank heat map #{xhr.status}", true)
          )

        when "improved-default"
          statusmsg.display("Loading...")
          response = $.getJSON("/improvedheat")
          response.done(_.bind(((data) ->
            heatdata = new google.maps.MVCArray()
            for d in data.data
              heatdata.push(
                location: new google.maps.LatLng(window.SCHOOL_COORDINATES[d["id"]][0], window.SCHOOL_COORDINATES[d["id"]][1])
                weight: d["weight"]
                radius: d["weight"]
              )

            @heatmap = new google.maps.visualization.HeatmapLayer(
              map: @map
              data: heatdata
              gradient: GRADIENT
            )

            @cleanup = @heat_cleanup
            @switch_button("improved", "Heat")
            statusmsg.close()
          ), this))

          response.fail((xhr) ->
            statusmsg.display("Failed to get rank heat map #{xhr.status}", true)
          )

        else
          marker_icon = _.bind(((level) ->
            if level == "M" then @marker_image_em else @marker_image_high
          ), this)

          redraw = _.bind((() ->
            @get_viewport_schools_and_draw("/schoolmarkers", marker_icon)
          ), this)

          redraw()
          @cleanup = @marker_cleanup
          @switch_button("enrollment", "Default")

      google.maps.event.clearListeners(@map, "idle")

      if redraw
        google.maps.event.addListener(@map, "idle", redraw)

      if callback
        callback()

    switch_button: (type, mode) ->
      buttons = $("#mapcontrols .mapnav")
      for button in buttons
        if button.id.slice(0, type.length) != type
          if $(button).hasClass("active")
            $(button).removeClass("active")
        else
          $(button).addClass("active")
          $(button).children("span").text(mode)

    show_details: (id) ->
      id = id.split("-")[0]
      if coordinate = window.SCHOOL_COORDINATES[id] # Yea i mean single equal
        latlng = new google.maps.LatLng(coordinate[0], coordinate[1])
        @map.setCenter(latlng)
        @details_view.show(id, $("#details-view", @el))
      else
        statusmsg.display("Invalid school id '#{id}'", true)

    on_view_changed: () ->
      @undelegateEvents()

    render: () ->
      @$el.html(@template())
      @delegateEvents()
      @

  exports["MapView"] = MapView
