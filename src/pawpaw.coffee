{all, always, any, call, contains, head, into, isEmpty, isNil, join, keys, last, map, match, omit, prepend, prop, range, replace, test, type, where, wrap} = R = require 'ramda' #auto_require:ramda
{cc, isThenable} = require 'ramda-extras'

utils = require './utils'
logger = require './logger'

isIterable = (o) -> !isNil(o) && typeof o[Symbol.iterator] == 'function'

ERR = 'Pawpaw: '


class Pawpaw
	# Creates a pawpaw tree (an instance of Pawpaw) based on your treeDefinition
	constructor: (treeDefinition) ->
		@keys = keys treeDefinition
		@tree = utils.prepareTree treeDefinition
		@index = -1
		@topLevelIndex = -1

	# Executes a query towards your Pawpaw tree.
	# Use meta to put any data you want for using in logging
	exec: (query, meta) -> @_exec query, meta, []

	# Use if you manually want to be in control of the stack, eg. if you're
	# integrating callbacks from a third-party or other code with you're tree
	# and want to keep coloring and indentations correct. See tests for example.
	execManually: (query, meta, stack) -> @_exec query, meta, stack

	# The default logger. Feel free to replace this with you own logger by doing:
	# pawpawInstance.log = () -> ...
	log: ({query, meta, stack}) ->
		firstIndex = cc prop('topLevelIndex'), last, stack
		colorName = logger.colorNames[firstIndex % logger.colorNames.length]
		dashes = cc join(''), map(always('-')), range(1, stack.length)
		if isThenable query
			if query.meta then logger.log colorName, "#{dashes}PROMISE", query.meta, query
			else logger.log colorName, "#{dashes}PROMISE", query
		else
			logger.log colorName, "#{dashes}EXEC", query

	# Helper method that simplifies if you have a generator function outside of
	# your pawpaw tree that contains one or more yield {...query...} and you want
	# to call that function and execute all queries inside it agains your pawpaw
	# tree.
	execIter: (generator, args, meta) =>
		iterable = generator.apply undefined, args

		if !isIterable iterable
			console.error ERR, generator, 'applied with', args, '=', JSON.stringify(iterable)
			throw new Error ERR + "generator did not return an iterable:", iterable

		@index++
		query = {execIter: meta} # kind of a "fake" query made for log purposes
		stack = prepend {query, index: @index}, []
		@topLevelIndex++
		head(stack).topLevelIndex = @topLevelIndex
		@log {query, meta, stack}
		@_iterate(iterable, meta, stack)(iterable.next(undefined))


	_exec: (query, meta, prevStack) ->
		@index++
		stack = prepend {query, index: @index}, prevStack
		if isEmpty prevStack
			@topLevelIndex++
			head(stack).topLevelIndex = @topLevelIndex

		{key, cmd} = utils.extractKeyCmd @keys, query
		if isNil key
			console.error ERR + 'Query does not match any key in the tree.
			 Stack:', stack
			throw new Error ERR + 'Query does not match any key in the tree'

		@log {query, meta, stack}

		if ! test /^Function|GeneratorFunction$/, type(@tree[key])
			args = omit [key], query
			f = @tree[key][cmd]
			if isNil(f) || ! test /^Function|GeneratorFunction$/, type(f)
				console.error ERR + "key #{key} does not have command #{cmd}.
				 Stack:", stack
				throw new Error ERR + "key #{key} does not have command #{cmd}"
			gen = f.call {stack}, args
		else # function as key
			args = cmd
			gen = @tree[key].call {stack}, args
		
		# NOTE: if we wrap in try catch, the stack looks the same but the file that
		# 			gets linked in chrome dev tools is bundle.js instead of the file
		# 			where the actual error occured. So, skip the try .. catch for now
		# catch err
		# 	console.error "Pawpaw, error in tree execution: ", JSON.stringify(stack[0].query), stack
		# 	# important to throw err and not new Error to get original stack trace
		# 	throw err

		if !isIterable(gen) || type(gen.next) != 'Function' then return gen

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
		if isThenable result
			return Promise.resolve(result)
				.then (val) => @_iterate(gen, meta, prevStack)(gen.next(val))
				.catch (err) =>
					console.error 'error in promise', stack
					@_iterate(gen, meta, stack)(gen.throw(err))

		return @_iterate(gen, meta, prevStack)(gen.next(result))



module.exports = Pawpaw

