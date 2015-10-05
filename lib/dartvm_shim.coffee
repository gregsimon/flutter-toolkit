# This is an implementation of _debugger that talks to the DartVM
# over websockets.

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

  connect: =>
    logger.info 'shim', 'connect'

  destroy: =>

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
