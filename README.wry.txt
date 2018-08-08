project : HTML Element Composer
	author : Mike Weaver
	created : 2018-06-13
	copyright : © 2018 All rights reserved.
	license : See [*License].

A scripting language for web authoring.

section : Grammar

	See {wry grammar}[*grammars/Wry.g4].

section : Types

	There are (at least) seven types: `Integer`, `Float`, `Bool`, `String`,
	`Null`, `Array`, and `Function`. The `Array` type replaces what would be
	arrays, dictionaries, class instances, and parameter lists in other
	languages. It is an ordered map and behaves similarly to PHP's array type.

	!!!
		Not sure if anyone else has coined this already, but I think I'll refer to
		the data structure that implements arrays as a "sortmap".

	!!!
		Probably a "chain" (or whatever I call it, maybe "stack"?) will be another
		type. It's a stack of arrays. Functions and chains can also be combined,
		and is that a different type or is that still a function type (just with
		some data already chained to it)?

	The simple types (`Integer`, `Float`, `Bool`, `String`, `Null`) will be
	familiar to users of other languages, and can be created with literals that
	are obvious.

	```
		count = 7
		radius = 13.6
		isChecked = false
		employee = "John Smith"
		flag = null

	Those 5 simple types are scalars, whereas the `Array` type is a compound
	object.

section : Arrays

	Arrays are an ordered hashmap. That means it preserves the order of the keys
	as items are inserted into the array. (Implementing it means something like a
	hashmap combined with a linked list, I'm going to call it a "sortmap".)

	To create an array, list out elements (keys and values) separated by commas.
	A trailing comma is allowed, and in fact is often useful to coerce something
	to an array. An array can be a simple list of other types (no keys), in which
	case incrementing integer keys will automatically be applied. Or it can be
	more like a dictionary with keys and values, separate by colons and commas.
	Keys are of type `String` or `Int`, or expressions that evaluate to one of
	these. Entries in the array can be retrieved by key.

	```
		employee = ('first': 'mike', 'last': 'weaver', 'empl-id': 1234, 10.5)

	This syntax is similar to creating a dictionary in other languages, say JSON.
	The parenthesis are needed because of operator precedence. Without them
	`employee` would be the first item in a much different array, instead of
	being the name to which the array is assigned.

	!!!
		Or it might be a syntax error. Without parenthesis the statement would be
		interpreted as

		```
			(employee = 'first') : 'mike', ...

	Which would be a syntax error. The first term in parenthesis is an assignment
	which doesn't return a value so can't be used as a key in an array.

	An `Array` of items without keys is declared in a similar way:

	```
		cutoffs = (15.0, 25.0, 47.0)

	The items in the array are accessed with a subscript operator that uses
	square brackets. Inside the brackets use an expression that evaluates to
	either an `Int` or `String` that represents the key.

	```
		cutoffs[0] // 15.0
		employee['first'] // 'mike'
		key = 'first'
		employee[key] // 'mike'

	An alternate way to retrieve keyed items in the array uses a dot syntax. In
	this case, the key for the item must be a string that is also a valid name.

	```
		employee.first // equivalent to employee['first']

	!!! Experimental subscripts

		Multiple items can be accessed using multiple items in the subscript,
		separated by commas. Expressions that resolve to other than String or
		Integer will emit a warning.

		```
			cutoffs[0, 2] //  0 and 1
			employee['first', 'empl-id']

		The two expressions above, instead of returning a single item from the
		original array, will each return an array with two items. Integer indices
		in the returned array will be reset to 0, but string keys will be
		preserved from the original. (... or, why not preserve integer indices? we
		can always have a method to "reset" array indices if that is desirable.)

		Would this kind of syntax be allowed as an lvalue?

	Arrays keys can be declared in different ways. The following are equivalent:

	```
		mydata = ('name': 'mike', 'age': 15)
		mydata = (name='mike', age=15)
		name = 'mike'
		age = 15
		mydata = (~name, ~age)
		mydata
			name = 'mike'
			age = 15
		mydata
			'name': 'mike'
			'age': 15
		'mydata': ('name': 'mike', 'age': 15)

	So when declaring keys, one can use a string, or an expression that evaluates
	to a string, followed by a colon. Or one can use a bare name (no quotes) and
	an equals sign. Or one can use multiple lines and indentation to layout the
	structure of the array. A tilde preceding a bare name converts it as follows:
	`~name` is expanded to `'name': name` where the expression on the left is a
	string, and the expression on the right will be evaluated.

	I was also thinking of an instance where, using indentation, if we need a
	non-named array we can use a bare comma:

	```
		people
			,   # Or maybe empty brackets `[]`, or empty parens `()`
				'name': 'mike'
				'age': 42
			,   # Another option might be to use a bare underscore: _
				'name': 'fred'
				'age': 34

	!!!
		I'm liking empty parens as representative of an empty array. Also use to
		initialize an empty array.
	!!!
		This of course screams out to use records.

!!! Continue converting this into wry prose.

A bare expression (something that is not part of an assignment statement) will act as an
assignment into the local scope, using the next integer key.

Do we need syntax for appending to an array? PHP makes this simple using empty brackets to
represent "the next available slot".

  	b[] = "next"

Do we want something like that? I'm currently thinking we use the `+` operator:

  	b += 'next'

  	a = b + ( 'surname' : 'thompson' )

What if we need to declare an array of arrays? I think we can do that with parens and
trailing commas:

  	b = (1, 2, 3)
  	c = b + 4
  	d = b + (4,5,6)
  	e = b + ((4,5,6),)



### Local Scope

Whatever the current scope is, its variables can be accessed via `$loc`, as follows:

  	$loc['a']['name'] = 'Fred'
  	print $loc.a['name']
  	print $loc.a.name
  	print $loc['a'].name

Normally, the search to resolve a name will start with `$loc`, so usually it is not
necessary to explicitly reference it.

This works:

  	$loc['count'] = 100
  	start = 0
  	stop = count

Another way to affect the scope is the `with` statement. This is also a way to append to
an array. All of these are equivalent. The `with` statement makes the array `a` the local
scope and expressions and statements affect `a`.

  	a.name = 'Fred'
  	a['name'] = 'Fred'
  	with a
 			name = 'Fred'

Conceptually the `with` statement is pushing a new scope (for `a`) onto the scope stack
and then popping it off after the with block is done. Any assignments or bare expressions
will affect the current scope, `a`. This makes it easy to construct an array and use
branching statements to conditionally add elements to the array.

  	hasSurname = true
  	a
 			name = 'Fred
 			if needsSurname surname = "Thompson"

We can also use the `with` statement to create a temporary scope where we may override
values outside. I'm not sure how I want that syntax to look:

	func bailout
		...

	with
		func bailout   // Overrides the bailout function at the outer level.
			...
			...
		bailout()

	bailout()   // Calls the original, outer `bailout`.

Maybe a "bare" `with` as above. Or maybe a `with` statement followed by an underscore. We
should also allow for labels in case we want to be able to refer to overriden values at
specific points in the hierarchy. (Which begs the question, how do we refer to the outermost
$out if we are several levels deep?) (This also begs the question, why would you need/want to
do this?)



### Importing files

Scripts can be split into multiple files and then included inside one another. We want to
be able to include a file, but keep it somewhat isolated from the current scope, to avoid
collisions. When a file is included, using the `wend` statement, it create a new level
in the scope hierarchy. The current hierarchy is pushed, or "wound", up the stack; the
included file is executed in its own scope, and then _that_ is wound up the stack and a
new scope level opened for the rest of the script.

This allows one, for example, to set variables prior to the `wend` statement that will affect
the execution of the imported file, and still be available (if not overridden) to later
parts of the script. It also allows the author to override something in the included file,
because the override is happening at the current (lower) scope level. A `wend` statement can
include a label so one can refer back to objects explicitly at that level. As with the above
discussion on local scope, this begs the question of how we refer to a scope that has been
pushed above a `wend` or `with` statement. Perhaps we allow for a label like this:

	#script

	...

	wend 'include/inc-standard.wry' #standard

	func bailout   // This overrides the function defined in 'inc-standard'.
		@standard.bailout()   // Call the overridden function <- need to think about syntax,

	@script.some_var

The act of pushing the scope up the stack will be triggered by a `wend` statement
and also by EOF.

Similar to the bare `with` above (and maybe, replacing it) would be a bare `wend` statement
which would push the current scope up the stack and open up a new one. This would let you
override something in the current scope, but still make it available if needed.

	#current

	myFunc = ...   // define something

	wend #next

	myFunc = ...   // will override (but not replace) the prior one

	myFunc()

	@current.myFunc()   // reaches back to version defined prior to `wend`

section : Loops

	!!!
		2018-04-26: I'm thinking instead of `continue`, the keyword to loop back
		should be `repeat`, which meaning is a little more obvious.

	There are two loop statements, `do`, and `for`. `for` takes an array and
	iterates through the elements of the array, providing variables `key` and
	`val` to the statements inside the block at each iteration. The `for`
	statement, unlike `do`, does *NOT* need an explicit `continue` at the bottom.

	!!!
		Question: should `val` be a reference to the array element, instead of a
		copy? One could always access the original object using the `key`. For
		instance, suppose we wanted to iterate over an array of numbers and add 1
		to each one:
		```
			for arr_of_numbers
				arr_of_numbers[key] += 1
			array_of_numbers->map({ $obj[key] += 1})

	!!!
		2018-04-26: With `for` loops, if they are nested, we need to distinguish
		between `key` and `val` at different levels. Perhaps the `for` loop needs
		a way to specify what variables we want to use, and `key` and `val` are
		the defaults if not specified.

	```
		for array_of_stuff
			// we can use key and val

		for array_of_stuff use index=value
			// now we can use variables index and value.

		for array_of_stuff<key,val>
			for val<iKey,iVal>
				...
		for array_of_stuff #outer
			for val #inner
				// here we can use key and val, but also
				// @outer.key and @outer.val ????

	!!!
		I like that last one, it uses labels and hints at the notion of nested
		scopes, so does that mean there is some sort of implicit wend going on
		with the loops? It also has cleaner syntax, because we don't have to
		introduce a new keyword `as` or `using` or something.
	!!!
		Good question about scopes. In PHP, variables defined inside of loops or
		branches are available outside the loop or branch, which I prefer to, say
		C++ where brackets introduce a new scope, even for if and while
		statements.
	!!!
		I'm starting to think of angle brackets as the syntax to use for
		"placeholders", whatever that might mean in different contexts.

The `do` statement begins a block of code that can be repeated with a `continue` statement
somewhere inside the block. The `do` block can also be exited with a `break` statement. If
the block is never "broken" out of, then an optional, trailing `then` block will be
executed. But if a `break` occurs, the `then` block will be skipped. (`break`, `continue`,
and `then` also apply the same to a `for` block.)

  	do
 			<some stuff>
 			if <expression> continue   // Skip the remaining statements and start loop over.
 			<some stuff>
 			if <expression> break   // Stop iterating and jump past the `then` block.
 			continue
  	then
 			<some stuff>   // Will only be executed if there was no `break` above.

Many loops will start with a test, similar to a standard `while` statement in C:

  	do
 			if !<while-condition> break
 				...

To keep the syntax clean (and prevent excessive indenting), a special form of the `do`
statement allows for a test at the top of the loop:

  	do if <condition>
 			<some stuff>
  	then
 			<some stuff>   // Executed even if we fail the condition, as long as no break.

It's very common to have an incrementing statement right before continue, such as:

  	i = 0
  	do if i < max
 			<statements>
 			i += 1
 			continue

To clean that up a bit, both `continue` and `break` allow for a statement after, to
capture change to the iterator variable, for example.

  	i = 0
  	do if i<max
 			<some stuff>
 			continue i += 1

This nicely keeps the logic controlling the loop close to the important `do-if` and
`continue` statements.

Both `do` and `for` statements can be given a label, and `break` and `continue` can refer
to that label in order to break out of nested loops.

  	do #outer
 			<some stuff>
 			do #inner
					<some stuff>
					if <expression> break @outer
 			<some stuff>
  	then
 			<stuff>   // won't be called if we broke out of the #outer loop

!!!
	Do we use the octothorpe on the break statement? Or would it be more appropriate
	to use the ampersand? Or do we need any punctuation at all? We probably don't
	_need_ punctuation, but it is probably useful as a visual marker.

The label always comes at the end of the line, so `do-if` has its test expression first,
then the label. And `continue` could have an optional incrementing statement first, then
the label, if any.

If we do exceptions, then we will "throw" an array, and we can test the array, using
`$exc`, to determine how we want to handle it in the `catch` clause, like so

  	try
 			<some stuff>
  	catch if $exc.name == 'error'
 			<stuff>
  	catch if $exc.name == 'blahblahblah'
 			<stuff>
  	catch
 			<stuff>   // for all other exceptions

I don't think we'll need a `finally` statement, because we'll adopt the concept of `defer`
from Swift.



### Object Serializing

Maybe we can borrow from the ideas behind dStruct and create a mechanism to save arrays in
a database. There can be some initialization files or configuration files that grant the
script access to a database, and then simple calls like this will make objects permanent
from one run of the script to another:

  	$dbs['person'] += ('name': 'Mike', 'age': 24)

  	for $dbs['persons']
 			<do something with all the persons returned from the database>

I think to make this work, we'll need hooks that are called when array items are `set` or
`get`. Those could be buried away and hidden from the user, or made available for anyone
to take advantage of them.

I'm thinking something similar (`$fil`) will be used to manage access to the file system.



### Functions

To create a function, use the keyword `func` to open a new block and then write
statements in an indented block that follows.
```
  	func celsiusFromFahrenheit
 			return ($0-32.0)*5.0/9.0
```
Calling the function is accomplished by appending parenthesis after a name. The
parenthesis can be empty, or they can contain array entries that will be passed in as
arguments and available inside the function via `$arg`.

You can also compose an array with a function call, and the array will be available inside
the function as `$obj`. Inside the function, name resolution follows a search path through
`$loc`, `$arg`, `$obj`, and finally `$out`. These arrays can be referenced explicitly or
searching will happen implicitly in the given order. Note that `$arg` is read-only,
whereas `$obj` is a reference to the original object, so changes to `$obj` inside the
function will be visible outside (or after) the function.

When passing similarly named arguments from one function to another, the tilde syntax
(`~name`) becomes very useful. And if an entire array needs to be passed, used double
tilde syntax: `~~name`.

When an array, `b`, is composed with a function, the search to resolve the function name
begins in `b` and then (if not found) search begins in the local scope. The result is that
composing becomes a natural way to call functions that are defined inside an array. (It
behaves like member lookup.)

Suppose we have an array `p` in the local scope that has been set up as a Person object,
with a first and last name, and a function `fullName`. Ignoring for the moment how we set
up this object, we would call the `fullName` method like so:

  	s = p->fullName()

Because of the compose operator, the process of resolving the name "fullName" will begin
with `p`, where it will indeed find a function under the key "fullName". The function will
be called with `p` as the `$obj`. If instead we did any of the following:

  	p.fullName()
  	p['fullName']()

the function would be found and called, but it would not have the `$obj` array as expected
and would probably produce meaningless results. We can "hijack" the function, being able
to make a good guess what it does, and do something strange like this:

  	imposter = ( 'firstName': 'Mike', 'lastName': 'Smith' )
  	imposter->p.fullName()

and would probably get the results we expected. Now the `fullName` function has an `$obj`
array with the entries it expects to see.

This is sort of a convoluted example because if all we really cared about was composing
a full name, we might want to pass first and last names in as (read-only) arguments,
rather than composing with an object. But here we are trying to provide an example of an
object (the Person) that includes data and functions to work on that data.
So there you go.

Related to this, if we have a function with the same name defined in the local
scope, it _won't_ get called by the straightforward composition operator. We instead have
to explicitly refer to it's containing scope (`$loc`), like so:

  	p->$loc.fullName()

Some functions don't need named parameters, so a simple array object can be provided.
Internally, the function refers to the arguments with an automatic variable `$arg`.

  	func sum
 			t = 0
 			for $arg t += $val
 			return t

The `for` block operates on an array in a loop, and at each iteration provides variables
`key` and `val` for the current entry.

  	total = sum(1, 2, 3, 4) // returns 10

Often the variables we use to construct an array share the same name as the key we
use in the array:

  	values = ( 'name' : name, 'id' : id, )

For this case we have a shortcut syntax using the tilde (`~`):

  	key = 'class'
  	value = 'ampm'
  	a = ( 'key' : key, 'value' : value)
  	// or
  	a = ( ~key, ~value)

A function can return a value, using the `return` statement. If a function does not
explicitly return a value and is chained to another function, then the original `$obj`
scope will be passed to the next function in the chain. If it returns a value, however,
then that value will take over and replace the `$obj` scope for the next function in the
chain. (Note that a function that returns a value is interpreted, at the call site, as an
expression and the returned value will be added to the current scope.)

Maybe another way to think about that last paragraph is that if a function
doesn't have a  return statement, it should be considered to have an implicit
`return $obj` (which brings up questions about copies vs references).

Suppose we have this function defined:

  	func transformer
 			$obj['name'] ?= "anonymous"

Note: The `?=` operator tests if a name is defined and, if not, assigns the value on the
right.

  	some_array -> transformer() -> print()

The above passes the object to transformer, which inserts a 'name' key (if it doesn't
exist already) and, by lacking a return statement, implicitly passes it's original `$obj`
as the `$obj` to the next function.

The idea here is that composing allows you to change the original array. Values passed in
as arguments aren't intended to be changed (they can be, but the changes die when the
function exits).

Closures. I think we can achieve something similar to closures by composing an object with
a function, but not calling the function. The resulting value will be--what should we call
it, a `Composition`?--something that can be executed but already has it's `$obj` bundled
with it. Really it's a function with some extra data tagging along with it. You can even
compose something with it when you call it, and the earlier composition will still be
first in the scope resolution hierarchy.

If the function is a member of an array, then other properties of that array should be
available to the function by default. (They will be, under composition, because they will
be found in `$obj`, as long as they are not hidden by something in `$loc` or `$arg`, which
are checked first.)

Here is an example from PHP and wCommon. We have a function, `addButtons`, that takes
an array of button definitions (each of those is itself an array), rearranges the info for
each button into the standard parts of an HTML element, and calls `addElement` to add the
button to our eventual HTML output (also wrapping it in its own 'p' element). `addButtons`
is defined in a 'FormBuilder' object that has a member, `cp`, a Composer, to accumulate
the HTML output. So in the PHP code, `$this` refers to the FormBuilder, and `cp` is its
member.

Here is how this function looks in PHP:

  	// in PHP
  	function addButtons($butts) {
 			$this->cp->beginElement('p');
 			foreach ($butts as $items) {
					if (!$items['type']) { $items['type'] = 'submit'; }
					if (!$items['name']) { $items['name'] = self::KEY_ACTION; }
					if (!$items['id']) { $items['id'] = $items['name'] . '-' . $items['value']; }
					$attribs = array_intersect_key($items, array_flip('type', 'name', 'id', 'value'));
					$attribs = array_merge($attribs, $items['xattr']);
					$this->cp->addElement('button', $attribs, $items['content']);
 			}
 			$this->cp->endElement();
  	}

If a button wasn't defined with a 'type', then it gets the default 'submit'. A default
'name' is similarly supplied. If it doesn't have an 'id', then one is created by
concatenating 'name' and 'value'. The caller can pass in extra attributes (such as "class"
or "onclick") via 'xattr'. And so on (you can go check it out in
[wCommon](https://github.com/wevrem/wCommon) for more details).

And here is how it could look in wry:

  	// in wry
  	func addButtons   // pass in an array of button objects
 			cp->beginElement('p')
 			for $args
					$val.type ?= 'submit'
					$val.name ?= keyAction
					$val.id ?= $val.name + '-' + $val.value
					attribs = $val['type', 'id', 'name', 'value'] + $val.xattr
					cp->addElement('button', ~attribs, ~$val.content)
 			cp->endElement()


We would call this function like so:

  	buttons
 			value='submit', content='Submit'
 			value='cancel', content='Cancel'

  	fb->addButtons(buttons)

where `fb` is an object representing a `FormBuilder`.

With records, *a la* [SAM](https://github.com/mbakeranalecta/sam), we could even do this:

  	buttons :: value, content
 			'submit', 'Submit'
 			'cancel', 'Cancel'

Let's look at the function that the one above relies on, it is `getElement` in the
composer object. This has an interesting (and probably poorly designed) signature where it
will accept an array of attributes, but if instead the caller passes a string, it will be
interpreted as a "class" attribute and an attribute array constructed from it.
This makes it convenient to call the function with a
simple class name (which will often be the use case) instead of having to construct an
array around that class name. In wry we don't have to do those sorts of gymnastics.

  	// in PHP
  	protected static function getElement($elem, $attribs=[], $content='', $close=false) {
 			if (is_string($attribs)) { $attribs = [ 'class'=>$attribs ]; }
 			else if (!is_array($attribs)) { $attribs = []; }
 			if ($class = $attribs['class']) { self::registerClass($class); }
 			$attribString = implode(' ', array_key_map('attribParam', array_filter($attribs, 'is_not_null')));   //(1)
 			if (self::isEmptyElement($elem)) {
					return '<' . $elem . prefixIfCe($attribString, ' ') . ' />';
 			} else {
					return '<' . $elem . prefixIfCe($attribString, ' ') . '>' . $content . ( $close ? "</$elem>" : '' );
 			}
  	}

  	// in wry
  	func getElement   //(elem, class?, attribs?, content?, close?=false)
 			if class attribs.class = class
 			registerClass(attribs.class)
 			s
					"<" + $0 + " "
					attribs->filtered()->mapped(composeAttrib)->joined(' ')   //(1)
					if emptyElements->contains($0) " />"
					else
						">" + content
						if close "</" + $0 + ">"
 			return s->joined()
  	}

In both versions, the logic at (1) turns the array of keys and values into a string that
will work as
attributes of an HTML tag, like so:

  	key1="val1" key2="val2" ...

The helper functions would be defined as follows. Note that the function passed in to
`mapped` will be called with two arguments: `key` and `val`.

  	func composeAttrib
 			return key + '="' + val + '"'

Note: this is an example of something cool: when we have to generate a string from pieces
and have logic that turns on or off pieces, the simple way to do it is to declare an array
in a block, and make use of flow control statements inside the block. Then at the end we
join the pieces of the array.

Composing can be chained: `firstArray -> secondArray -> myFunc` means both arrays will end
up being sent as `$obj` to the function `myFunc`.
Inside `myFunc`, `$obj` will be a composition of both arrays, not that `myFunc` will be
able to distinguish them. Really it means that when resolving names, `secondArray` will be
searched first and `firstArray` will be searched last. Name lookup to retrieve a value
will work its way down the chain. Name lookup for assignment will stop at the first level
of the hierarchy.

You can pre-compose and then pass that to a function later:

  	new_array = firstArray -> secondArray

  	new_array->doSomething()

Composition preserves references to objects, so `new_array` contains a reference to the
two originals, and and they are combined in a hierarchy, like a stack.

What do you get when you compose different things?

  	myArray -> anotherArray   // returns an array that combines both `myArray` and `anotherArray`.
  	// They won't be merged, they will be arranged more like a stack with `anotherArray`
  	// at the top and, thus, searched first.

  	anArray -> aFunction   // returns a function with `anArray` composed as its `$obj`

  	anArray -> map(mapFunc)   // this composes `anArray` with, and then calls, the `map` function

  	anArray->myFunc<myArgs>   // composes `anArray` with `myFunc` using arguments `myArgs`
  	// but does not execute the function

Arguments can be composed with a function, but the function not called, by using `<` and
`>` around the arguments. If the result is further composed with arguments, or the
function later called with arguments, the most recent arguments will "win" (because `$arg`
is not stacked up like `$obj`, there is only ever one `$arg` attached to a function so
multiple compositions will just combine `$arg`s).

If a non-array item is thrown into a composition, it will first be converted to an array,
using default integer keys.

### Comments

Two slashes create a comment to the end of the line.
I don't think we'll have multi-line comments like `/**/`.
Instead, the keyword `comment` will change the line where it appears *and all indented lines below*
into comments. This make it easy to comment out a block of code, you just prepend `comment`

	comment do
		...some stuff...

The `comment` comments out the `do` and all the code belonging to the `do` block.

(2018--07-20) Alternatively, a comment block could be introduced by ///.

I've used # as a comment character in some places when writing about wry. But  I
think # needs to be reserved for labeling scopes and loops, so it is out as a
comment character.

section : Values and references

	Arrays exhibit reference semantics, but standard operations will produce
	copies of things:

	```
		a = ( name='mike', age='42' )
		b = a

	The above will make a _copy_ of `a`, referred to as `b`. If you change either
	`a` or `b`, it won't affect the other.

	```
		a.name->print()   // prints 'mike'
		b.name->print()   // prints 'mike'
		a.name = 'tom'
		a.name->print()   // still prints 'mike'
		b.name->print()   // now prints 'tom'

	Actually in the run-time, `b` refers to `a`, but it is a read-only reference.
	Writing to either `a` or `b` will mask the original values. Here is how that
	works:

	Let `A` represent the array we created above, with keys 'name' and 'age'.
	Originally, variable `a` points to that array, so

	```(txt)
		a --> A

	when the runtime encounters the statement `b = a` it alters `a` by chaining
	with an empty array

	```(txt)
		a --> [] --> A

	and `b` similarly becomes

	```(txt)
		b --> [] --> A

	Both `b` and `a` point to `A`, but there is an empty array first in each
	chain. When looking up key `name`, the search will skip the empty array and
	find the value in `A` (which is how we achieve a read-only reference). When
	we write to either `b` or `a`, the assignment will happen at the bottom of
	the chain, in the empty array. Thus they share an original reference, but
	can't clobber each other with writes.

	How do we make a change that we know will affect the original `A`, even if
	shared by different references? We have to use chaining and tags.

	```(txt)
		b = a -> []

	or

	```(txt)
		b <- a

	!!!
		2018-04-26: Hmm... I don't like this. I think for reference semantics we
		should have a different operator, like &= that makes one object refer to
		another. Think about it.

	Now if we make a change to `a`, it will be visible from `b`.

	```
		a.name = 'tom'
		b.name->print()   // prints 'tom'

	Using our "pointer" diagrams, this is what happens when we execute `b <- a`:

	```
		a --> A
		b --> [] --> A

	In this case, `a` still points directly to `A` with no empty array sitting in
	between. So changes through `a` are visible in `b`, which was not the case
	above. However, those changes are one-sided. If we make a change to `b` it
	will not affect `a`. To achieve that we need to use tags:

	```
		b <- a#orig
		b@orig.name = 'tom'

		This is what the pointers look like:

	```
		a --> A
		b --> [] --> A#orig

	Now the badge on `b` jumps over the empty array and makes changes directly in
	`a`.

	This is how we would, for example, maintain a shared counter.

	```
		counter #base
			count = 0
			func incrementCounter
				$0 ?= 1
				@base.count += $0

		a <- counter
		b <- counter
		a->incrementCounter(1)
		b->incrementCounter(5)

	To make this work, we have to set an explicit tag on `counter`, and reference
	that tag within the `incrementCounter` method.

	As part of this, I think we need to be able to use references with tags and
	badges. Maybe with parens:

	```
		counter#(theBaseName)

		...   # inside the function
		@(theBaseName).count

	!!!
		Actually, I'm thinking it should be wrapped in colons, which hints back at
		the way of declaring arrays with evaluated keys.
		```
			my_array = ( <some expression> : <some value>)

		Here, because of the colon, `some expression` can be a variable or an
		expression or what have you, something you can't do if you use an equal
		sign.

		Similarly, we could evaluate an expression to determine the tag/badge by
		wrapping it in colons:

		```
			counter #:<some expression>:

			@:<some expression>:->count()

		It's maybe not as visible as the parens, but syntax highlighting could
		help with that.

	We should be able to put tags on items as they are declared, like we did
	above with `counter` and also when composing. Those tags should not clobber
	each other. So maybe each chain keeps track of what tags have been added
	(meaning if we tag an item like `counter` above it will be automatically
	converted into a chain with the tag) and then when composed later with other
	things, those chains will have slots for additional tags.

	Do we need to distinguish between chains formed by the runtime (for example,
	for copy-on-write and tagged objects as described above) and those formed
	explicitly by the user? Or does it matter?
