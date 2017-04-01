wren `<*(~)`
===========

A scripting language for web authoring.

Grammar
-----------

Some of this might contradict what is written below. This is an evolving document. Go with it.

###Lexical Structure

####Name

	name :: name-head | name-head name-characters
	name :: ` name-head ` |  ` name-head name-characters `
	name-head :: _ | a-z | A-Z
	name-character :: name-head
	name-character :: decimal-digit
	name-character :: <bunch of unicode stuff>
	name-characters :: name-character
	name-characters :: name-character name-characters

	decimal-digit :: 0-9
	decimal-digits :: decimal-digit decimal-digits

####Operator

	operator :: <some stuff>
	assignment-operator :: `=`
	conditional-operator :: `?` expression `:`
	compose-operator :: `->`
	
####Literal

	literal :: numeric-literal | string-literal | boolean-literal | null-literal

	boolean-literal :: true | false

	null-literal :: nil

	numeric-literal :: integer-literal | floating-point-literal
	integer-literal :: <some stuff>
	floating-point-literal :: <some stuff>

	string-literal :: <some stuff>

####Arrays and Functions

I had these up under literals before. If they are not there, they need to be included in somewhere so they count as an expression.

	array-literal :: array-field-list
	array-field-list :: array-field
	array-field-list :: array-field array-separator // This makes optional the trailing separator
	array-field-list :: array-field array-separator array-field-list
	array-separator :: `,`
	array-field :: expression `:` expression // here the left-side expression will be coerced to a string to become the key
	array-field :: expression
	array-field :: `~` name // would we want the scope operator to work here??
	
	function-literal :: code-block 
	code-block :: `{` statement-list `}` // statement list will be defined below

###Expressions

	expression :: prefix-expression | prefix-expression binary-expressions
	expression :: `(` expression `)` // Is this recursion okay?? Let's find an example of a calculator that uses grouping parenthesis

####Primary expression

	primary-expression :: name
	primary-expression :: literal-expression
	primary-expression :: scope-expression
	
	literal-expression :: literal | array-literal | function-literal
	
	scope-expression :: name `::` scope-name
	scope-expression :: name `:` expression `:`
	scope-name :: name // redundant for now, but maybe we want to add decimal-digits ??

####Postfix expression

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
	
####Binary Expression
	
	binary-expression :: binary-operator prefix-expression
	binary-expressions :: binary-expression | binary-expression binary-expressions
	
	prefix-expression :: postfix-expression | prefix-operator postfix-expression

###Statements

For now, assignment is sort of an operator that works, but allows a bunch of stuff through that we'll have to check for and emit errors (such as assigning to a string literal, for example). It might be better to make assignment a statement where we have some better control over what goes on the left-hand side (names, together with memberwise, scope, subscript access; and also lists of names).

Another thought: how will we declare constants? It needs to happen in two places: in assignments, such as:

	const CLASS_LABEL = 'lbl'
	
and also needs to be possible when we set properties on an object.

	myobject = ( const 'CLASS_LABEL' : 'lbl', const 'CLASS_INPUT' : 'inp' ) // or something like that

	statement :: expression
	statement :: loop-statement | branch-statement | labeled-statement | control-transfer-statement | defer-statement
	statement :: try-statement
	statement-list :: statement statement-list
	statement :: statement `;`

####Loop Statement

	loop-statements :: for-in-statement | while-statement | repeat-statement

	for-in-statement :: `for` for-pattern `in` expression code-block
	for-pattern :: name | name, name 

	while-statement :: `while` condition-clause code-block
	condition-clause :: expression

	repeat-statement :: `repeat` code-block `while` expression

####Branch Statement

####Labeled Statement

####Control Transfer Statement

####Defer Statement

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
	
Do we to allow any expression as condition-clauses? or only those that return boolean values? PHP has a broad set of things it will consider `false`, including empty strings, empty arrays, zero; whereas Lua only considers `false` and `nil` to be false and all those others are considered true. How do we handle a condion-clause that evaluates to an array? Do all the members of the array have to be true to continue?

Maybe we say: whatever expression is there in the condiction clause will be cast (coerced) to a boolean, and there is a set of rules that control that. Maybe for an array, the first item of the array is used to determine the boolean.

Types
-----------

There are seven types: `Integer`, `Float`, `Bool`, `String`, `Null`, `Array`, and `Functions`. The `Array` type replaces what would be arrays, dictionaries, class instances, and parameter lists in other languages. It is an ordered map and behaves similarly to php's array type. The `Function` type is replacement for functions, methods, closures, and anonymous functions in other languages.

The simple types (`Integer`, `Float`, `Bool`, `String`, `Null`) will be familiar to users of other languages, and can be created with literals that are obvious.

	count = 7
	radius = 13.6
	isChecked = false
	employee = 'John Smith'
	flag = null

Those 5 simple types, together with the `Function` type, are scalars, whereas the `Array` type is a compound object.

### Arrays

To create an array use parenthesis (or not, it is really the comma that denotes an array -- the parenthesis are needed mostly as delimiters because of operator precedence). An array can be a simple list of other types, with an automatic index that starts at 0. Or it can be more like a dictionary with keys and values, separate by colons and commas. Keys in this case would be `String` types. An array can also be a mix of the two. Key expressions that don't resolve to strings will emit a warning. Entries with keys can be accessed by their key or by their position within the array. Positions are zero-based.

	employee = ( 'first' : 'mike', 'last' : 'weaver', 'empl-id' : 1234, 10.5 )
	
	employee[0] == employee['first'] == 'mike'
	employee[3] == 10.5
	
This is similar to creating a dictionary in other languages, say JSON. Note that we use parenthesis (not square or curly brackets), key-value pairs are delimited by a colon, and items are separated by a comma.

An `Array` of items without keys is declared in a similar way:

	cutoffs = ( 15.0 , 25.0 , 47.0 )

The items in the array are accessed with a subscript operator that uses square brackets. Inside the brackets use an integer index (or an expression that resolves to an `Integer` type) to access an item based on it's location. Use a string (or, again, an expression that resolves to a `String` type) to access an item by key. Expressions that resolve to other than `String` or `Integer` will emit a warning.

	cutoffs[0]
	employee['first']

An alternate way to retrieve keyed items in the array uses a dot syntax.

	employee.first // equivalent to employee['first']

Multiple items can be accessed using multiple items in the subscript, separated by commas. Integer indices will access entries based on position. String indices will access based on key lookup. Expressions that resolve to other than String or Integer will emit a warning.

	cutoffs[0, 2] // the results here will not have keys associated with them, just the indices 0 and 1
	employee['first', 'empl-id']

The two expressions above, instead of returning a single item from the original array, will each return an array with two items. Integer indices in the returned array will be rest to 0, but string keys will be preserved from the original.

TODO: need a syntax for ranges, maybe something like Swift's ... and ..< operators.

But that functionality is really not needed, because what you put inside backticks works just as well inside square brackets.

### Functions

A function is declared with curly braces:

	simple_add = { print(2 + num) }

This function uses a variable `num` that hasn't been defined or declared. It will be provided when the function is called, like so:

	simple_add('num': 7)

Calling the function is accomplished by appending an array to the name of the function and supplying keys and values for the function's internal variables. This is syntactic sugar for the realy way to call functions, by composing them with an array as described below.

If you are constructing an object on the fly to serve as the arguments, you can use the syntax above, which reads more like a traditional function call. But it is shortcut for this operator `->` which composes an array with a function. The `->` operator is needed when you are not declaring literals, but are composing `Array` expressions and `Function` expressions (which could be, for example, variables):

	simple_add('num': 7)
	('num': 10) ->  simple_add
	args = ('num': 8)
	args -> simple_add
	args -> { return num + 6 }

The operator wants the argument array first so that function calls can be chained. Here are some more examples before we get to chaining.

	foo = ( 5, 7 ) -> { return _[0] + _[1] }
	//or
	args = ( 5, 7)
	adder = { return _[0] + _[1] }
	bar = args -> adder

TODO: probably also want some magic variables for indices, like `$0` and `$1`. I'm also thinking `$_` will be the array of the arguments, and `$this` will be the array object that the function is a member of, if indeed the function is a member. Otherwise that would just be nil.

Some functions don't need named parameters, so a simple array object can be provided. Internally, the function refers to the arguments with an automatic variable `$_` (that's an underscore).

	sum_all = {
		tally = 0
		for i in $_ {
			tally += i
		}
		return tally
	}

	sum_all(1, 2, 3, 4) // returns 10
	// or
	sum = {
		head, tail = $_
		if tail is null { return head }
		else { return head + tail -> sum }
	}
	// or
	sum = {
		head, tail = $_
		if head is null { return 0 }
		else { return ( head is Numeric ? head : 0 ) + tail -> sum ) }
	}

Often the variables we use to construct an array share the same name as the key we want to use in the array:

	values = ( 'name' : name, 'id' : id, )

For this case we have a shortcut syntax using the tilde (`~`):

	key = 'class'
	value = 'ampm'
	a = ( 'key' : key, 'value' : value)
	// or
	a = ( ~key, ~value)

A function can explicitly return a value, using the return statement. Or it can implicitly return the (possibly modified) parameter array it was given. Inside the function, the parameter array can be explicitly referred to (and modified) with $_ (that's an underscore).

	transformer = {
		if name is null { $_.name = 'button' }
	}

	( 'id' : 'my-button', 'type' : 'input' ) -> transformer -> print_all

The above passes the object to transformer, which inserts a 'name' key (if it doesn't exist already) and explicitly returns that new object which is passed along to the next function.

	transformer_redux = {
		a = 'button'
		if name is null { $_.name = a }
	}

In this version, the internal variable 'a' does not become part of the implicit argument object. It takes the underscore `$_` to access it and to make changes to it. It would be equivalent to end the above function with

	return $_

That is implicitly done if there is no return statement.

All the members of the parameter are implicitly splatted to be local variables within the function. Sort of similar to Python's unpacking of argument lists. But different. Python unpacks so that members of the single tuple will spread out and be assigned to the declared parameter, in the same order. With wren we unpack so that the keys of the parameter array will be accessible as local variables inside the function.

What about closures? When a variable is referenced inside a function, how do know the difference between a local variable being created? versus an external variable we want to capture?

	// in this case it seems clear you want to capture the external variable `a`
	a = 'hello'
	greeter = {
		print(a + ' there my friend')
	}
	// But here no capture is desired. We are masking the outer variable `b` with our own internal one.
	b = 'bye'
	fareweller = {
		b = 'safe travels'
		print(“friend, “ + b)
	}

It seems to make this work, our interpreter will have to examine the names referred to inside the function, and close around any variable that are referenced that exist in the same scope as where the function is defined.  Of course maybe the programmer intends those variables to be supplied as arguments when the function is called. That's okay, the argument value will become the default value, not the closure value.

If the function is a member of an array, then other properties of that array should be available to the function by default.

So here is how this function from PHP would look in wren:

	// in PHP	
	function addButtons($butts) {
		$this->composer->beginElement('p');
		foreach ($butts as $items) {
			if (!$items['type']) { $items['type'] = 'submit'; }
			if (!$items['name']) { $items['name'] = self::KEY_ACTION; }
			if (!$items['id']) { $items['id'] = $items['name'] . '-' . $items['value']; }
			$this->composer->addElement('button', $items['class'], array_merge(array_intersect_key($items, array_flip('type', 'name', 'id', 'value')), $items['xattr']), $items['display']);
		}
		$this->composer->endElement();
	}

	// in wren
	addButtons : {
		composer.beginElement('name' : 'p')
		for item in _ { // what's implied here is ( 'item' : item) -> {
			type not null or type = 'submit'
			name not null or name = KEY_ACTION::self
			id not null or id = name + '-' + action
			composer.addElement('elem' : 'button', \class, 'attribs' : ( \type, \value, \id, \name ) + xattr, \contents)
		}
		composer.endElement()
	}

Let's look at the function that the one above relies on, it is getElement in the composer object:

	// in PHP
	protected static function getElement($elem, $class='', $attribs=[], $content='', $close=false) {
		$filtered = array_filter($attribs, function ($v) { return !empty($v); } );
		$attribString = implode(' ', array_map(function($k, $v) { return "$k=\"$v\""; }, array_keys($filtered), $filtered));
		$empty = self::isEmptyElement($elem);
		return '<' . $elem . wrapIfCe($class, ' class="', '"') . prefixIfCe($attribString, ' ') . ( $empty ? '' : '>' . $content ) . ( $close ? ( $empty ? ' />' : "</$elem>" ) : '' );
	}

	// in wren
	getElement : {
		attribString = attribs.filter({ return value not null }).map({ return "\(key)=\(value)" }).implode(' ')
		empty = isEmptyElement(elem)
		return "<\(elem) class=\"\(class)\" " + attribString + ( empty ? '' : ">\(content)" ) + ( close as bool ? (empty ? ' />' : "</\(elem)>" ) : '' )
	}

This `->` operator is important. It is how we compose argument arrays and functions, and also how we create subclasses.

	shape = {
		'name' : ''
		'area' : { return 0.0 }
		'description' : {
			print(“shape “ + name + “ area=“ + area())
		}
	)

	circle = shape( // This creates a copy of shape, with additional entries in the object.
		'radius' : 1.0
		'area' : { return radius * radius * 3.14 }
	)
	//that is equivalent to
	circle = (…) -> shape // but it reads better the first way, because it looks like a constructor in other languages

In the above code, an object is created and stored in the variable `shape`. Then a new object is created as a copy, called `circle` with a new property `radius` and a new function `area`. When we call description on circle we will get the correct printout.

Talk about subscripts, which is a way to get to the ::self and ::super versions of a variable. There might also need to be a ::call or ::outer.  Or ::builtin. If a function is defined as a member of an array, it should have acceess to the properties of the array when it is called, without needing extra syntax. Does that stay in sync with how access to other variables work? Need to think about how scope rules work.

