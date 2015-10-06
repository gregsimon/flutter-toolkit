# This is an implementation of _debugger that talks to the DartVM
# over websockets. _debugger is part of the internal atom repl.js
# package.

# .client.destroy
# .client.reqLookup(ref)
# .client.listbreakpoints
# .client.breakpoints[]
# .client.setBreakpoint(req)
# .client.step [type, count]
# .client.continue
# .client.getScriptById
# .client.currentScript
# .client.currentSourceLine
# .client.scripts[]
# .client.fullTrace
# .client.evaluate(expr)
# .client.on ('unhandledResponse')
# .client.on ('break')
# .client.on ('exception')
# .client.on ('error')
# .client.on ('close')
# .client.once('ready') -> callback

{EventEmitter} = require 'events'
logger = require './logger'


class Client extends EventEmitter
  constructor: ()->
    super()
    @s = null
    @iso = null
    @vm = null

    @breakpoints_ = []

  connect: (port, host)->
    logger.info 'shim', 'connecting to VM...'
    @s = new WebSocket('ws://localhost:8181/ws')

    @s.onopen = (event) =>
      logger.info 'shim', 'ws::onopen'

      # subscribe to events from the VM
      @s.send '{"jsonrpc": "2.0","method": "streamListen","params": {"streamId": "Debug"},"id": "streamlisten"}'

      # Collect some info about the VM here.
      @s.send '{"jsonrpc": "2.0","method": "getVM","params": {},"id": "getvm"}'

      # emit 'ready' when the VM info has come back.

    @s.onerror = (error) =>
      logger.info 'shim', 'ws::error'
      @emit 'error', error

    @s.onmessage = (event) =>
      logger.info 'shim', 'ws::onmessage'
      json = JSON.parse(event.data)
      if (json.id == 'streamlisten')
        console.log(json)
        logger.info 'shim', event.data
      else if (json.id == 'getvm')
        console.log(json)
        @vm = json
        @iso = json.result.isolates
        @emit 'ready'
      else if (json.id == 'getiso')
        @iso = json
      else
        console.log("ws::message (unclassified) " + event.data)


    @s.onclose = () =>
      logger.info 'shim', 'ws::onclose'
      @emit 'close'

  destroy: ->
    @s.close()

  getVM: -> return @vm
  getIsolates: -> return @iso

  req: (obj) ->
    logger.info 'shim', 'req -> ' + obj.command
    switch obj.command
      when 'continue'
        # TODO : Support more than one isolate
        @s.send '{"jsonrpc": "2.0","method": "resume","params":{"isolateId":"'+@iso[0].id+'"},"id": "resume"}'

  reqLookup: (req) ->
    logger.info 'shim', 'reqLookup'

  listbreakpoints: ->
    logger.info 'shim', 'listbreakpoints'

  breakpoints: ->
    logger.info 'shim', 'breakpoints'
    return ""

  setBreakpoint: (req) ->
    logger.info 'shim', 'setBreakpoint ' + req

  step: (type, count) ->
    logger.info 'shim', 'step ' + type
    switch type
      when 'pause'
        # TODO : support more than one isolate
        @s.send '{"jsonrpc": "2.0","method": "pause","params":{"isolateId":"'+@iso[0].id+'"},"id": "pause"}'

  continue: ->
    logger.info 'shim', 'continue'
    # TODO : support more than one isolate
    @s.send '{"jsonrpc": "2.0","method": "resume","params":{"isolateId":"'+@iso[0].id+'"},"id": "resume"}'

  getScriptById: (id) ->
    logger.info 'shim', 'getScriptById'

  currentScript: ->
    logger.info 'shim', 'currentScript'

  currentSourceLine: ->
    logger.info 'shim', 'currentSourceLine'
    return 1;

  scripts: ->
    logger.info 'shim', 'scripts'
    return []

  fullTrace: ->
    logger.info 'shim', 'fullTrace'
    return "";

  evaluate: (expr) ->
    logger.info 'shim', 'evaluate'


exports.Client = Client
