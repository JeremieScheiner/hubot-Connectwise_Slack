# Description:
#   Identifies ConnectWise ticket numbers in chat, verifies they are real, and provides a web link to the ticket
#
# Dependencies:
#   Slack Adapter
#
# Configuration:
#   HUBOT_CW_URL - The URL of the ConnectWise Server
#   HUBOT_CW_COMPANYID - The Company ID of the ConnectWise Instance
#   HUBOT_CW_APIPUBLIC - The REST API Public Key
#   HUBOT_CW_APISECRECT - The REST API Private Key
#
# Commands:
#   5-6 digit number in chat {}\b\d{5-6}\b}/ig - Provides a Hyperlink to the ticket if the number is a valid ticket number.
#
# Notes:
#   Currently will respond to a hyperlink pasted into slack...
#
# Author:
#   John Vernon

#Environment Variables
cwURL = process.env.HUBOT_CW_URL
cwCompanyID = process.env.HUBOT_CW_COMPANYID
cwPublic = process.env.HUBOT_CW_APIPUBLIC
cwSecret = process.env.HUBOT_CW_APISECRECT
cwAPIURL = process.env.HUBOT_CW_API_URL

#check for config Errors
configError = ->
  unless cwURL?
    return "Connectwise Helper: Undefined HUBOT_CW_URL"
  unless cwCompanyID?
    return "Connectwise Helper: Undefined HUBOT_CW_COMPANYID"
  unless cwPublic?
    return "Connectwise Helper: Undefined HUBOT_CW_APIPUBLIC"
  unless cwSecret?
    return "Connectwise Helper: Undefined HUBOT_CW_APISECRECT"
  unless cwAPIURL?
    return "Connectwise Helper: Undefined HUBOT_CW_API_URL"

#Ticket Watchers DAL
class CWTWatchers
  constructor: (@robot) ->
    @robot.brain.data.cwtwatchers = {}

  add: (cwTicket, userName) ->
    if @robot.brain.data.cwtwatchers[cwTicket] is undefined
      @robot.logger.debug "cwTicket collection is undefined"
      @robot.brain.data.cwtwatchers[cwTicket] = []

    for watcher in @robot.brain.data.cwtwatchers[cwTicket]
      if watcher.toLowerCase() is userName.toLowerCase()
        @robot.logger.debug "Found #{watcher} already watching #{cwTicket}"
        return

    @robot.brain.data.cwtwatchers[cwTicket].push userName
    @robot.logger.debug "#{userName} is now watching #{cwTicket}"

  remove: (cwTicket, userName) ->
    watchers = @robot.brain.data.cwtwatchers[cwTicket] or []
    @robot.brain.data.cwtwatchers[cwTicket] = (user for user in watchers when user.toLowerCase() isnt userName.toLowerCase())
    @robot.logger.debug "Removed #{userName} from watching #{cwTicket}"

  removeAll: (cwTicket) ->
    delete @robot.brain.data.cwtwatchers[cwTicket]

  watchers: (cwTicket) ->
    return @robot.brain.data.cwtwatchers[cwTicket] or []

#Check for other listeners that we need to ignore for the ticket watch
ticketHeardExclusions = (heardString) ->
  if heardString.match(/watch ticket \b(\d{3,6})\b/i)?
    return true
  if heardString.match(/ignore ticket \b(\d{3,6})\b/i)?
    return true
  if heardString.match(/who is watching \b(\d{3,6})\b/i)?
    return true

#Dedupe and array
removeDuplicates = (ar) ->
  if ar.length == 0
    return []
  res = {}
  res[ar[key]] = ar[key] for key in [0..ar.length-1]
  value for key, value of res

#create an auth string for ConnectWise REST API
auth = 'Basic ' + new Buffer(cwCompanyID + '+' + cwPublic + ':' + cwSecret).toString('base64');

###Begin Listeners###
module.exports = (robot) ->
  CWTicketWatchers = new CWTWatchers robot

  #Listen for ticket numbers mentioned in chat
  robot.hear /\b(\d{3,6})\b/i, (msg) ->
    unless not configError()?
      msg.send "#{configError()}"
      return
    robot.logger.debug "CWTicket passed environment check"
    #check to ensure that the message is not in another match
    robot.logger.debug "HeardString = #{msg.message.text}"
    if ticketHeardExclusions(msg.message.text)?
      robot.logger.debug "Excluded string match found"
      return
    #Create an array of match strings
    foundValues = removeDuplicates(msg.message.text.match(/\b(\d{3,6})\b/ig))
    for cwticket in foundValues
      #check ConnectWise to see if ticket exists
      robot.http("https://#{cwAPIURL}/v4_6_release/apis/3.0/service/tickets/#{cwticket}")
      .headers(Authorization: auth, Accept: 'application/json')
      .get() (err, res, body) ->
        data = JSON.parse(body)
        if res.statusCode == 200
          robot.logger.debug "Ticket Link: #{data.id}!"
          robot.emit 'slack.attachment',
            message: msg.message
            content:
              title: "Ticket Link: #{data.id}!"
              title_link: "https://#{cwURL}/v4_6_release/services/system_io/Service/fv_sr100_request.rails?service_recid=#{data.id}&companyName=#{cwCompanyID}"
              color: "#0A53A1"
              fallback: "Ticket Link: #{data.id}!"

  #listen for ticket watch requests
  robot.hear /watch ticket \b(\d{3,6})\b/i, (msg) ->
    unless not configError()?
      msg.send "#{configError()}"
      return
    robot.http("https://#{cwAPIURL}/v4_6_release/apis/3.0/service/tickets/#{msg.match[1]}")
    .headers(Authorization: auth, Accept: 'application/json')
    .get() (err, res, body) ->
      data = JSON.parse(body)
      if res.statusCode == 200
        #add to watch list
        CWTicketWatchers.add data.id,msg.message.user.name
        #notify user of addition
        robot.logger.debug "Ticket watch set for #{data.id}"
        robot.emit 'slack.attachment',
          message: msg.message
          channel: msg.envelope.user.name
          content:
            title: "Ticket watch success"
            color: "good"
            fallback: "Watch set for ticket: #{data.id}"
            text: "Watch set for ticket: #{data.id}"
      else
        robot.logger.debug "Ticket #{msg.match[1]} not in CW"
        robot.emit 'slack.attachment',
          message: msg.message
          channel: msg.envelope.user.name
          content:
            title: "Ticket watch failure"
            color: "danger"
            fallback: "Ticket watch failure"
            text: "Invalid ticket for watch: #{msg.match[1]}.\nPlease verify that this is the correct ticket number."

  #get a list of listeners for a given ticket
  robot.hear /who is watching \b(\d{3,6})\b/i, (msg) ->
    cwTicket = msg.match[1]
    ticketWatchers = CWTicketWatchers.watchers(cwTicket)
    if ticketWatchers.length > 0
      robot.logger.debug "#{ticketWatchers.toString()} are watching #{cwTicket}"
      robot.emit 'slack.attachment',
        message: msg.message
        channel: msg.envelope.user.name
        content:
          title: "Users watching ticket #{cwTicket}"
          text: "#{ticketWatchers.toString()} are watching #{cwTicket}"
          fallback: "#{ticketWatchers.toString()} are watching #{cwTicket}"
          color: "#439FE0"
    else
      robot.logger.debug "Can't find anyone watching #{cwTicket}"
      msg.send "I don't recall anyone watching #{cwTicket}"

  #listen for ticket ignore requests
  robot.hear /ignore ticket \b(\d{3,6})\b/i, (msg) ->
    unless not configError()?
      msg.send "#{configError()}"
      return
    cwticket = msg.match[1]
    CWTicketWatchers.remove cwticket, msg.message.user.name
    robot.logger.debug "Ticket #{cwticket} ignored"
    robot.emit 'slack.attachment',
      message: msg.message
      channel: msg.envelope.user.name
      content:
        title: "Ignoring Ticket"
        color: "good"
        fallback: "Now ignoring: #{cwticket}"
        text: "You are no longer watching ticket: #{cwticket}"


  #clear all followers for a ticket
  robot.hear /clear all watchers for ticket \b(\d{3,6})\b/i, (msg) ->
    unless not configError()?
      msg.send "#{configError()}"
      return
    cwticket = msg.match[1]
    CWTicketWatchers.removeAll cwticket
    robot.logger.debug "Removed all watchers for ticket #{cwticket}"
    robot.emit 'slack.attachment',
      message: msg.message
      channel: msg.envelope.user.name
      content:
        title: "Clear Watchers"
        color: "info"
        fallback: "All watchers cleared for ticket #{cwticket}"
        text: "All watchers cleared for ticket #{cwticket}"


  #Listen for callbacks with watched tickets
  robot.router.post '/hubot/cwticket', (req, res) ->
    if req.query.id?
      watchers = CWTicketWatchers.watchers req.query.id
      if watchers.length == 0
        return
      for user in watchers
        robot.send {room: "#{user}"}, "#{req.query.id} was updated"
    res.end()
