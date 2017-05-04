
![](https://rawgit.com/Cottin/pawpaw/master/docs/pawpaw.svg)
# Pawpaw
Some parts of your applications are pure, but some parts are inherently full of side effects, eg. http-requests, websocket, local storage, etc.

Pawpaw lets you write the "side-effecty" parts of your application in a simple tree where all the code looks synchronous (using `yield`).

## How it works

**1 - You write your functions in a tree where you can group similar functions together under the same key:**

```
app = import './application'

const pawpaw = new Pawpaw({
	Data: {
		read: ({path}) => app.read(path)
		write: ({path, value}) = > app.write(path, value)
	},
	RestAPI: {
		create: () => ...
		read: () => ...
		update: () => ...
		delete: () => ...
	}
})
```

**2 - You use a query to call your functions. A query is a simple javascript object:**

```
const data = pawpaw.exec({Data: 'read', path: 'customers'})
pawpaw.exec({RestAPI: 'create', ...})
```

**3 - Functions in the tree can call other functions in the tree by using the `yield` keyword:**

```
	RestAPI: {
		read: (objectType, id, path) => {
			const data = api.fetch(`/api/${objectType}/${id}`)
			yield {Data: 'write', path: objectType, value: data}
		}
	}
```

**4 - The functions can handle promises so async programming gets quite simple:**

```
	Customers: {
		get: (id) => {
			yield {Data: 'write', path: `syncStatus/Customer/${id}`, value: 'pedning'}
			try {
				// NOTE: fetch is not part of the function tree it is
				// javascript's fetch api that returns a promise
				const response = yield fetch(`api/customers/${id}`, {mode: 'cors'})

				const customer = response.json()
				yield {Data: 'write', path: `Customer/${id}`, value: customer}
				yield {Data: 'write', path: `syncStatus/Customer/${id}`, value: 'finished'}
			}
			catch (err) {
				yield {Data: 'write', path: `syncStatus/Customer/${id}`, value: 'finished'}
			}
		}
	}
```

**5 - Queries and function calls in the tree will be logged so you can easily do some debugging.**

## Why?
What you get is essentially:

0. One place in your code that contains all the side-effectful functions.
0. Writing async code in a synchronous manner using `yield`.
0. Concise code using `yield` and queries to compose functions in the tree.

## Examples
Comming late...



