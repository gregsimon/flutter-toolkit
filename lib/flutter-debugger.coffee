R = require 'ramda'
path = require 'path'
kill = require 'tree-kill'
Promise = require 'bluebird'
{Client} = require './dartvm_shim'
childprocess = require 'child_process'
{EventEmitter} = require 'events'
Event = require 'geval/event'
logger = require './logger'

dropEmpty = R.reject(R.isEmpty)

class ProcessManager extends EventEmitter
  constructor: (@atom = atom)->
    super()
    @process = null

  startPaused: ()->
    logger.info 'shim', 'starting target paused'
    @start true

  start: (start_paused = false)->
    @cleanup()
      .then =>
        targetPath = @atom.config.get('flutter-toolkit.dartPath')
        nodeArgs = @atom.config.get('flutter-toolkit.dartArgs')
        appArgs = @atom.config.get('flutter-toolkit.appArgs')

        appPath = @atom
          .workspace
          .getActiveTextEditor()
          .getPath()

        args = [
          nodeArgs or ''
          appPath
          appArgs or ''
        ]

        if start_paused
          args.push ' --pause-isolates-on-start'

        logger.error 'spawn', dropEmpty(args)

        @process = childprocess.spawn targetPath, dropEmpty(args), {
          detached: true
          cwd: path.dirname(args[1])
        }

        @process.stdout.on 'data', (d) ->
          logger.info 'child_process', d.toString()

        @process.stderr.on 'data', (d) ->
          logger.info 'child_process', d.toString()

        @process.stdout.on 'end', () ->
          logger.info 'child_process', 'end out'

        @process.stderr.on 'end', () ->
          logger.info 'child_process', 'end error'

        @emit 'processCreated', @process

        @process.once 'error', (err) =>
          switch err.code
            when "ENOENT"
              logger.error 'child_process', "ENOENT exit code. Message: #{err.message}"
              atom.notifications.addError(
                "Failed to start debugger.
                Exit code was ENOENT which indicates that the node
                executable could not be found.
                Try specifying an explicit path in your atom config file
                using the node-debugger.targetPath configuration setting."
              )
            else
              logger.error 'child_process', "Exit code #{err.code}. #{err.message}"
          @emit 'processEnd', err

        @process.once 'close', () =>
          logger.info 'child_process', 'close'
          @emit 'processEnd', @process

        @process.once 'disconnect', () =>
          logger.info 'child_process', 'disconnect'
          @emit 'processEnd', @process

        return @process

  cleanup: ->
    self = this
    new Promise (resolve, reject) =>
      return resolve() if not @process?
      if @process.exitCode
        logger.info 'child_process', 'process already exited with code ' + @process.exitCode
        @process = null
        return resolve()

      onProcessEnd = R.once =>
        logger.info 'child_process', 'die'
        @emit 'processEnd', @process
        @process = null
        resolve()

      logger.info 'child_process', 'start killing process'
      kill @process.pid

      @process.once 'disconnect', onProcessEnd
      @process.once 'exit', onProcessEnd
      @process.once 'close', onProcessEnd

class Debugger extends EventEmitter

  constructor: (@atom = atom, @processManager)->
    super()
    @className = 'Flutter-Debugger'
    @breakpoints = []
    @client = null

    @onBreakEvent = Event()
    @onAddBreakpointEvent = Event()
    @onRemoveBreakpointEvent = Event()
    @onBreak = @onBreakEvent.listen
    @onAddBreakpoint = @onAddBreakpointEvent.listen
    @onRemoveBreakpoint = @onRemoveBreakpointEvent.listen
    @processManager.on 'processCreated', @start
    @processManager.on 'processEnd', @cleanup
    @markers = []

  stopRetrying: ->
    return unless @timeout?
    clearTimeout @timeout


  listBreakpoints: ->
    new Promise (resolve, reject) =>
      @client.listbreakpoints (err, res) ->
        return reject(err) if err
        resolve(res.breakpoints)

  step: (type, count) ->
    self = this
    new Promise (resolve, reject) =>
      @client.step type, count, (err) ->
        return reject(err) if err
        resolve()

  reqContinue: ->
    self = this
    new Promise (resolve, reject) =>
      @client.req {
        command: 'continue'
      }, (err) ->
        return reject(err) if err
        resolve()

  getScriptById: (id) ->
    self = this
    new Promise (resolve, reject) =>
      @client.req {
        command: 'scripts',
        arguments: {
          ids: [id],
          includeSource: true
        }
      }, (err, res) ->
        return reject(err) if err
        resolve(res[0])

  tryGetBreakpoint: (script, line) =>
    logger.info 'debugger', 'tryGetBreakpoint'
    # TODO : This can be called before the client is instantiated.
    # This is also called by toggleBreakpoint

    findMatch = R.find (breakpoint) =>
      console.log 'finding for '+script+' '+line
      console.log breakpoint
      if breakpoint.scriptId is script or breakpoint.scriptReq is script or \
              (breakpoint.script and breakpoint.script.indexOf(script) isnt -1)
        return breakpoint.line is (line+1);
    #console.log 'tryGetBreakpoint'
    #console.log @client.breakpoints
    bb =  findMatch(@client.breakpoints)
    console.log('found?')
    console.log bb
    return bb

  toggleBreakpoint: (editor, script, line) ->
    logger.info 'debugger', 'toggleBreakpoint'
    # We need to start the process in a puased state if
    # it hasn't been started yet.
    if @client is null
      @start(true)

    new Promise (resolve, reject) =>

      match = @tryGetBreakpoint(script, line)
      if match
        @clearBreakPoint(script, line)
      else
        @addBreakpoint(editor, script, line)

  addBreakpoint: (editor, script, line, condition, silent) =>
      logger.info 'debugger', 'addBreakpoint'
    #new Promise (resolve, reject) =>
      # script e.g. -> '/usr/local/google/home/gregsimon/github/flutter-toolkit/loop.dart'
      if script is undefined
        script = @client.currentScript;
        line = @client.currentSourceLine + 1

      if line is undefined and typeof script is 'number'
        line = script
        script = @client.currentScript

      return if not script?

      if /\(\)$/.test(script)
        req =
          type: 'function'
          target: script.replace /\(\)$/, ''
          confition: condition
      else
        if script != +script && not @client.scripts[script]
          scripts = @client.scripts
          for id in scripts
            if scripts[id] and scripts[id].name and scripts.name.indexOf(script) isnt -1
              ambiguous = scriptId?
              scriptId = id
            else
              scriptId = script

      if line <= 0
        return reject(new Error('Line should be a positive value'))
      if ambiguous
        return reject(new Error('Invalid script name'))

      if scriptId?
        req =
          type: 'scriptId'
          target: scriptId
          line: line - 1
          condition: condition
          editor: editor
      else
        escapedPath = script.replace(/([/\\.?*()^${}|[\]])/g, '\\$1')
        scriptPathRegex = "^(.*[\\/\\\\])?#{escapedPath}$";
        req =
          type: 'script'
          target: script
          line: line
          condition: condition
          editor: editor

      # call shim to set the breakpoint. This returns immediately
      # and returns with an event.
      @client.setBreakpoint req

      ###
      @client.setBreakpoint req, (err, res) =>
        console.log '******* setBreakpoint returned from shim with:'
        console.log err
        console.log res

        return reject(err) if err

        if not scriptId?
          scriptId = res.script_id
          line = res.line + 1

        brk =
          id: res.breakpoint
          scriptId: scriptId
          script: (@client?.scripts?[scriptId] or {}).name
          line: line,
          condition: condition,
          scriptReq: script

        @client.breakpoints.push brk
        brk.marker = @markLine(editor, brk)
        @onAddBreakpointEvent.broadcast(brk)
        resolve(brk)
        ###

  breakpointAdded: (b) =>
    logger.info 'debugger', 'breakpointAdded'
    console.log('breakpointAdded')
    console.log(b)
    brk =
      id: b.id
      scriptId: b.location.script.id
      script: b.location.script.uri
      line: b.line
      condition: b.condition
      scriptReq: b.location.script.uri
    @client.breakpoints.push brk
    brk.marker = @markLine(b.editor, brk)
    @onAddBreakpointEvent.broadcast(brk)

  clearBreakPoint: (script, line) ->
    self = this
    getbrk =
      () ->
        new Promise (resolve, reject) =>
              match = self.tryGetBreakpoint(script, line)
              return reject() if not match?
              resolve({
                    breakpoint: match
                    index: self.client.breakpoints.indexOf match
                  })
    clearbrk =
      (brk) ->
        new Promise (resolve, reject) =>
            self.client.clearBreakpoint { breakpoint: brk.breakpoint.id }, (err) =>
              return reject(err) if err
              self.client.breakpoints.splice brk.index, 1
              markerIndex = self.markers.indexOf(brk.breakpoint.marker)
              self.markers.splice(markerIndex, 1)
              brk.breakpoint.marker.destroy()
              self.onRemoveBreakpointEvent.broadcast(brk)
              resolve()

    getbrk().then(clearbrk)

  fullTrace: () ->
    new Promise (resolve, reject) =>
      @client.fullTrace (err, res) ->
        return reject(err) if err
        resolve(res)

  # The target process has started but may be in a paused state
  start: =>
    logger.info 'debugger', 'start connect to process'
    self = this
    attemptConnectCount = 0
    attemptConnect = ->
      logger.info 'debugger', 'attempting to connect to child process'
      if not self.client?
        logger.info 'debugger', 'client has been cleaned up'
        return
      attemptConnectCount++
      self.client.connect(
        self.atom.config.get('flutter-toolkit.debugPort'),
        self.atom.config.get('flutter-toolkit.debugHost')
      )

    onConnectionError = =>
      logger.info 'debugger', "trying to reconnect #{attemptConnectCount}"
      attemptConnectCount++
      @emit 'reconnect', attemptConnectCount
      @timeout = setTimeout =>
        attemptConnect()
      , 500

    @client = new Client()
    @client.once 'ready', @bindEvents

    @client.on 'unhandledResponse', (res) => @emit 'unhandledResponse', res
    @client.on 'break', (res) =>
      @onBreakEvent.broadcast(res.body)
      @emit 'break', res.body
    @client.on 'exception', (res) => @emit 'exception', res.body
    @client.on 'error', onConnectionError
    @client.on 'close', () ->
      logger.info 'client', 'client closed'

    attemptConnect()

  bindEvents: =>
    logger.info 'debugger', 'connected'
    @emit 'connected'
    @client.on 'breakpointAdded', @breakpointAdded
    @client.on 'close', =>
      logger.info 'debugger', 'connection closed'

      @processManager.cleanup()
        .then =>
          @emit 'close'

  lookup: (ref) ->
    new Promise (resolve, reject) =>
      @client.reqLookup [ref], (err, res) ->
        return reject(err) if err
        resolve(res[ref])

  eval: (text) ->
    new Promise (resolve, reject) =>
      @client.req {
        command: 'evaluate'
        arguments: {
          expression: text
        }
      }, (err, result) ->
        return reject(err) if err
        return resolve(result)

  cleanup: =>
    return unless @client?
    @removeBreakpointMarkers()
    @removeDecorations()
    @client.destroy()
    @client = null
    @emit 'disconnected'

  markLine: (editor, breakPoint) ->
      logger.info 'debugger', 'markLine'
      marker = editor.markBufferPosition([breakPoint.line-1, 0], invalidate: 'never')
      editor.decorateMarker(marker, type: 'line-number', class: 'flutter-debugger-breakpoint')
      @markers.push marker
      return marker

  removeBreakpointMarkers: =>
      logger.info 'debugger', 'removeBreakpointMarkers'
      return unless @client?
      # TODO ???? breakpoint.marker.destroy() for breakpoint in @client.breakpoints

  removeDecorations: ->
      logger.info 'debugger', 'removeDecorations'
      return unless @markers?
      marker.destroy() for marker in @markers
      @markers = []

  isConnected: =>
      return @client?

exports.ProcessManager = ProcessManager
exports.Debugger = Debugger
