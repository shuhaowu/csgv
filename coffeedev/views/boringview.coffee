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

exports = namespace "views.boringview"
utils = require "views.utils"

class BoringView extends Backbone.View
  load_template: () ->
    if not @__template_fetch_inprogress

      @__template_fetch_inprogress = true
      template_deferred = $.Deferred()

      request = $.get("/static/jstemplates/#{@template_name}")
      request.done(_.bind(((data) ->
        template = Handlebars.compile(data)
        @template = template
        @rawtemplate = data
        
        if @on_template_loaded
          @on_template_loaded()

        template_deferred.resolve(template, data)
      ), this))

      request.fail((jqxhr) ->
        template_deferred.reject(jqxhr)
      )

      @template_request = template_deferred.promise()

exports["BoringView"] = BoringView
