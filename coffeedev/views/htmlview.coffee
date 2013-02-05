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

exports = namespace "views.htmlview"

class HtmlView extends Backbone.View
  tagName: "div"

  render: (page) ->
    statusmsg.display("Loading page...")
    that = this
    $(@el).load("/static/jstemplates/#{page}.html?"+Math.random(), (response, textstatus, xhr) ->
      statusmsg.close()
      if textstatus == "error"
        that.el.innerHTML = "<h3 class=\"text-center\">#{xhr.status} #{xhr.statusText}</h3>"
    )
    @

  switch: HtmlView.prototype.render

exports["HtmlView"] = HtmlView