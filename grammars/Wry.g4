/*
* Wry.g4
*
* ANTLR4 grammar for wry.
*
* Author: Mike Weaver
* Created: 2017-03-15
*
*/

//   Ideas not yet working in the grammar (or not yet tested).

//   1. "Inheritance"
//
//   I want to provide for composing and defining at the same time, which
//   is what we need to mimic inheritance. So we want to do something like this:
//        a = base_obj -> ()
//        with a
//             ...
//   If we want to compose with a copy of the base object (so that we can't alter it via
//   the composition) then we can use the `~~` expansion operator, which creates a copy
//   of the object, instead of a reference (which is the normal result of composition).
//   The `with` statement allows us to declare stuff inside the newly composed
//   object.
//   All of the above can be accomplished with:
//        a <- base_obj
//             ...
//   This is a form of composition, but it also defines and opens a new scope for further
//   declarations in the block statements that follow.

//   2. References
//
//   I've been thinking a lot about this, and I think all objects will have normal
//   reference semantics. If one wants a copy instead of a reference, use the expansion
//   operator `~~`. If we decide to do automatic reference counting instead of GC, then
//   we can use the ampersand `&` to indicate a "weak" reference (meaning "strong" would
//   be the default). Copies will be "copy on write" to make them more efficient.

//   3. Badges
//
//   When composing, a "badge" can be assigned to the intermediate objects, giving us a
//   way to later jump directly to that object's scope for name resolution, skipping over
//   the normal hierarchy chain.
//   Use the pound sign `#` to badge an object during composition:
//        base_obj#base -> oth_obj#child -> some_func()
//   Later use the ampersand `@` to access the badged object directly.
//   For example within `some_func`, where we have an `$obj` scope, we could write:
//        @base.parent_func()
//   which is equivalent to
//        $obj@base.parent_func()
//   Or, if we are saving the composition:
//        comp = base_obj#base -> oth_obj
//        comp@base.some_func()   //(1)
//        comp.some_func()   //(2)
//   Statement (1) will grab the function `some_func` defined on the original base_obj
//   array, skipping past any such object if defined on `oth_obj`; whereas statement (2)
//   will undergo a normal name resolution search starting with `oth_obj`.
//   Badges don't make sense on the rightmost end of a composition, because that will be
//   the "closest" end of the stack and you don't need a badge to reach it. Later on if
//   a saved composition is composed with something else, a badge would apply to the
//   (previously unavailable for badging) "nearest" or "right-most" end.
//        next_comp = comp#foo -> next_obj
//   is equivalent to adding the badge `foo` to `oth_obj` from the original composition:
//        next_comp = base_obj#base -> oth_obj#foo -> next_obj
//   That also means that this:
//        some_obj#foo -> some_func()
//   is allowed but is sort of pointless, because inside the function, using `@foo` is not
//   necessary: that is where scope searches would start anyway (i.e., the badge isn't
//   "skipping" anything).



grammar Wry;

tokens { INDENT, DEDENT }

@lexer::members {

	private boolean pendingDent = true;   // Setting this to true means we start out in `pendingDent` state and any whitespace at the beginning of the file will trigger an INDENT, which will probably be a syntax error, as it is in Python.

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
				tokenQueue.offer(createToken(DentParser.INDENT, "INDENT" + indentCount, next));
			} else {
				indentStack.pop();
				tokenQueue.offer(createToken(DentParser.DEDENT, "DEDENT"+getSavedIndent(), next));
			}
		}
		pendingDent = false;
		tokenQueue.offer(next);
		return tokenQueue.poll();
	}

}

script : ( NEWLINE | statement )* EOF ;

statement
     :    inlineStatementList NEWLINE
     |    compoundStatement
     ;

inlineStatementList
     :    smallStatement ( ';' smallStatement )*  ';'? ;

smallStatement
     :    flowStatement
     |    exprList
     ;

flowStatement
     :    'break' inlineStatementList? Label?
     |    'continue' inlineStatementList? Label?
     |    'return' exprList
     |    'throw' exprList
//   |    'assert' exprList
//   |    'yield' exprList
     ;



/*
* blocks
*/

compoundStatement
     :    ifStatement
     |    doStatement
     |    forStatement
     |    tryStatement
     |    withStatement
     |    assignBlock
     |    funcBlock
     |    inheritBlock
     ;

ifStatement
     :    'if' exprList doableBlock ( 'else' 'if' exprList doableBlock )* ( 'else' doableBlock )?
     ;

doStatement
     :    'do' Label? block ( 'then' block )?
     |    'do' 'if' exprList Label? block ( 'then' block )?
     ;

forStatement
     :    'for' exprList Label? block ( 'then' block )?
     |    'for' exprList 'if' exprList Label? block ( 'then' block )?
     ;

tryStatement
     :    'try' doableBlock ( 'catch' 'if' exprList doableBlock )* ( 'catch' doableBlock )?
     ;

withStatement
     :    'with' nameRef block
     ;

assignBlock
     :    nameRef blockStatements
     |    exprList ':' blockStatements
     |    arrayLiteral blockStatements
     ;

funcBlock
     :    'func' Name blockStatements
     ;

inheritBlock
     :    nameRef ( '<-' exprList Label? )+ blockStatements?
     ;

block
     :    inlineStatementList NEWLINE
     |    blockStatements
     ;

blockStatements
     :    NEWLINE INDENT statement+ DEDENT
     ;

doableBlock
     :    block
     |    doStatement
     |    forStatement
     |    withStatement
     ;



/*
* expressions
*/

exprList
     :    expr ( ',' expr )* ','?
     ;

expr
     :    '(' exprList ')'                         #groupExpr
     |    expr Label? '->' expr                    #composeExpr
     |    expr '(' expr? ')'                       #executeExpr
     |    expr '<' expr '>'                        #argExpr
     |    sign=( PLUS | MINUS ) expr               #unarySignExpr
     |    NOT expr                                 #notExpr
     |    expr op=( MULT | DIV | MOD ) expr        #multExpr
     |    expr op=( PLUS | MINUS ) expr            #addExpr
     |    expr op=( LTEQ | GTEQ | LT | GT ) expr   #relationExpr
     |    expr AND expr                            #andExpr
     |    expr OR expr                             #orExpr
     |    nameRef '=' expr                         #assignExpr
     |    <assoc=right>  expr ':' expr             #assocExpr
     |    atom                                     #atomExpr
     ;

NOT : '!' ;
MULT : '*' | '×' ;
DIV : '/' | '÷' ;
MOD : '%' ;
PLUS : '+' ;
MINUS : '-' ;
LTEQ : '<=' | '≤' ;
GTEQ : '≥' | '>=' ;
LT : '<' ;
GT : '>' ;
AND : '&&' | '∧' ;
OR : '||' | '∨' ;

simpleStatement : LEGIT+ NEWLINE ;

blockStatements : LEGIT+ NEWLINE INDENT statement+ DEDENT ;

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; initialIndentToken = null; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

LEGIT : ~[ \t\r\n]+ ~[\r\n]*;   // Replace with your language-specific rules...
