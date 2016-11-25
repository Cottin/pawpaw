assert = require 'assert'
{flip, keys, match, type} = require 'ramda' #auto_require:ramda

utils = require './utils'

eq = flip assert.equal
deepEq = flip assert.deepEqual
throws = (f) -> assert.throws f, Error

describe 'utils', ->
	describe 'prepareTree', ->
		it 'simple case', ->
			tree = utils.prepareTree
				a:
					a1: ({a, b, c}) -> a + b + c

			eq 6, tree.a.a1({a: 1, b: 2, c: 3})

		it 'using a function wrapping object',  ->
			tree = utils.prepareTree
				a: ->
					fn = (a, b) -> a + b
					a1: ({a, b}) -> fn a, b

			eq 3, tree.a.a1({a: 1, b: 2})

		it 'using a function for key',  ->
			tree = utils.prepareTree
				a: -> (a, b) -> a + b

			eq 3, tree.a(1, 2)

		# it 'this.yield should be a function', ->
		# 	tree = utils.prepareTree
		# 		a:
		# 			a1: () -> type @yield

		# 	eq 'Function', tree.a.a1()

	describe 'extractKeyCmd', ->
		tree = 
			k:
				k1: ({a, b}) -> a + b
		it 'simple case', ->
			{key, cmd} = utils.extractKeyCmd keys(tree), {k: 'k1', a: 1, b: 1}
			eq 'k', key
			eq 'k1', cmd

		it 'no key', ->
			{key, cmd} = utils.extractKeyCmd keys(tree), {m: 'm1', a: 1, b: 1}
			eq undefined, key
			eq undefined, cmd

		it 'more than one match', ->
			tree = 
				k:
					k1: ({a, b}) -> a + b
				m:
					m1: ({a, b}) -> a + b
			throws ->
				{key, cmd} = utils.extractKeyCmd keys(tree), {m: 'm1', k: 1, b: 1}

	describe 'shouldLog', ->
		it 'simple cases', ->
			eq true, utils.shouldLog {stack: [{a: 1}, {b: 2}]}, 1
			eq false, utils.shouldLog {stack: [{a: 1}, {b: 2}]}, 0


