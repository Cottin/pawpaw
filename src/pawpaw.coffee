{always, evolve, into, isNil, join, keys, last, map, omit, prepend, range} = require 'ramda' #auto_require:ramda
{cc, isThenable} = require 'ramda-extras'

utils = require './utils'

isIterable = (o) -> !isNil(o) && typeof o[Symbol.iterator] == 'function'

class Pawpaw
	constructor: (treeDefinition) ->
		@keys = keys treeDefinition
		@tree = utils.prepareTree treeDefinition
		@logLevel = 0
		# @logAllUnderKeyCmd = [] TODO
		@execLog = []
		@index = 0

	exec: (query, name) ->
		context = {name, stack: [query]}
		return @_exec query, context

	execIter: (generator, args, name, caller) ->
		context = {name, stack: [name]}

		yieldObject =
			yield: (newQuery) =>
				newContext = evolve {stack: prepend(newQuery)}, context
				@_exec newQuery, newContext

		iterable = generator.apply yieldObject, args
		if !isIterable(iterable)
			throw new Error "generator #{generator} did not return an interable"

		if utils.shouldLog context, @logLevel #, @logAllUnderKeyCmd
			if caller
				console.log "EXEC_ITER (#{name || ''})", caller, args
			else 
				console.log "EXEC_ITER (#{name || ''})", args

		lastYieldResult = undefined
		while true
			next = iterable.next lastYieldResult
			if next.done then return next.value
			else
				newQuery = next.value
				newContext = evolve {stack: prepend(newQuery)}, context
				lastYieldResult = @_exec newQuery, newContext


	_exec: (query, context, playMode = false) ->
		if !playMode then @execLog.push {query, context}
		@index++


		{key, cmd} = utils.extractKeyCmd @keys, query
		if isNil key then throw new Error "No key called #{key}"

		if utils.shouldLog context, @logLevel #, @logAllUnderKeyCmd
			dashes = cc join(''), map(always('-')), range(1, context.stack.length)
			console.log "#{dashes}EXEC (#{context.name || ''})", query

		if playMode && utils.shouldExecuteOnPlay query, @tree
			return

		yieldObject =
			yield: (newQuery) =>
				newContext = evolve {stack: prepend(newQuery)}, context
				@_exec newQuery, newContext, playMode

		args = omit [key], query
		try
			gen = @tree[key][cmd].call yieldObject, args
		catch err
			console.error "exec error", context
			throw new Error "exec error: " + err

		if !isIterable gen then return gen


		# inspiration from: https://www.promisejs.org/generators/
		# Note that I'm cheating a bit not taking into concideration this last part:
		# "Note how we use Promise.resolve to ensure we are always dealing with well behaved promises and we use Promise.reject along with a try/catch block to ensure that synchronous errors are always converted into asynchronous errors."
		# For now haven't had problems but might be good to look into.
		handle = (res) =>
			if res.done then return res.value

			newQuery = res.value
			newContext = evolve {stack: prepend(newQuery)}, context

			if isThenable newQuery

				if utils.shouldLog context, @logLevel #, @logAllUnderKeyCmd
					dashes = cc join(''), map(always('-')), range(1, newContext.stack.length)
					console.log "#{dashes}PROMISE (#{newContext.name || ''})", newQuery

				return Promise.resolve(newQuery)
					.then (val) -> handle gen.next(val)
					.catch (err) -> handle gen.throw(err)

			result = @_exec newQuery, newContext, playMode
			return handle gen.next(result)

		return handle gen.next(undefined)


	loadExecLog: (log, index = 0) ->
		@index = index
		@execLog = log

	playNext: () ->
		{query, context} = @execLog[@index]
		@_exec query, context, true

	goBack: () -> @index--
	goForward: () -> @index++
	goTo: (index) -> @index = index

module.exports = Pawpaw
