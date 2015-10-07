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
    @iso_details = []
    @vm = null

    @breakpoints_ = []

  connect: (port, host)->
    logger.info 'shim', 'connecting to VM...'
    @s = new WebSocket('ws://localhost:8181/ws')

    @s.onopen = (event) =>
      logger.info 'shim', 'ws::onopen'

      # subscribe to events from the VM
      @s.send '{"jsonrpc": "2.0","method": "streamListen","params": {"streamId": "Debug"},"id": "stream_debug"}'
      @s.send '{"jsonrpc": "2.0","method": "streamListen","params": {"streamId": "Isolate"},"id": "stream_iso"}'

      # Collect some info about the VM here.
      @s.send '{"jsonrpc": "2.0","method": "getVM","params": {},"id": "getvm"}'

      # emit 'ready' when the VM info has come back.

    @s.onerror = (error) =>
      logger.info 'shim', 'ws::error'
      @emit 'error', error

    @s.onmessage = (event) =>
      logger.info 'shim', 'ws::onmessage'
      json = JSON.parse(event.data)
      if (json.id == 'stream_debug')
        console.log(json)
        logger.info 'shim', event.data
      if (json.id == 'stream_iso')
        console.log(json)
        logger.info 'shim', event.data
      else if (json.id == 'getvm')
        #console.log(json)
        @vm = json
        @iso = json.result.isolates

        # collect detailed isolate info so we can set breakpoints/etc.
        # TODO : support more than one isolate!
        @s.send '{"jsonrpc": "2.0","method": "getIsolate","params":{"isolateId":"'+@iso[0].id+'"},"id": "getiso"}'

        @emit 'ready'
      else if (json.id == 'getiso')
        isolate = json.result;
        # also collect the 'scripts' for this isolate
        @s.send '{"jsonrpc": "2.0","method": "getObject","params":{"isolateId":"'+isolate.id+'",\
            "objectId":"'+isolate.libraries[14]+'"},"id": "getlib"}'
        @iso_details.push isolate
        #console.log(json.result)
      else if (json.id == 'getlib')
        console.log("collected library");
        console.log json.result
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
    console.log('from editor: ' + req.target + ':' + req.line)
    # req.type <-- "script"
    # req.target <-- <file path>
    # req.line <-- <number>
    # req.condition <-- 'undefined'

    # @iso_details.libraries[?].url <-- contains the fielname ("file:///usr ... ")
    # @iso_details.libraries[?].id <-- scriptId

    scriptId = undefined
    console.log @iso_details

    # TODO : support more than one isolate
    # Locate the isolate which we want to set the breakpoint in.
    scriptId = lib.id for lib in @iso_details[0].libraries when lib.uri.search req.target >= 0
    console.log('found '+scriptId);

    if scriptId is undefined
      logger.error 'shim', 'unable to locate script id for ' + req.target

    str = '{"jsonrpc":"2.0","method":"addBreakpoint","params":{\
      "isolateId":"'+@iso[0].id+'",\
      "scriptId":"'+scriptId+'", \
      "line":'+req.line.toString()+' \
      },"id":"addbreakpoint"}'
    console.log str
    @s.send str


  step: (type, count) ->
    logger.info 'shim', 'step ' + type
    switch type
      when 'pause'
        # TODO : support more than one isolate
        @s.send '{"jsonrpc": "2.0","method": "pause","params":{"isolateId":"'+@iso[0].id+'"},"id": "pause"}'
      when 'next'
        # TODO : support more than one isolate
        @s.send '{"jsonrpc": "2.0","method": "resume","params":{"isolateId":"'+@iso[0].id+'","step":"Over"},"id": "pause"}'

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
