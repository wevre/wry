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

	private boolean pendingDent = true;   // Starting out `true` means we'll capture any whitespace at the beginning of the script.

	private int indentCount = 0;

	private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();

	private java.util.Stack<Integer> indentStack = new java.util.Stack<>();

	private Token initialIndentToken = null;

	private int getSavedIndent() { return indentStack.isEmpty() ? 0 : indentStack.peek(); }

	private CommonToken createToken(int type, String text, Token next) {
		CommonToken token = new CommonToken(type, text);
		if (null != initialIndentToken) {
			token.setStartIndex(initialIndentToken.getStartIndex());
			token.setLine(initialIndentToken.getLine());
			token.setCharPositionInLine(initialIndentToken.getCharPositionInLine());
			token.setStopIndex(next.getStartIndex()-1);
		}
		return token;
	}

	@Override
	public Token nextToken() {

		// Return tokens from the queue if it is not empty.
		if (!tokenQueue.isEmpty()) { return tokenQueue.poll(); }

		// Grab the next token and if nothing special is needed, simply return it.
		Token next = super.nextToken();
		//NOTE: This would be the appropriate spot to count whitespace or deal with NEWLINES, but it is already handled with custom actions down in the lexer rules.
		if (pendingDent && null == initialIndentToken && NEWLINE != next.getType()) { initialIndentToken = next; }
		if (null == next || HIDDEN == next.getChannel() || NEWLINE == next.getType()) { return next; }

		// Handle EOF; in particular, handle an abrupt EOF that comes without an immediately preceding NEWLINE.
		if (next.getType() == EOF) {
			indentCount = 0;
			// EOF outside of `pendingDent` state means we did not have a final NEWLINE before the end of file.
			if (!pendingDent) {
				initialIndentToken = next;
				tokenQueue.offer(createToken(NEWLINE, "NEWLINE", next));
			}
		}

		// Before exiting `pendingDent` state we need to queue up proper INDENTS and DEDENTS.
		while (indentCount != getSavedIndent()) {
			if (indentCount > getSavedIndent()) {
				indentStack.push(indentCount);
				tokenQueue.offer(createToken(WrenParser.INDENT, "INDENT" + indentCount, next));
			} else {
				indentStack.pop();
				tokenQueue.offer(createToken(WrenParser.DEDENT, "DEDENT"+getSavedIndent(), next));
			}
		}
		pendingDent = false;
		tokenQueue.offer(next);
		return tokenQueue.poll();
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

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; initialIndentToken = null; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;   //TODO: Swift includes \u000B, \u000C, and \u0000
