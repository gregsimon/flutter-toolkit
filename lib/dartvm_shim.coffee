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

logger = require './logger'


class Client
  constructor: ()->
    @s = null
    @iso = null
    @vm = null

  connect: =>
    logger.info 'shim', 'connect'
    @s = new WebSocket("ws://localhost:8181/ws");
    @s.onopen = (event) ->
      @s = event.target
      console.log("ws::open");

      # subscribe to Debug events
      @s.send '{"jsonrpc": "2.0","method": "streamListen","params": {"streamId": "Debug"},"id": "2"}'

      # Collect some info about the VM here.
      @s.send '{"jsonrpc": "2.0","method": "getVM","params": {},"id": "getvm"}'

    @s.onmessage = (event) ->
      console.log("ws::message " + event.data);
      json = JSON.parse(event.data)
      if (json.id == 'getvm')
        @vm = json
      else if (json.id == 'getiso')
        @iso = json


    @s.onclose = () ->
      console.log("ws::close");

  destroy: =>
    @s.close()

  reqLookup: (req) ->
    logger.info 'shim', 'reqLookup'

  listbreakpoints: =>
    logger.info 'shim', 'listbreakpoints'

  breakpoints: =>
    logger.info 'shim', 'breakpoints'

  setBreakpoint: (req) ->
    logger.info 'shim', 'setBreakpoint'

  step: (type, count) ->
    logger.info 'shim', 'step'

  continue: =>
    logger.info 'shim', 'continue'

  getScriptById: (id) ->
    logger.info 'shim', 'getScriptById'

  currentScript: =>
    logger.info 'shim', 'currentScript'

  currentSourceLine: =>
    logger.info 'shim', 'currentSourceLine'
    return 1;

  scripts: =>
    logger.info 'shim', 'scripts'
    return []

  fullTrace: =>
    logger.info 'shim', 'fullTrace'
    return "";

  evaluate: (expr) ->
    logger.info 'shim', 'evaluate'

  on: (eventName) ->
    logger.info 'shim', 'on(...)'

  once: (eventName) ->
    logger.info 'shim', 'once(...)'


exports.Client = Client
