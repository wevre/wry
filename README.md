wren <*(~)
===========

A scripting language for web authoring.

Grammar
-----------

Some of this might contradict what is written below. This is an evolving document. Go with it.

### Lexical Structure

#### Name

#### Operator

	operator :: <some stuff>
	assignment-operator :: `=`
	conditional-operator :: `?` expression `:`
	compose-operator :: `->`

#### Literals

	literal :: numeric-literal | string-literal | boolean-literal | null-literal

	boolean-literal :: true | false

	null-literal :: nil

	numeric-literal :: integer-literal | floating-point-literal
	integer-literal :: <some stuff>
	floating-point-literal :: <some stuff>

	string-literal :: <some stuff>

#### Arrays and Functions

I had these up under literals before. If they are not there, they need to be included in somewhere so they count as an expression.

	array-entry :: expr | expr ':' expr | NAME '=' expr | TNAME | TTNAME
	array-list :: array-entry ( ',' array-entry )* ( ',' )?

	NAME :: [a-zA-Z_]([a-zA-z_0-9])*
	TNAME :: '~' NAME
	TTNAME :: '~~' NAME

	block-do :: 'do' ( LABEL )? ( statement-one-liner | INDENT statement-list ( DEDENT )? )
	block-do-if :: 'do' 'if' ( LABEL )? ( statement-one-liner | INDENT statement-list ( DEDENT )? )
	block-for :: 'for' expr ( LABEL )? ( statement-one-liner | INDENT statement-list ( DEDENT )? )
	block-if :: 'if' cond ( statement-one-liner | INDENT statement-list ( DEDENT )? )

	block-func :: 'func' ( statement-one-liner | INDENT statement-list ( DEDENT )? )


	function-literal :: code-block
	code-block :: `{` statement-list `}` // statement list will be defined below

### Expressions

	expression :: prefix-expression | prefix-expression binary-expressions
	expression :: `(` expression `)` // Is this recursion okay?? Let's find an example of a calculator that uses grouping parenthesis

#### Primary expression

	primary-expression :: name
	primary-expression :: literal-expression
	primary-expression :: scope-expression

	literal-expression :: literal | array-literal | function-literal

	scope-expression :: name `::` scope-name
	scope-expression :: name `:` expression `:`
	scope-name :: name // redundant for now, but maybe we want to add decimal-digits ??

#### Postfix expression

A postfix expression is formed by applying a postfix operator or other postfix syntax to an expression.

	postfix-expression :: primary-expression
	postfix-expression :: postfix-expression postfix-operator
	postfix-expression :: function-call-expression
	postfix-expression :: explicit-member-expression
	postfix-expression :: subscript-expression

	postfix-operator :: operator

	function-call-expression :: postfix-expression `(` array-literal `)` // There needs to be no white space before that opening parenthesis

	explicit-member-expression :: postfix-expression `.` member-name // This means you could have "hello".prop
	member-name :: name | decimal-digits

	subscript-expression :: postfix-expression `[` subscript-expression-list `]`
	subscript-expression-list :: expression | expression `,` subscript-expression-list

#### Binary Expression

	binary-expression :: binary-operator prefix-expression
	binary-expressions :: binary-expression | binary-expression binary-expressions

	prefix-expression :: postfix-expression | prefix-operator postfix-expression

### Statements

For now, assignment is sort of an operator that works, but allows a bunch of stuff through that we'll have to check for and emit errors (such as assigning to a string literal, for example). It might be better to make assignment a statement where we have some better control over what goes on the left-hand side (names, together with memberwise, scope, subscript access; and also lists of names).

Another thought: how will we declare constants? It needs to happen in two places: in assignments, such as:

	const CLASS-LABEL = 'lbl'

and also needs to be possible when we set properties on an object.

	myobject = ( const 'CLASS-LABEL' : 'lbl', const 'CLASS-INPUT' : 'inp' ) // or something like that

	statement :: expression
	statement :: loop-statement | branch-statement | labeled-statement | control-transfer-statement | defer-statement
	statement :: try-statement
	statement-list :: statement statement-list
	statement :: statement `;`

#### Loop Statement

	loop-statements :: for-in-statement | while-statement | repeat-statement

	for-in-statement :: `for` for-pattern `in` expression code-block
	for-pattern :: name | name, name

	while-statement :: `while` condition-clause code-block
	condition-clause :: expression

	repeat-statement :: `repeat` code-block `while` expression

#### Branch Statement

#### Labeled Statement

#### Control Transfer Statement

#### Defer Statement

Questions
-----------

Do we allow assignment to be an operator that returns a value? That is how it works in PHP, but in Swift it is forbidden (not by the grammar, by the way, but by something else downstream from the parser). But I find it useful to be able to capture a value at the same time as testing and then use that captured value:

	a = <some hairy expression>
	if a { // assuming we can test `a` even if it is not strictly a boolean value
		<do something with a>
	}

	if a = <some hairy expression> {
		<do something with a>
	}

Do we to allow any expression as condition-clauses? or only those that return boolean values? PHP has a broad set of things it will consider `false`, including empty strings, empty arrays, zero; whereas Lua only considers `false` and `nil` to be false and all those others are considered true. How do we handle a condion-clause that evaluates to an array? Do all the members of the array have to be true to continue?  (In PHP it only depends on whether or not the array is empty.)

Maybe we say: whatever expression is there in the condition clause will be cast (coerced) to a boolean, and there is a set of rules that control that. Maybe for an array, the first item of the array is used to determine the boolean. In PHP an array is true if it isn't empty.

As of 2017-03-01 my thoughts on this subject have landed on this: assignments are statements. The condition in an `if` test must be expressions, so assignment is not allowed there.


Types
-----------

There are (at least) seven types: `Integer`, `Float`, `Bool`, `String`, `Null`, `Array`, and `Function`. The `Array` type replaces what would be arrays, dictionaries, class instances, and parameter lists in other languages. It is an ordered map and behaves similarly to PHP's array type.

The simple types (`Integer`, `Float`, `Bool`, `String`, `Null`) will be familiar to users of other languages, and can be created with literals that are obvious.

	count = 7
	radius = 13.6
	isChecked = false
	employee = 'John Smith'
	flag = null

Those 5 simple types are scalars, whereas the `Array` type is a compound object.
[Maybe:]But an `Array` with a single object can be treated as a scalar when necessary.
[Maybe:]Likewise a scalar can be treated as a single-item array when necessary.


### Arrays

To create an array use parenthesis (or not, it is really the comma that denotes an array--the parenthesis are needed mostly as delimiters because of operator precedence).
An array can be a simple list of other types (no keys), in which case incrementing integer keys will automatically be applied.
Or it can be more like a dictionary with keys and values, separate by colons and commas.
Keys are of type `String` or `Int`, or expressions that evaluate to one of these.
Entries in the array can be retrieved by key.

	employee = ('first': 'mike', 'last': 'weaver', 'empl-id': 1234, 10.5)

This is similar to creating a dictionary in other languages, say JSON.
Note that we use parenthesis (not square or curly brackets), key-value pairs are delimited by a colon, and items are separated by a comma.

An `Array` of items without keys is declared in a similar way:

	cutoffs = (15.0, 25.0, 47.0)

The items in the array are accessed with a subscript operator that uses square brackets.
Inside the brackets use an expression that evaluates to either an `Int` or `String` that represents the key.

	cutoffs[0] // 15.0
	employee['first'] // 'mike'
	key = 'first'
	employee[key] // 'mike'

An alternate way to retrieve keyed items in the array uses a dot syntax. In this case, the key for the item must be a string that is also a valid name.

	employee.first // equivalent to employee['first']

[MAYBE:]
Multiple items can be accessed using multiple items in the subscript, separated by commas.
Expressions that resolve to other than String or Integer will emit a warning.

	cutoffs[0, 2] //  0 and 1
	employee['first', 'empl-id']

The two expressions above, instead of returning a single item from the original array, will each return an array with two items.
Integer indices in the returned array will be reset to 0, but string keys will be preserved from the original.
(... or, why not preserve integer indices? we can always have a method to "reset" array indices if that is desirable.)
[:MAYBE]

Alternate array declaration syntax:

Arrays keys can be declared in different ways. The following are equivalent:

	mydata = ('name': 'mike', 'age': 15)
	mydata = (name='mike', age=15)
	name = 'mike'
	age = 15
	mydata = (~name, ~age)
	mydata
		name='mike'
		age=15
	mydata
		'name': 'mike'
		'age': 15
	'mydata': ('name': 'mike', 'age': 15)

So when declaring keys, one can use a string, or an expression that evaluates to a string, followed by a colon.
Or one can use a bare name (no quotes) and an equals sign.
One can use parenthesis for an in-line declaration.
Or one can use multiple lines and indentation to layout the structure of the array.
A tilde preceding a bare name converts it as follows: `~name` is expanded to `'name': name`.
I was also thinking of an instance where, using indentation, if we need a non-named array we can use a bare comma:

	people
		,
			'name': 'mike'
			'age': 42
		,
			'name': 'fred'
			'age': 34

Of course the above could be achieved by declaring each node array on a single line with commas
This also begs the question of allowing records a la SAM.

A bare expression (something that is not part of an assignment statement) will act as an assignment into the local scope, using the next integer key.

### Local Scope

Whatever the current scope is, it's variables can be accessed via `$loc`, as follows:

	$loc['a']['name'] = 'Fred'
	print $loc.a['name']
	print $loc.a.name
	print $loc['a'].name

Outside of functions, the search to resolve a name will start with $loc, so usually it is not necessary to explicitly reference it.

This works:

	$loc['count'] = 100
	start = 0
	stop = count

Another way to affect the scope is the `with` statement. This is also a way to append to an array. All of these are equivalent. The `with` statement makes the array `a` the local scope and expressions and statements affect `a`.

	a.name = 'Fred'
	a['name'] = 'Fred'
	with a
		name = 'Fred'

Conceptually (although you can't really do this) the with statement does this:

	$save = $loc
	$loc = a
	<statements inside the with block>
	$loc = $save

### Loops

There are two loop statements, `do`, and `for`. `for` takes an array and iterates through the elements of the array, providing variables `$key` and `$val` to the statements inside the block at each iteration. (Question, does the `for` statement need an explicit `continue` at the bottom?)

The `do` statement begins a block of code that can be repeated with a `continue` statement somewhere inside the block. The `do` block can also be exited with a `break` statement. If the block is never "broken" out of, then a trailing `then` block will be exited. But if a `break` occurs, the `then` block will be skipped. (`break`, `continue`, and `then` also apply the same to a `for` block.)

	do
		<some stuff>
		if <expression> continue   // finish this iteration early and start at the top again
		<some stuff>
		if <expression> break   // stop iterating and jump past the `then` block
		continue
	then
		<some stuff>   // these will only be executed if there was no `break` above

Many loops will start with a test, similar to a standard `while` statement in C:

	do
		if !<while-condition> break
		...

To keep the syntax clean, a special form of the `do` statement allows for a test at the top of the loop:

	do if <while-condition>
		<some stuff>
	then
		<some stuff> // executed even if we fail the do-if expression, but not if there was a break.

It's very common to have a incrementing statement right before continue, such as:

	i = 0
	do if i < max
		<statements>
		i += 1
		continue

To clean that up a bit, both `continue` and `break` allow for a statement after, to capture change to the iterator variable, for example.

	i = 0
	do if i<max
		<some stuff>
		continue i += 1

This nicely keeps the logic controlling the loop close to the important do-if and continue statements.

Both `do` and `for` statements can be given a label, and `break` and `continue` can refer to that label in order to break out of nested loops.

	do #outer
		<some stuff>
		do #inner
			<some stuff>
			if <expression> break #outer
		<some stuff>
	then
		<stuff>   // won't be called if we broke out of the #outer loop

The label always comes at the end of the line, so do-if has its test expression first, then the label. And `continue` would have an optional incrementing statement first, then the label, if any.

If we do exceptions, then we will "throw" an array, and we can test the array, using $exc, to determine how we want to handle it in the `catch` clause, like so

	try
		<some stuff>
	then
		<stuff>   // if no exception thrown
	catch if $exc.name == 'error'
		<stuff>
	catch if $exc.name == 'blahblahblah'
		<stuff>
	catch
		<stuff>   // for all other exceptions

I don't think we'll need a `finally` statement, because we'll adopt the concept of `defer` from Swift.

### Object Serializing

Maybe we can borrow from the ideas behind dStruct and create a mechanism to save arrays in a database. There can be some initialization files or configuration files that grant the script access to a database, and then simple calls like this will make objects permanent from one run of the script to another:

	$dbs['person'] = ('name': 'Mike', 'age': 24)

	for $dbs['persons']
		<do something with all the persons returned from the database>

I'm thinking something similar ($fil) will be used to manage access to the file system.

### Functions

NOTE[2017-02-09] I want to change this to make the curly braces unnecessary.
They will be more like parenthesis for arrays: need for inline declarations, but
replaced with indentation for multi-line construction.
(And let's face it, most functions are multi-line.)

To create a function, use the keyword `func` to open a new block and then write statements, indented, on the lines below

	celsiusFromFahrenheit = func
		return ($0-32.0)*5.0/9.0

Calling the function is accomplished by appending parenthesis after a name. The parenthesis can be empty, or they can contain array entries that will be passed in as arguments and available inside the function in the array `$arg`.

You can also compose an array with a function call, and the array will be available inside the function as `$obj`. Inside the function, name resolution follows a search path through `$loc`, `$arg`, `$obj`, and finally `$out`. These arrays can be referenced explicitly or searching will happen implicitly in the given order.

When passing similar args from one function to another, the tilde syntax (`~name`) becomes very useful. And if an entire array needs to be passed, used double tilde syntax: `~~name`.

When an array, `b`, is composed with a function, the search to resolve the function name begins in `b` and then (if not found) search begins in the local scope. The result is that composing becomes a natural way to call functions that are defined inside an array. (It looks like member lookup.)

Suppose we have an array `p` in the local scope that has been set up as a Person object, with a first and last name, and a function `fullName`. Ignoring for the moment how we set up this object, we would call the `fullName` method like so:

	s = p->fullName()

Because of the compose operator, the process of resolving the name "fullName" will begin with `p`, where it will indeed find a function under the key "fullName". The function will be called with `p` passed in as `$obj`. If instead we did any of the following:

	p.fullName()
	p['fullName']()

the function would be found and called, but it would not have the `$obj` array as expected and would probably produce meaningless results. We can "hijack" the function, being able to make a good guess what it does, and do something strange like this:

	imposter = ( 'firstName': 'Mike', 'lastName': 'Smith' )
	imposter->p.fullName()

and would probably get the results we expected. Now the `fullName` function has an `$obj` array with the entries it expects to see.

As a corollary to this, if we have a function defined in the local scope, it _won't_ get called by the straightforward composition operator. We instead have to explicitly refer to it's scope, like so:

	p->$loc.fullName()

Some functions don't need named parameters, so a simple array object can be provided. Internally, the function refers to the arguments with an automatic variable `$args`.

	sum = func
		t = 0
		for $args t += $val
		return t

The `for` block operates on an array in a loop, and at each iteration provides variables `$key` and `$val` for the current entry.

	total = sum(1, 2, 3, 4) // returns 10

Often the variables we use to construct an array share the same name as the key we want to use in the array:

	values = ( 'name' : name, 'id' : id, )

For this case we have a shortcut syntax using the tilde (`~`):

	key = 'class'
	value = 'ampm'
	a = ( 'key' : key, 'value' : value)
	// or
	a = ( ~key, ~value)

A function can return a value, using the `return` statement.

	transform = func
		$obj.name ?= 'button'

The `?=` operator tests if a name is defined and, if not, assigns the value on the right.

[Question:] so we have to explicitly return $obj if we want to be able to chain functions together with the composer operator. And right now I'm thinking that $obj is passed by reference, so changes inside the function will alter it. Maybe we say: if the function does not return a value, then the (possibly) altered $obj becomes its return value for the purposes of further composing. If it does return a value, then that returned value will be composed with the next function in the chain. So a "procedure" or "subroutine" that doesn't return a value will preserve the original $obj in the calling chain. But something that returns a value will break that chain, supplying a different result (possibly a _copy_ of the original $obj) for later functions in the chain.

	some_array -> transformer() -> print()

The above passes the object to transformer, which inserts a 'name' key (if it doesn't exist already) and, by lacking a return statement, implicitly returns that new object which is passed along to the next function.

The idea here is that composing allows you to change the original array. Values passed in as arguments aren't intended to be changed (they can be, but the changes die when the function exits).

Closures. I think we can achieve something similar to closures by composing an object with a function, but not calling the function. The resulting value will be--what should we call it, a `Composition`?--something that can be executed but already has it's `$obj` bundled with it. Really it's a function with some extra data tagging along with it. You can even compose something with it when you call it, but the earlier composition will be first in the scope resolution hierarchy. (So what gets returned in that situation? What original object is changed? if the function changes something in the bundled $obj, then will that change live on after the call? meaning it would affect subsequent calls. I think that is what would naturally happen.)


If the function is a member of an array, then other properties of that array should be available to the function by default. (They will be, under composition, because they will be found in $obj, as long as they are not hidden by something in $loc or $arg, which are checked first.)

So here is how this function from PHP would look in wren:

	// in PHP
	function addButtons($butts) {
		$this->composer->beginElement('p');
		foreach ($butts as $items) {
			if (!$items['type']) { $items['type'] = 'submit'; }
			if (!$items['name']) { $items['name'] = self::KEY_ACTION; }
			if (!$items['id']) { $items['id'] = $items['name'] . '-' . $items['value']; }
			$this->composer->addElement('button', $items['class'], array_merge(array_intersect_key($items, array_flip('type', 'name', 'id', 'value')), $items['xattr']), $items['content']);
		}
		$this->composer->endElement();
	}

	// in wren
	addButtons = func   // pass in an array of button objects
		composer.beginElement('p')
		for $args
			$val.type ?= 'submit'
			$val.name ?= constants.keyAction
			$val.id ?= $val.name + '-' + $val.action
			attribs = $val['type', 'name', 'id', 'value'] + $val.xattr
			composer.addElement('button', class=$val.class, attribs=attribs, $val.content)
		composer.endElement()


We would call this function like so:

	buttons
		value='submit', content='Submit'
		value='cancel', content='Content'

	fb->addButtons(buttons)

Let's look at the function that the one above relies on, it is getElement in the composer object:

	// in PHP
	protected static function getElement($elem, $class='', $attribs=[], $content='', $close=false) {
		$filtered = array_filter($attribs, function ($v) { return !empty($v); } );
		$attribString = implode(' ', array_map(function($k, $v) { return "$k=\"$v\""; }, array_keys($filtered), $filtered));
		$empty = self::isEmptyElement($elem);
		return '<' . $elem . wrapIfCe($class, ' class="', '"') . prefixIfCe($attribString, ' ') . ( $empty ? '' : '>' . $content ) . ( $close ? ( $empty ? ' />' : "</$elem>" ) : '' );
	}

	// in wren
	getElement = func   //(elem, class?, attribs?, content?, close?=false)
		attribs.class = $class
		attribString = attribs->filter(notEmpty)->map(composeAttrib)->implode(' ')
		empty = emptyElements->contains($0)
		s = "<\($0) " + attribString
		if empty s += ' />'
		else
			s += ">\(content)"
			if close s += "</\(elem)>
		return s
	}

So this syntax says that in-line functions can be defined without the `func` keyword using curly braces instead. For this to work, `filter` can't change its $obj. That would be disaster. Maybe it needs to be called `filtered` so it is clear it returns a new array, instead of altering the original

One odd thing about the above getElement function: what if `class` is present in the attrib array? Shouldn't that be merged?

Composing can be chained: firstArray -> secondArray -> myFunc means both arrays will end up being sent as args to the functin `myFunc`. No, they will not be sent as separate args. Inside `myFunc`, $obj will be a composition of both arrays, not that myFunc will be able to distinguish them. Really it means that when resolving names, secondArray will be searched first and firstArray will be searched last. Any changes will "stick" in whatever object the resolved name was found.

You can pre-compose and then pass that to a function later:

	new_array = firstArray -> secondArray

	new_array->doSomething()

The array `new_array` is now a copy that composes both first and second.

What do you get when you compose different things?

	myArray -> anotherArray // This returns an array that contains elements from both `myArray` and `anotherArray`. For any keys that are the same, they are organized into an inheritance relationship

	anArray -> aFunction // this calls the function with `anArray` as the $args implicit

	anArray -> map(mapFunc) // anArray -> (mapFunc) -> map  // So how does map refer it its inputs? first `anArray` is composed with `(mapFunc)` so mapFunc is scoped behind anArray? then map sees that as $args?

	maybe it is implicit with numbers: anArray -> map(mapFunc) ==> anArray -> (mapFunc) -> map ==> anArray<1> -> (mapFunc)<0> -> map

	then the map is implemented this way:

	map = {
		for item in $args<1> { item -> $args[0] }
	}

	and maybe $0 is shortcut for $args[0] and of course $args implies $args<0> (or should it imply $args<n> with n being the highest scope number?)

	so maybe

	map = {
		func = $0<0>
		for i in $args.range { $args[i] = args[i] -> f }
	}

	anArray<this> -> aFunction

	anArray<this> -> othArray<args> -> aFunction

	is the same as anArray.aFunction(othArray)

What about these?

	scalar -> scalar  <-- result is an array? or is the result a scalar with two levels of scope?

	scalar -> array  <-- returns the array with one of its members (the first one?) having two levels of scope

	scalar -> function  <-- scalar is passed to function as its only argument

	array -> scalar  <-- an array with its first member backed up by the scalar?

	array -> array  <-- first array becomes "topmost" over any equivalent keys in second array

	array -> function  <-- array is passed in to function as its arguments

	function -> scalar  <-- scalar has two levels of scope, function is in front

	function -> array  <-- array's first member has function in front-most scope

	function -> function  <-- first function is passed to second as an argument

	(function)->function <-- this is a better way to write the first, because it is clear that we are not evaluating the first func

	array -> func -> func  <-- array is passed as args to first func, the result is passed to second func

	array -> (func) -> func  <-- array is composed with first func, result is passed as args to second func



