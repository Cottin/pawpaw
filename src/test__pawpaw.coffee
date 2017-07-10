assert = require 'assert'
{__, all, always, any, flip, join, last, map, match, range, where} = require 'ramda' #auto_require:ramda
{cc} = require 'ramda-extras'

Pawpaw = require './pawpaw'

eq = flip assert.equal
deepEq = flip assert.deepEqual
throws = (re, f) -> assert.throws f, re
peq = (done, x, p) ->
	(p.then (val) ->
		eq x, val
	).then(done).catch(done)

describe 'pawpaw', ->
	describe 'exec', ->
		it 'simple case', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b

			eq 3, tree.exec {k: 'k1', a: 1, b: 2}

		it 'logs with different colors', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> yield {k: 'k2', a, b}
					k2: ({a, b}) -> a + b

			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			eq 3, tree.exec {k: 'k1', a: 1, b: 2}
			# do a manual check in the console to see that there is a rainbow

		it 'simple yield', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
				m:
					m1: ({a}) ->
						ret = yield {k: 'k1', a, b: 10}
						return ret

			tree.logLevel = 999
			eq 11, tree.exec {m: 'm1', a: 1}

		it 'more complex yield', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
				m:
					m1: ({a}) ->
						ret = yield {k: 'k1', a, b: 10}
						return ret
				n:
					n1: ({a}) ->
						return yield {m: 'm1', a: a * a}

			tree.logLevel = 999
			eq 14, tree.exec {n: 'n1', a: 2}

		it 'function as key', ->
			tree = new Pawpaw
				k: -> ({a, b}) -> a + b

			tree.logLevel = 999
			eq 3, tree.exec {k: {a: 1, b: 2}}

		it 'should print stack on error (and throw)', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a() + b

			throws /TypeError: a is not a function/, ->
				tree.exec({k: 'k1', a: 1, b: 2}, 'caller-provoking-error')

		it 'key not in tree', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a() + b

			throws /Pawpaw: Query does not match any key in the tree/, ->
				tree.exec({m: 'k1', a: 1, b: 2}, 'caller-provoking-error')

		it 'cmd not a function', ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a() + b

			throws /Pawpaw: key k does not have command k2/, ->
				tree.exec({k: 'k2', a: 1, b: 2}, 'caller-provoking-error')

		it 'no yield but return of array', ->
			tree = new Pawpaw
				k:
					k1: () -> []

			deepEq [], tree.exec {k: 'k1'}


		it 'stack trace from where error occured', ->
			f1 = () ->
				x = undefined
				x.thisWillThrow()

			tree = new Pawpaw
				k:
					k1: () -> f1()
				m:
					m1: () ->
						ret = yield {k: 'k1'}
						return ret

			# tree.exec({k: 'k1', a: 1, b: 2}, 'nice stack trace')
			throws /Cannot read property 'thisWillThrow' of undefined/, ->
				tree.exec({k: 'k1', a: 1, b: 2}, 'nice stack trace')

	describe 'execManually', ->
		it 'simple', ->
			class ThirdPartyThing
				constructor: ({pub}) ->
					@pub = pub

				sub: (key, meta) ->
					@pub key, meta

			thing = new ThirdPartyThing
				pub: (key, meta) -> tree.execManually({k: 'pub', key}, {}, meta.stack)

			tree = new Pawpaw
				k:
					pub: ({key, meta}) ->
						yield {k: 'write', text: key}
					sub: ({key}) ->
						thing.sub key, {stack: @stack}

					write: ({text}) ->
						yield {write2: {text}}

				write2: -> ({text}) ->
					return text + '__' + @stack.length

			logs = []
			tree.log = ({query, meta, stack}) ->
				dashes = cc join(''), map(always('-')), range(1, stack.length)
				logs.push dashes

			res = tree.exec({k: 'sub', key: 'hej'})
			deepEq ['', '-', '--', '---'], logs
			eq 'hej__4', res


	describe 'execIter', ->
		tree = new Pawpaw
			k:
				k1: ({a, b}) -> a + b
				k2: ({a}) -> a * a
		it 'should throw if not iterable', ->
			throws /Pawpaw: generator did not return an iterable:/, ->
				tree.execIter -> {a: 1}

		it 'should handle the result of a generator', ->
			f = (a, b) ->
				res = yield {k: 'k1', a, b}
				res_ = yield {k: 'k2', a: res}
				return res_
			tree.logLevel = 999
			eq 9, tree.execIter f, [1, 2], 'called-by-me'


	# put all async tests last so we don't mess up the order of log messages
	describe 'async exec', ->

		# it 'simple async function not using promise', (done) ->
		# 	tree = new Pawpaw
		# 		k:
		# 			k1: ({a, b}) -> a + b
		# 			k2: ({a, b}) ->
		# 				asyncFn = () =>
		# 					res = @yield {k: 'k1', a, b}
		# 					eq 3, res
		# 					done()
		# 				setTimeout asyncFn, 0

		# 	tree.logLevel = 999
		# 	tree.exec {k: 'k2', a: 1, b: 2}

		it 'promise', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
					k2: ({a, b}) ->
						x = yield {k: 'k1', a, b}
						x_ = yield new Promise (res, rej) ->
							f1 = ->
								res x + 1
							setTimeout f1, 1

						x__ = yield {k: 'k1', a: 1, b: x_}
						return x__

			tree.logLevel = 999
			res = tree.exec({k: 'k2', a: 1, b: 2})
			peq done, 5, res

		it 'promise exception', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
					k2: ({a, b}) ->
						x = yield {k: 'k1', a, b}
						x_ = yield new Promise (res, rej) ->
							f1 = ->
								rej new Error('This is an error')
							setTimeout f1, 1
						x__ = yield {k: 'k1', a: 1, b: x_}
						return x__

			tree.logLevel = 999
			res = tree.exec({k: 'k2', a: 1, b: 2})
			res.catch (err) ->
				console.log 'err', err
				done()

		it 'multiple promises', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
					k2: ({a, b}) ->
						x = yield {k: 'k1', a, b}
						x_ = yield new Promise (res, rej) ->
							f1 = ->
								res x + 1
							setTimeout f1, 1
						x__ = yield new Promise (res, rej) ->
							f1 = ->
								res x_ + 1
							setTimeout f1, 1
						x___ = yield {k: 'k1', a: 1, b: x__}
						return x___

			tree.logLevel = 999
			res = tree.exec({k: 'k2', a: 1, b: 2})
			peq done, 6, res

		it 'promise in separate function', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
					k2: ({a}) ->
						x = yield new Promise (res, rej) ->
							f1 = ->
								res a + 1
							setTimeout f1, 10
						return x

					k3: ({a, b}) ->
						x = yield {k: 'k1', a, b}
						x_ = yield {k: 'k2', a: x}
						x__ = yield {k: 'k1', a: 1, b: x_}
						return x__

			res = tree.exec({k: 'k3', a: 1, b: 2})
			peq done, 5, res

		# it 'nested promises', (done) -> # TODO?

	describe 'async execIter', ->

		# note: I don't see the point of using promises in the iter itself.
		# In most cases those promises will be made inside the function tree, since
		# the point (or at least one point) is that we want to handle async things
		# inside the function tree
		it 'calling promise in tree', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a, b}) -> a + b
					k2: ({a, b}) ->
						x = yield {k: 'k1', a, b}
						x_ = yield new Promise (res, rej) ->
							f1 = ->
								res x + 1
							setTimeout f1, 1
						x__ = yield {k: 'k1', a: 1, b: x_}
						return x__


			f = (a, b) ->
				res = yield {k: 'k1', a, b}
				res_ = yield {k: 'k2', a: res, b: 1}
				return res_
			tree.logLevel = 999

			res = tree.execIter f, [1, 2], 'called-by-me2'
			peq done, 6, res

		it 'promise waiting in iter', (done) ->
			tree = new Pawpaw
				k:
					k1: ({a}) -> 
						new Promise (res, rej) ->
							f1 = ->
								res a + 1
							setTimeout f1, 10
					k2: ({a, b}) -> a + b
					k3: ({a}) ->
						x = yield {k: 'k1', a: 1}
						return x + 1

			f = (a) ->
				res = yield {k: 'k1', a}
				res_ = yield {k: 'k2', a: res, b: 1}
				return res_
			# f2 and k3 are only included as references for how pawpaw behaves when
			# waiting for yield inside of tree
			f2 = (a) ->
				res = yield {k: 'k3', a}
				return res
			tree.logLevel = 999

			res = tree.execIter f, [1], 'called-by-me2'
			peq done, 3, res

