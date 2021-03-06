require "colors"
util = require "./util"
Tracker = require("./tracker").Tracker
sys = require "sys"
parser = require "./source-parser"
exp = require "./export"
usage = '''
Usage:

strack [COMMAND] args

id field in commands may be replaced by shortuts ^0-^9 and ^a-^z

strack commands and aliases:
  add, a\tAdd new ticket/task
  config, cf\tWork with config options
  comment, c\tComment ticket/task
  done, d\tChange ticket/task state
  fs    \tSearch tags in source
  edit, e\tEdit ticket title
  help, h\tHelp on commands
  info, i\tShow info on ticket/task
  log, l\tShow tracker log.
        \tSearch by tags, states and regular words
  remove, rm\tRemove ticket/task
  states, st\tChange states for project
  touch, t\tChange task access time
'''

showHelp = ->
  v = process.argv[3]
  switch v
    when "add", "a"
      console.log "strack #{v} [ticket/task text]\n\n  Add new ticket/task\n  For input multiline text, omit all parameters after add\n"
    when "config", "cf"
      console.log "strack #{v} [key [value]]\n\n  Work with config options\n  If key and value omited, show all config params\n" +
        "  If key is set, show key value\n  If key and value is set, write new value to config\n\nConfig options:\n" +
        '  user\t\t\tUser name\n  email\t\t\tUser email\n  log\t\t\tLog format, one of "tiny", "short", "long"\n  showDonedTasks\tShow done tasks' +
        ' when watch log, one of "true", "false"\n  verbose\t\tSet/unset verbose mode, one of "true", "false"\n'
    when "comment", "c"
      console.log "strack #{v} id [comment]\n\n  Comment ticket/task\n  For input multiline comment, omit comment parameter\n"
    when "info", "i"
      console.log "strack #{v} id\n\n  Show detail information about ticket/task\n  " +
        "Add . and shortcut symbol (0-z) to see only comments on ticket/task.\n"
    when "log", "l"
      console.log "strack #{v} [pattern]\n\n  Show tracker log\n  If pattern is set, only tasks, that match this pattern will be displayed\n"
    when "remove", "rm"
      console.log "strack #{v} id [id2, id3...]\n\n  Remove tickets/tasks from tracker\n"
    when "done", "d"
      console.log "strack #{v} id new-state\n\n  Change state of ticket/task\n"
    when "states", "st"
      console.log "strack #{v} [group [new states]]\n\n  Work with project states.\n" +
        '  If optional params omited, show groups with states. Project have two groups\n ' +
        ' of states "initial" and "final". Final states are final in ticket/task processing\n' +
        '  If only group specified (it must be "initial" or "final"), will be shown params\n' +
        '  that belong to this group. New states REPLACE ALL group states.\n'
    when "fs"
      console.log "strack #{v} [ext [keywords]]\n\n  Search keywords in file with ext " +
        'extension\n  Default ext is "js"\n  Default keywords is [config.defaultState]\n'
    when "touch", "t"
      console.log "strack #{v} id\n\n  Change last access time for task with specified id.\n"
    else
      console.log usage

exports.run = ->
  config = new util.Config()
  tracker = new Tracker(config)
  tracker.load()

  if tracker.created
    switch process.argv[2]
      when "init"
        "clean Tracker"
        # create file with tickets and id's
        # write files to .gitignore
      when "add", "a"
        if 3 < process.argv.length
          data = process.argv[3..]
          tracker.addTicket data.join " "
        else
          util.readText config.get("eof"), (data) ->
            tracker.addTicket data
      when "edit", "e"
        if 3 < process.argv.length
          id = process.argv[3]
          if "." == id[0]       # show comment
            id = "^" + id.substring 1
            cid = process.argv[4]
            commentList = tracker.getComment id, cid
            if commentList      # comment found?
              [ticket, cId] = commentList
              c = ticket.comments[cId]

              if tracker.canEditComment id, cid              # ok
                 util.editTextLines c.comment, config.get("eof"),
                   ((text) ->
                     if text
                       tracker.updateComment id, cid, text), config.get "showLineNumbers"
              else
                console.log "You can't edit this comment"
            else
              console.log "Invalid comment id (#{cid})"
          else                  # edit ticket
            t = tracker.getSingleTicket id
            util.editTextLines t.text, config.get("eof"),  ((text) ->
              if text
                t.text = text
                tracker.updateTicket t), config.get "showLineNumbers"
        else
          console.log "To edit state text add id"

      when "export"
        format = process.argv[3]
        if format && format in ["txt", "org", "htm", "html"]
          filename = process.argv[4] || "strack.#{format}"
          switch format
            when "txt"
              exp.toTxt tracker, filename
            when "org"
              exp.toOrg tracker, filename
            when "htm", "html"
              exp.toHtml tracker, filename
        else
          console.log "Add format and filename"

      when "config", "cf"
        key = process.argv[3] if 3 < process.argv.length
        if key
          value = process.argv[4] if 4 < process.argv.length
          if value                # set new value
            param = {}
            param[key] = value
            config.update param
          else                    # show key value
            console.log "#{key} = #{config.get key}"
        else                      # dump all settings
          config.dump()
      when "log", "l" # log all or by tag (log + grep!)
        word = process.argv[3] if 3 < process.argv.length
        tracker.log word
      when "done", "d"
        if 4 < process.argv.length
          # replace state
          state = process.argv[3]
          id = process.argv[4]
          if 0 == id.indexOf util.statePrefix
            [state, id] = [id, state]
          tracker.changeState id, state
        else
          console.log "To change state add id and new state"
      when "states", "st"
        if 4 < process.argv.length
          tracker.updateStates process.argv[3..]
        else
          tracker.showStates process.argv[3]
      when "info", "i"
        if 3 < process.argv.length
          id = process.argv[3]
          if "." == id[0]       # show comments
            id = "^" + id.substring 1
            tracker.showComments id
          else
            tracker.info id
        else
          console.log "Add id for ticket "
      when "remove", "r", "rm"
        if 3 < process.argv.length
          ids = process.argv[3..]
          tracker.removeTickets ids
      when "comment", "c"
        id = process.argv[3] if 3 < process.argv.length
        if id
          comment = process.argv[4..].join " "if 4 < process.argv.length
          if !comment
            util.readText config.get("eof"), (comment) ->
              tracker.commentTicket id, comment
          else
             tracker.commentTicket id, comment
        else
          console.log "Ticket id is missing"
      when "help", "h"
        showHelp()
      when "fs"                   #from source
        ext = "." + if 3 < process.argv.length then process.argv[3].toLowerCase() else "js"
        tags =  if 4 < process.argv.length then process.argv[4..] else [config.get "defaultState"]
        filteredTags = []
        tags.forEach (tag) -> filteredTags.push tag.toLowerCase()
        util.listDir(process.cwd(), ext).forEach (file) -> parser.addTickets file, tags, tracker, config
      when "touch", "t"
        if 3 < process.argv.length
          t = tracker.getSingleTicket process.argv[3]
          t.modified = new Date()
          tracker.updateTicket t
        else
          console.log "Ticket id is missing"
      else
        console.log usage
