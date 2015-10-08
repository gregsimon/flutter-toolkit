# This is an implementation of _debugger that talks to the DartVM
# over websockets. _debugger is part of the internal atom repl.js
# package. The rest of the debugger code (e.g., flutter-debugger.coffee)
# is looking for the following methods:

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
    @s = null             # websocket

    @vm = null            # VM json object
    @isolates = { }       # details of active isolates
    @libraries = { }      # details of all known libraries

    @breakpoints = []

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

      switch json.id
        when 'stream_debug'
          console.log(json)
          logger.info 'shim', event.data
        when 'stream_iso'
          console.log(json)
          logger.info 'shim', event.data
        when 'getvm'
          @vm = json.result
          # collect detailed isolate info so we can set breakpoints/etc.
          @s.send('{"jsonrpc": "2.0","method": "getIsolate","params":{"isolateId":"'+iso.id+'"},"id": "getiso"}') for iso in json.result.isolates
          @emit 'ready'
        when 'getiso'
          isolate = json.result;
          @isolates[isolate.id] = isolate
          console.log 'the ISO object ' + isolate.id
          #console.log(@isolates)
          # also collect the 'scripts' for this isolate
          @s.send('{"jsonrpc": "2.0","method": "getObject","params":{"isolateId":"'+isolate.id+'",\
              "objectId":"'+lib.id+'"},"id": "getlib"}') for lib in isolate.libraries
        when 'getlib'
          # callback for asking for library details. We'll need this to
          # set breakpoints on the script.
          lib = json.result;
          @libraries[lib.id] = lib
        when 'addbreakpoint'
          # a breakpoint was added by US. We'll wait for the streamNotify callback
        else
          if json.method != undefined
            switch json.method
              when 'streamNotify'
                @handleStreamNotify json
              else
                # uncaught method
                console.log('unsupported method from streamevent: ' + json.method)
          else
            # uncaught id
            console.log("ws::message (unclassified) " + event.data)


    @s.onclose = () =>
      logger.info 'shim', 'ws::onclose'
      @emit 'close'

  destroy: ->
    @s.close()

  handleStreamNotify: (json)->
    console.log 'handleStreamNotify:'
    console.log json
    switch json.params.event.kind
      when 'BreakpointAdded'
        console.log '----> A breakpoint was added'
        # TODO
      when 'PauseBreakpoint'
        console.log '----> execution has stopped because a breakpoint was hit'
        # TODO
      else
        console.log 'UNSUPPORTED stream type'

  getVM: -> return @vm
  getIsolates: -> return @isolates

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
    logger.info 'shim', 'setBreakpoint'
    src_file = req.target.replace(/\\/g, "/")

    console.log('setBreakpoint .. from editor: ' + src_file + ':' + req.line)
    # req.type <-- "script"
    # req.target <-- <file path>
    # req.line <-- <number>
    # req.condition <-- 'undefined'

    scriptId = undefined
    #console.log @isolates
    console.log @libraries

    # find the isolate which contains this script.
    isloate_with_script = iso for id, iso of @isolates when iso.id.search src_file >= 0
    console.log 'isloate_with_script -> ' + isloate_with_script.id

    # find the library this script is in. We'll search the libraries
    # we are aware of for the .uri field. From there we'll get the
    # scriptid.
    library_with_script = lib for id, lib of @libraries when lib.uri.search src_file >= 0
    if library_with_script is undefined
      logger.error 'shim', 'unable to locate script id for ' + src_file

    scriptId = library_with_script.scripts[0].id;

    # TODO : we aren't identifying the isolate here.

    str = '{"jsonrpc":"2.0","method":"addBreakpoint","params":{\
      "isolateId":"'+isloate_with_script.id+'",\
      "scriptId":"'+scriptId+'", \
      "line":'+req.line.toString()+' \
      },"id":"addbreakpoint"}'
    #console.log str
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
