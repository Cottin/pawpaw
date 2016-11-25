{head, intersection, keys, length, mapObjIndexed, type} = require 'ramda' #auto_require:ramda

_prepareKey = (node) ->
	if type(node) == 'Function'
		return node()

	return node

prepareTree = (treeDefinition, yieldCallback) ->
	mapObjIndexed _prepareKey, treeDefinition

extractKeyCmd = (keysInTree, query) ->
	inBoth = intersection keysInTree, keys(query)

	if length(inBoth) > 1
		throw new Error "duplicate matches found (#{inBoth}) for query #{query}"

	key = head inBoth
	return {key, cmd: query[key]}

shouldLog = (context, logLevel) ->
	return context.stack.length <= logLevel + 1


module.exports = {prepareTree, extractKeyCmd, shouldLog}
