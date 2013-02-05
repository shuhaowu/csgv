# This file is not licensed under GPLv3, but LGPLv3.
# This file is actually an early preview of another project I have going.

# statusmsg = {}
statusmsg = namespace "statusmsg"

set_human_msg_css = (msgbox) ->
  msgbox.css("position", "fixed").css("left", ($(window).width() - $(msgbox).outerWidth()) / 2)

statusmsg["setup"] = (appendTo="body", msgOpacity=0.8, msgID="statusmsg") ->
  statusmsg.msgID = msgID
  statusmsg.msgOpacity = msgOpacity

  statusmsg.msgbox = $('<div id="' + statusmsg.msgID + '" class="statusmsg"></div>')
  $(appendTo).append(statusmsg.msgbox)

  $(window).resize(() ->
    set_human_msg_css(statusmsg.msgbox)
  )
  $(window).resize()

statusmsg["display"] = (msg, closable) ->
  if closable
    msg += "<a href=\"#\" class=\"close-statusmsg\">&times;</a>"
  statusmsg.msgbox.html(msg)
  
  if closable
    $(".close-statusmsg", statusmsg.msgbox).click((event) ->
      event.preventDefault()
      statusmsg.close()
    )
  set_human_msg_css(statusmsg.msgbox)
  statusmsg.msgbox.fadeIn()
  
statusmsg["close"] = () ->
  if statusmsg.msgbox.css("display") != "none"
    statusmsg.msgbox.fadeOut()
