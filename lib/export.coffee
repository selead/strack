###
Module for export project files
###

fs = require "fs"
util = require "./util"

###
Export tracker to txt file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toTxt = (tracker, filename) ->
  out = "#{tracker.name}\n"
  for k,t of tracker.tickets
    out += "created: #{t.created}"
    out += "\tmodified: #{t.modified}" if t.created != t.modified
    out += "\n#{t.author.user} <#{t.author.email}>\n#{t.text}\n" # bug write [Object object]
    out += "Comments :\n" if 0 < t.comments.length
    for c in t.comments
      out += "#{c.author}:\n#{c.comment}\n"
    out += "\n"
  fs.writeFileSync filename, out

###
Export tracker to org-mode file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toOrg = (tracker, filename) ->
  out = "#+STARTUP: hidestars\n#+STARTUP: align\n#+SEQ_TODO:"
  tracker.states.initial.forEach (state) -> out += "#{state.toUpperCase()} "
  out += "| "
  tracker.states.final.forEach (state) -> out += "#{state.toUpperCase()} "
  out += "\n#+AUTHOR: #{tracker.config.get 'user'}\n#+EMAIL: #{tracker.config.get 'email'}\n"
  out +="\n\n* #{tracker.name || tracker.config.get('user') + '\'s project'}[/]\n"
  for t in tracker._sortTickets()
    [text, tags] = util.searchAndReplaceTags t.text, (tag) -> tag
    text = text.replace('@' + t.state, '').replace /\n/g, '\n   '
    text = text.split "\n"
    firstLine = text[0]
    restLines = text[1..]
    tags = tags.join(":").replace(/[\-\.\,]/g, "")
    tags = ":#{tags}:" if tags
    out += "** #{t.state.toUpperCase()} " + "#{util.makeLineLonger(firstLine)} #{tags}\n"
    out += "#{restLines.join '\n'}"
    if 0 < t.comments.length
      out += "\n*** Comments\n"
      for c in t.comments
        out += "    - #{c.comment.replace /\n/g, '\n     '}\n"
    out += "\n"
  fs.writeFileSync filename, out

###
Export tracker to html file

@param {Object} tracker Tracker object
@param {String} filename Path to file
@api public
###
exports.toHtml = (tracker, filename) ->
  out = '<html><head><meta charset="utf-8"><title>' +
    "#{tracker.name || tracker.config.get('user') + '\'s project' &mdash config.get 'user'}" +
    '</title><body><ul style="list-style:none;">\n'
  for t in tracker._sortTickets()
    [text, tags] = util.searchAndReplaceTags t.text, (tag) ->
      "<a href=\"#\">#{tag}</a>"

    text = text.replace /\n/g, "<br />"
    if util.getState(t.text, tracker.config) in tracker.states.final
      styles = 'style="color:grey"'
      text = "<s>#{text}</s>"
    else
      styles = ""
    out += "<li #{styles}>#{text} </li>\n"
  out += "</ul>\n</body></html>\n"
  fs.writeFileSync filename, out