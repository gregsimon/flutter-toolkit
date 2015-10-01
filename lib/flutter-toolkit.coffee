FlutterToolkitView = require './flutter-toolkit-view'
{CompositeDisposable} = require 'atom'
Event = require 'geval'
os = require 'os'

processManager = null
_debugger = null
onBreak = null

module.exports = FlutterToolkit =
  flutterToolkitView: null
  modalPanel: null
  subscriptions: null

  config:
    dartPath:
      type: 'string'
      default: if os.platform() is 'win32' then 'node.exe' else '/usr/local/bin/dart'
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
    isCoffeeScript:
      type: 'boolean'
      default: false

  activate: (state) ->
    processManager = new ProcessManager(atom)


    @flutterToolkitView = new FlutterToolkitView(state.flutterToolkitViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @flutterToolkitView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'flutter-toolkit:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'flutter-toolkit:debug': => @debug()
    console.log "ftk.activate"

  deactivate: ->
    console.log "ftk.deactivate"
    @modalPanel.destroy()
    @subscriptions.dispose()
    @flutterToolkitView.destroy()

  serialize: ->
    flutterToolkitViewState: @flutterToolkitView.serialize()

  debug: ->
    console.log '****** DEBUG TODO !'

  toggle: ->
    console.log 'ftk was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
