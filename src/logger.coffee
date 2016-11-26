# note: this could be a bit interesting: https://github.com/icodeforlove/Console.js
#       and https://github.com/chalk/chalk

colorNames = ['red', 'green', 'yellow', 'blue', 'magenta', 'cyan']

_colors =
	# most terminals seem to only support 8 bits, so for now we'll do like that
	node:
		red: '\x1b[31m'
		green: '\x1b[32m'
		yellow: '\x1b[33m'
		blue: '\x1b[34m'
		magenta: '\x1b[35m'
		cyan: '\x1b[36m'
	browser:
		red: '#FFBCB7'
		green: '#9BE9A8'
		yellow: '#F5F1A6'
		blue: '#D0E7FE'
		magenta: '#FBDFFA'
		cyan: '#F5D2A6' # this is brown not cyan... because cyan isn't nice :)
	
log = (colorName, text, obj) ->
	isNode = typeof window == 'undefined'
	if isNode
		_logNode colorName, text, obj
	else
		_logBrowser colorName, text, obj

_logNode = (colorName, text, obj) ->
	color = _colors.node[colorName]
	reset = '\x1b[0m'
	if obj then console.log color, text, reset, obj
	else console.log color, text, reset

_logBrowser = (colorName, text, obj) ->
	color = _colors.browser[colorName]
	if obj then console.log "%c #{text}", "background:#{color}", obj
	else console.log "%c #{text}", "background:#{color}", obj

module.exports = {log, colorNames}
