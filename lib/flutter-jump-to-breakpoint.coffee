Promise = require 'bluebird'
fs = require 'fs'
url = require 'url'
Module = require 'module'
NonEditableEditorView = require './flutter-non-editable-editor'


PROTOCOL = 'atom-dart-debugger://'

currentMarker = null
cleanupListener = null

exists = (path) ->
  new Promise (resolve) ->
    fs.exists path, (isExisted) ->
      resolve(isExisted)

module.exports = (_debugger) ->
  atom.workspace.addOpener (filename, opts) ->
    parsed = url.parse(filename, true)
    if parsed.protocol is 'atom-dart-debugger:'
      return new NonEditableEditorView({
        uri: filename
        id: parsed.host
        _debugger: _debugger
        query: opts
      })

  cleanupListener = _debugger.onBreak (breakpoint) ->
    currentMarker.destroy() if currentMarker?
    {sourceLine, sourceColumn} = breakpoint
    script = breakpoint.script and breakpoint.script.name
    id = breakpoint.script?.id
    exists(script)
      .then (isExisted)->
        if isExisted
          promise = atom.workspace.open(script, {
            initialLine: sourceLine
            initialColumn: sourceColumn
            activatePane: true
            searchAllPanes: true
          })
        else
          return if not id?
          newSourceName = "#{PROTOCOL}#{id}"
          promise = atom.workspace.open(newSourceName, {
            initialColumn: sourceColumn
            initialLine: sourceLine
            name: script
            searchAllPanes: true
          })

        return promise

      .then (editor) ->
        return if not editor?
        currentMarker = editor.markBufferPosition([
          sourceLine, sourceColumn
        ])
        editor.decorateMarker(currentMarker, {
          type: 'line-number'
          class: 'flutter-debugger-stop-line'
        })

module.exports.cleanup = ->
  currentMarker.destroy() if currentMarker?

module.exports.destroy = ->
  module.exports.cleanup()
  cleanupListener() if cleanupListener?
