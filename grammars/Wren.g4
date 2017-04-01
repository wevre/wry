/*
*	wren.g4
*
*	An ANTLR4 grammar for wren.
*
*	Author: Mike Weaver
*	Created: 2017-03-15
*
*/


//	Here is what we don't handle yet:
//		compose function might need its own rule, or anyway we want to be able to have this construct:
//			expr '->' block
//		and this one
//			name = expr '->' block
//		which I was thinking could be "sugared" to look like this:
//			name '<-' reference block
//		maybe a block of statements/expressions can be allowed in the middle of an expression sequence
//		to build an "array on the fly". <-- I think that will make for some very messy code. Instead, let's isolate where
//		we want to allow this and create explicit rules for it.

//	Another thought I had: we can compose an object with a function, without calling the function, and save that.
//	Doing so creates a sort of "bundle" with the function and a built-in $obj. But what about allowing the same thing
//	with a pre-composed, or bundled, $arg? So maybe we allow this:
//		saved = my_obj -> my_func ~ my_arg
//	Then that can be saved and called later. It can also be composed later, so we might see something like this:
//		oth_obj -> saved( oth_args... )
//	And in this case, the $obj will be equivalent to `oth_obj -> my_obj` and the $arg will be equivalent to `my_arg -> oth_arg`.
//	The thing to note here is that the object provided at the call will be composed "behind" the original (searched last),
//	but the args will be composed "in front" of the original (searched first).
//	Whether we allow it or not, then, conceptually we have this:
//		obj1 -> obj2 -> myfunc ~ arg1 ~ arg2
//	with scope searches resolved from the inside out.


//	Another thing I want to provide for is composing and defining at the same time. This allows for a form of inheritance.
//	So instead of this:
//		base_obj = ...
//		a = base_obj -> ()   // or however we designate an empty array? maybe with a comma?
//		with a
//			...
//	All of the above can be accomplished with:
//		a <- base_obj
//			...

//	Another clarifying thought: when we badge an object participating in a composition, we need different operators for (a) declaring the
//	badge, and (b) accessing the badge. Perhaps something like this:
//		base_obj#base -> oth_obj#child -> some_func()
//	And then inside the func we can access a member of base_obj or oth_obj with:
//		parent_func@base()
//	At first I thought I could use `#` for both, but confusion would arise if, during composition, you are intending to declare a badge,
//	or maybe you are trying to access an already declared badge instead. For that reason, the operators need to be different.

//	Also need to sort out how strong and weak references will work. They only make sense in assignments
//	(so a new name is pointing at a reference to an existing name) or maybe return statements from functions.
//	This includes assignments that are happening inside an array construction. Let's go see how PHP handles this.

//	Also I was thinking I would allow alternate operators for things like × and ÷ and ≤ and ≥ and ∧ and ∨ and ∩ and ∪

grammar Wren;

tokens { INDENT, DEDENT }

@lexer::members {

	// A queue onto which we push extra tokens. The implementation of `nextToken` is overridden to empty the `tokens` queue first.
	private java.util.LinkedList<Token> tokens = new java.util.LinkedList<>();

	// The stack that keeps track of the indentation level.
	private java.util.Stack<Integer> indents = new java.util.Stack<>();

	// The most recently produced token. We set it inside `nextToken`.
	private Token lastToken = null;

	// I think this method intercepts the normal emit and stashes the token in our `tokens` queue.
	@Override
	public void emit(Token t) {   //TODO: how does `emit` relate to `nextToken`?
		System.out.println("emit called with token `" + t + "`");
		super.setToken(t);   //TODO: what does this do?, and if we haven't overridden, do we need `super`?
		tokens.offer(t);
		System.out.println("the tokens queue now has " + tokens.size() + " members.");
	}

	// When we reach EOF, spit out any pending DEDENTs.
	private void clearOutDedents() {
		// Remove any trailing EOF tokens from our buffer.
		for (int i = tokens.size() - 1; i >= 0; i--) {
			if (tokens.get(i).getType() == EOF) { tokens.remove(i); }
		}

		// First emit an extra line break that serves as the end of the statement.   //TODO: is this needed? Need to think of an example...
		emit(commonToken(WrenParser.NEWLINE, "\n"));

		// Now emit as many DEDENT tokens as needed.
		while (!indents.isEmpty()) {
			emit(createDedent());
			indents.pop();
		}

		// Put the EOF back on the token stream.
		emit(commonToken(WrenParser.EOF, "<EOF>"));
	}

	// My understanding of Lexer.nextToken() is it
	@Override
	public Token nextToken() {

		// Check if the end-of-file is ahead and there are still some DEDENTS expected.
		if (_input.LA(1) == EOF && !indents.isEmpty()) {
			clearOutDedents();
		}

		System.out.println("calling super.nextToken");
		Token next = super.nextToken();   //TODO: how is it that this value is not lost when we pull from the `tokens` queue instead?
		System.out.println("result of super.nextToken is `" + next + "`");

		if (next.getChannel() == Token.DEFAULT_CHANNEL) {
			// Keep track of the last token on the default channel.
			lastToken = next;
		}

		if (tokens.isEmpty()) {
			System.out.println("nextToken: returning `next`");
			return next;
		} else {
			System.out.println("nextToken: returning `tokens.poll()`");
			return tokens.poll();
		}
		//return tokens.isEmpty() ? next : tokens.poll();
	}

	// Creates a DEDENT token and sets the line number using the last token
	private Token createDedent() {
		CommonToken dedent = commonToken(WrenParser.DEDENT, "");
		dedent.setLine(lastToken.getLine());
		return dedent;
	}

	private CommonToken commonToken(int type, String text) {
		return new CommonToken(type, text);
	}

	// Not sure how to describe what this does, think it just wraps some repetitive logic into a single function call.
	// Actually it sets the stop and start character indices.
	private CommonToken old_commonToken(int type, String text) {
		int stop = getCharIndex() - 1;
		int start = text.isEmpty() ? stop : stop - text.length() + 1;
		return new CommonToken(_tokenFactorySourcePair, type, DEFAULT_TOKEN_CHANNEL, start, stop);
	}

	// Counts the characters in the string, which should only be either spaces or tabs.
	static int getIndentationCount(String spaces) {
		return spaces.length();
	}

	boolean atStartOfInput() {
		return getCharPositionInLine() == 0 && getLine() == 1;
	}
}

script
	:	( NEWLINE | statement )* EOF
	;

/*
*	statement
*/

statement
	:	inlineStatementList NEWLINE
	|	compoundStatement
	;

inlineStatementList
	:	smallStatement ( ';' smallStatement )*	';'? ;

/*
*	smallStatement
*/

smallStatement
	:	assignStatement
	|	flowStatement
	|	expr
	;

assignStatement
	:	nameRef EQOP expr   //TODO: we want to be able to put an array on the left side, or a nameReference with . and []
	;

flowStatement
	:	'break' inlineStatementList? Label?
	|	'continue' inlineStatementList? Label?
	|	'return' expr
	|	'throw' expr
//	|	'assert' expr
//	|	'yield' expr
	;

/*
*	compound statement
*/

compoundStatement
	:	ifStatement
	|	doStatement
	|	forStatement
	|	tryStatement
	|	withStatement
	|	assignBlock
	;

ifStatement
	:	'if' expr doableBlock ( 'else' 'if' expr doableBlock )* ( 'else' doableBlock )?
	;

doStatement
	:	'do' ( Label )? block ( 'then' block )?
	|	'do' 'if' expr ( Label )? block ( 'then' block )?
	;

forStatement
	:	'for' expr ( Label )? block ( 'then' block )?
	|	'for' expr 'if' expr ( Label )? block ( 'then' block )?
	;

tryStatement
	:	'try' doableBlock ( 'catch' 'if' expr doableBlock )*	( 'catch' doableBlock )?
	;

withStatement
	:	'with' nameRef block
	;

assignBlock
	:	nameRef blockStatements
	|	expr ':' blockStatements
	;

block
	:	inlineStatementList NEWLINE
	|	blockStatements
	;

blockStatements
	:	NEWLINE INDENT statement+ DEDENT
	;

doableBlock
	:	block
	|	doStatement
	|	forStatement
	;

expr
	:	nameExpression
	|	literal
	|	functionExpression
	|	expr ( ',' expr )+ ','?
	|	'(' expr ')'
	|	expr OP expr
	|	expr '(' expr ')'
	|	expr '->' expr
	|	PlainName '=' expr
	|	expr ':' expr
	|	TildeName
	|	DubTildeName
//	|	logicalExpression
	;
TildeName : '~' Name ;
DubTildeName : '~~' Name ;

functionExpression
	:	'{' inlineStatementList '}'
	;

// funcBlock
// 	:	inlineStatementList
// 	|	blockStatements
// 	;

/*
*	names
*/

nameRef
	:	Name trailer*
	;

trailer
	:	'[' expr ']'
	|	'.' PlainName
	;

nameExpression
	:	nameRef
	|	'&' nameRef
	|	'&&' nameRef
	;

Name
	:	PlainName
	|	SpecialName
	;

PlainName : NameHead NameChar*	;
fragment NameHead : [_a-zA-Z] ;
fragment NameChar : [0-9] | NameHead ;

SpecialName : '$' PlainName ;

Label : '#' NameChar+ ;

/*
*	What does it mean to type `&a.fred` as opposed to `a.&fred`? I don't think we want to put the & in the middle of the dot operator. So it seems more natural to come first.
*	So does that make it a token? Or is it an operator?
*	It can't be just in front of a name, it needs to be in front of a reference.
*	Will this ever be used other than in assignment? YES: it could be in a return statement or in an array assignment used as an argument to a function.
*	So it seems like it is part of object reference, not really an operator
*/

/*
*	literals
*/

literal
	:	numericLiteral
	|	StringLiteral
	|	booleanLiteral
	|	nullLiteral
	;

booleanLiteral : 'true' | 'false' ;

nullLiteral : 'null' ;

numericLiteral
	:	integerLiteral
	|	FloatingPointLiteral
	;

fragment SIGN : [+\-] ;

/*
*	integer literal
*/

integerLiteral
	:	BinaryLiteral
	|	OctalLiteral
	|	DecimalLiteral
	|	DozenalLiteral
	|	HexadecimalLiteral
	;

BinaryLiteral : SIGN? '0b' BinDigit ( BinDigit | '_' )*	;
fragment BinDigit : [01] ;

OctalLiteral : SIGN? '0o' OctDigit ( OctDigit | '_' )*	;
fragment OctDigit : [0-7] ;

DecimalLiteral : SIGN? DecDigit ( DecDigit | '_' )*	;
fragment DecDigit : [0-9] ;

DozenalLiteral : SIGN? '0d' DozDigit ( DozDigit | '_' )*	;
fragment DozDigit : [0-9xeXE] ;

HexadecimalLiteral : SIGN? '0x' HexDigit HexChars? ;
fragment HexDigit : [0-9a-fA-F] ;
fragment HexChars : ( HexDigit | '_' )+ ;

/*
*	floating point literal
*/

FloatingPointLiteral
	:	SIGN? DecimalLiteral ( '.' DecimalLiteral )? DecimalExponent?
	|	SIGN? HexadecimalLiteral ( '.' HexDigit HexChars? )? HexadecimalExponent?
	;
fragment DecimalExponent : [eE] SIGN? DecimalLiteral ;
fragment HexadecimalExponent : [pP] SIGN? DecimalLiteral ;

/*
*	string literal
*/

StringLiteral
	:	'"' ( StringEscapeChar | ~[\r\n\\"] )*? '"'
	|	'\'' ( StringEscapeChar | ~[\r\n\\'] )*? '\''
	;
fragment
StringEscapeChar
	:	'\\' [0\\tnr"']
	|	'\\x' HexDigit HexDigit
	|	'\\u' '{' HexDigit HexDigit HexDigit HexDigit '}'
	|	'\\u' '{' HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit '}'
	;

/*
*	comments and whitespace
*/

Block_comment : '/*' ( Block_comment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
Line_comment : '//' ~[\r\n] -> channel(HIDDEN) ;

NEWLINE
	:	( {atStartOfInput()}? SPACES | EOL SPACES? )
		{
			String newline = getText().replaceAll("[^\r\n]+", "");
			String spaces = getText().replaceAll("[\r\n]+", "");
			int next = _input.LA(1);

			// skip a blank line
			if (next == 'r' || next == '\n') { skip(); return; } //TODO: should also skip if comment is next token on the line

			//TODO: we could test here if next == '/' and _input.LA(2) == '*' which means we are starting a comment
			//TODO: similarly, we could test if next is '/' and LA(2) is also '/' and skip.

			emit(commonToken(NEWLINE, newline));

			int indent = getIndentationCount(spaces);
			int previous = indents.isEmpty() ? 0 : indents.peek();

			if (indent == previous) {
				skip();
			} else if (indent > previous) {
				indents.push(indent);
				emit(commonToken(WrenParser.INDENT, spaces));
			} else {
				while (!indents.isEmpty() && indents.peek() > indent) {
					emit(createDedent());
					indents.pop();
				}
			}
		}
	;

fragment
EOL : '\r'? '\n' | '\r' ;
fragment
SPACES : [ \t]+ ;

//WS : [ \t\r\n]+ -> channel(HIDDEN) ;   //TODO: Swift includes \u000B, \u000C, and \u0000
WS : [ \t]+ -> channel(HIDDEN) ;   //TODO: Swift includes \u000B, \u000C, and \u0000
