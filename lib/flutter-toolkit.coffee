FlutterToolkitView = require './flutter-toolkit-view'
Event = require 'geval'
{CompositeDisposable} = require 'atom'
{Debugger, ProcessManager} = require './flutter-debugger'
jumpToBreakpoint = require './flutter-jump-to-breakpoint'
logger = require './logger'
os = require 'os'

processManager = null
_debugger = null
onBreak = null

initNotifications = (_debugger) ->
  _debugger.on 'connected', ->
    atom.notifications.addSuccess('Debugger connected.')

  _debugger.on 'disconnected', ->
    atom.notifications.addInfo('Process exited.')

module.exports =
  flutterToolkitView: null
  config:
    dartPath:
      type: 'string'
      default: if os.platform() is 'win32' then 'C:\\Users\\gregs_000\\Downloads\\dartsdk-windows-x64-release\\dart-sdk\\bin\\dart.exe' else '/usr/local/bin/dart'
    debugPort:
      type: 'number'
      minium: 5857
      maxium: 65535
      default: 5858
    debugHost:
      type: 'string'
      default: '127.0.0.1'
    dartArgs:
      type: 'string'
      default: '--observe'
    appArgs:
      type: 'string'
      default: ''

  activate: () ->
    logger.info 'main', "activate()"
    @disposables = new CompositeDisposable()
    processManager = new ProcessManager(atom)
    _debugger = new Debugger(atom, processManager)
    initNotifications(_debugger)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable

    # Register command that toggles this view
    @disposables.add atom.commands.add('atom-workspace', {
      'flutter-toolkit:debugger-start-resume': @debuggerStartResume
      'flutter-toolkit:debugger-stop': @debuggerStop
      'flutter-toolkit:debugger-step': @debuggerStep
      'flutter-toolkit:debugger-step-in': @debuggerStepIn
      'flutter-toolkit:debugger-step-out': @debuggerStepOut
      'flutter-toolkit:toggle-breakpoint': @toggleBreakpoint
    })

    jumpToBreakpoint(_debugger)


  debuggerStartResume: =>
    logger.info 'main', "debuggerStartResume() *******************"
    if _debugger.isConnected()
      _debugger.reqContinue()
    else
      processManager.start()
      FlutterToolkitView.show(_debugger)

  debuggerStop: =>
    logger.info 'main', "debuggerStop()"
    processManager.cleanup()
    _debugger.cleanup()
    FlutterToolkitView.destroy()
    jumpToBreakpoint.cleanup()

  debuggerStep: =>
    _debugger.step('next', 1)

  debuggerStepIn: =>
    _debugger.step('in', 1)

  debuggerStepOut: =>
    _debugger.step('out', 1)

  toggleBreakpoint: =>
    logger.info 'main', "toggleBreakpoint"
    editor = atom.workspace.getActiveTextEditor()
    path = editor.getPath()
    {row} = editor.getCursorBufferPosition()
    _debugger.toggleBreakpoint(editor, path, row)


  deactivate: ->
    logger.info 'main', "deactivate()"
    jumpToBreakpoint.destroy()
    @debuggerStop()
    @disposables.dispose()
    FlutterToolkitView.destroy()

  serialize: ->
    flutterToolkitViewState: @flutterToolkitView.serialize()
