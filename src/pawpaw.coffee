{all, always, any, call, contains, into, isNil, join, keys, last, map, omit, prepend, prop, range, replace, type} = require 'ramda' #auto_require:ramda
{cc, isThenable} = require 'ramda-extras'

utils = require './utils'
logger = require './logger'

isIterable = (o) -> !isNil(o) && typeof o[Symbol.iterator] == 'function'


class Pawpaw
	# Creates a pawpaw tree (an instance of Pawpaw) based on your treeDefinition
	constructor: (treeDefinition) ->
		@keys = keys treeDefinition
		@tree = utils.prepareTree treeDefinition
		@index = -1

	# Executes a query towards your Pawpaw tree.
	# Use meta to put any data you want for using in logging
	exec: (query, meta) -> @_exec query, meta, []

	# The default logger. Feel free to replace this with you own logger by doing:
	# pawpawInstance.log = () -> ...
	log: ({query, meta, stack}) ->
		firstIndex = cc prop('index'), last, stack
		colorName = logger.colorNames[firstIndex % logger.colorNames.length]
		dashes = cc join(''), map(always('-')), range(1, stack.length)
		text = if isThenable query then 'PROMISE' else 'EXEC'
		logger.log colorName, "#{dashes}#{text}", query

	# Helper method that simplifies if you have a generator function outside of
	# your pawpaw tree that contains one or more yield {...query...} and you want
	# to call that function and execute all queries inside it agains your pawpaw
	# tree.
	execIter: (generator, args, meta) =>
		iterable = generator.apply undefined, args

		lastYieldResult = null
		while true
			next = iterable.next lastYieldResult
			if next.done then return next.value
			else
				query = next.value
				lastYieldResult = @exec query, meta


	_exec: (query, meta, prevStack) ->
		@index++
		stack = prepend {query, index: @index}, prevStack

		{key, cmd} = utils.extractKeyCmd @keys, query
		if isNil key
			console.error "No key called #{key}", stack
			throw new Error "No key called #{key}"

		@log {query, meta, stack}

		try
			if type(cmd) == 'String'
				args = omit [key], query
				gen = @tree[key][cmd].call undefined, args
			else # function as key
				args = cmd
				gen = @tree[key].call undefined, args

		catch err
			console.error "exec error", stack
			throw new Error "exec error: " + err

		if !isIterable gen then return gen

		@_iterate(gen, meta, stack)(gen.next(undefined))


	# inspiration from: https://www.promisejs.org/generators/
	# Note that I'm cheating a bit not taking into concideration this last part:
	# "Note how we use Promise.resolve to ensure we are always dealing with well behaved promises and we use Promise.reject along with a try/catch block to ensure that synchronous errors are always converted into asynchronous errors."
	# For now haven't had problems but might be good to look into.
	_iterate: (gen, meta, prevStack) => (res) =>
		if res.done then return res.value

		query = res.value

		if isThenable query
			@index++
			stack = prepend {query, index: @index}, prevStack
			@log {query, meta, stack}
			return Promise.resolve(query)
				.then (val) => @_iterate(gen, meta, prevStack)(gen.next(val))
				.catch (err) =>
					console.error 'error in promise', stack
					@_iterate(gen, meta, stack)(gen.throw(err))

		result = @_exec query, meta, prevStack
		return @_iterate(gen, meta, prevStack)(gen.next(result))




module.exports = Pawpaw

