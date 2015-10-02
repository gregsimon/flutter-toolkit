FlutterToolkitView = require './flutter-toolkit-view'
Event = require 'geval'
{CompositeDisposable} = require 'atom'
{Debugger, ProcessManager} = require './flutter-debugger'
jumpToBreakpoint = require './jump-to-breakpoint'
logger = require './logger'
os = require 'os'

processManager = null
_debugger = null
onBreak = null

initNotifications = (_debugger) ->
  _debugger.on 'connected', ->
    atom.notifications.addSuccess('connected, enjoy debugging : )')

  _debugger.on 'disconnected', ->
    atom.notifications.addInfo('finish debugging : )')

module.exports = #FlutterToolkit =
  flutterToolkitView: null
  subscriptions: null

  config:
    dartPath:
      type: 'string'
      default: if os.platform() is 'win32' then 'C:\Users\gregs_000\Downloads\dartsdk-windows-x64-release\dart-sdk\bin\dart.exe' else '/usr/local/bin/dart'
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

  activate: (state) ->
    logger.info 'main', "activate()"
    @subscriptions = new CompositeDisposable
    processManager = new ProcessManager(atom)
    _debugger = new Debugger(atom, processManager)
    initNotifications(_debugger)

    #flutterToolkitView = new FlutterToolkitView(state.flutterToolkitViewState)
    #@modalPanel = atom.workspace.addModalPanel(item: @flutterToolkitView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add('atom-workspace', {
      'flutter-toolkit:debug': @debug()
      'flutter-toolkit:debug-stop': @stop()
      'flutter-toolkit:toggle-breakpoint': @toggleBreakpoint()
    })

    jumpToBreakpoint(_debugger)

  deactivate: ->
    logger.info 'main', "deactivate()"
    @subscriptions.dispose()
    flutterToolkitView.destroy()

  serialize: ->
    flutterToolkitViewState: @flutterToolkitView.serialize()

  debug: ->
    logger.info 'main', "debug() *******************"
    if _debugger.isConnected()
      _debugger.reqContinue()
    else
      processManager.start()
      @flutterToolkitView.show(_debugger)

  stop: =>
    logger.info 'main', "debug-stop"
    processManager.cleanup()
    _debugger.cleanup()
    @flutterToolkitView.destroy()
    jumpToBreakpoint.cleanup()

  toggleBreakpoint: =>
    logger.info 'main', "toggleBreakpoint"
    editor = atom.workspace.getActiveTextEditor()
    path = editor.getPath()
    {row} = editor.getCursorBufferPosition()
    _debugger.toggleBreakpoint(editor, path, row)
