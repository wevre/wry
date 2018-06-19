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
//        a = base_obj -> ,
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

     // Starting out `true` for `pendingDent` will capture whitespace at beginning of script.
     private boolean pendingDent = true;
     private int indentCount = 0;
     private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();
     private java.util.Stack<Integer> indentStack = new java.util.Stack<>();
     private Token initialIndentToken = null;
     private int getSavedIndent() { return indentStack.isEmpty() ? 0 : indentStack.peek(); }

     private CommonToken createToken(int type, String text, Token next) {
          CommonToken token = new CommonToken(type, text);
          // If we have an `initialIndentToken` use it to set locations in `token`.
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
               //NOTE: This would be the appropriate spot to count whitespace or deal with NEWLINES;
               // instead, it is handled with custom actions down in the lexer rules.
          if (pendingDent && null == initialIndentToken && NEWLINE != next.getType()) { initialIndentToken = next; }
          if (null == next || HIDDEN == next.getChannel() || NEWLINE == next.getType()) { return next; }

          // Handle EOF; in particular, handle an abrupt EOF that comes without a NEWLINE.
          if (next.getType() == EOF) {
               indentCount = 0;
               if (!pendingDent) {   // We didn't have a final NEWLINE...
                    initialIndentToken = next;
                    tokenQueue.offer(createToken(NEWLINE, "NEWLINE", next));
               }
          }

          // Before exiting `pendingDent` state queue up proper INDENTS and DEDENTS.
          while (indentCount != getSavedIndent()) {
               if (indentCount > getSavedIndent()) {
                    indentStack.push(indentCount);
                    tokenQueue.offer(createToken(WryParser.INDENT, "INDENT" + indentCount, next));
               } else {
                    indentStack.pop();
                    tokenQueue.offer(createToken(WryParser.DEDENT, "DEDENT" + getSavedIndent(), next));
               }
          }
          pendingDent = false;
          tokenQueue.offer(next);
          return tokenQueue.poll();
     }

}



/*
* top level
*/

script
     :    ( NEWLINE | statement )* EOF
     ;



/*
* statements
*/

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

functionExpression
     :    '{' inlineStatementList '}'
     ;

atom
     :    nameRef
     |    functionExpression
     |    literal
     |    nameExpansion
     ;



/*
* names
*/

nameRef
     :    NamePrefix? Name nameTrailer*
     ;

NamePrefix : '&' | '@' | '$' ;

nameTrailer
     :    '[' exprList ']'   #keyLookup
     |    '.' Name           #memberLookup
     |    '@' Name           #badgeLookup
     ;

nameExpansion : ( '~' | '~~' ) nameRef ;   // Maybe this should be just a `name`, not a `nameRef`

Name : NameHead NameChar*     ;
fragment NameHead : [_a-zA-Z] ;
fragment NameChar : [0-9] | NameHead ;

Label : '#' NameChar+ ;



/*
* literals
*/

literal
     :    numericLiteral
     |    StringLiteral
     |    booleanLiteral
     |    nullLiteral
     |    arrayLiteral
     ;

booleanLiteral : 'true' | 'false' ;

nullLiteral : 'null' ;

arrayLiteral : ',' ;

numericLiteral
     :    integerLiteral
     |    FloatingPointLiteral
     ;



/*
* integer literal
*/

integerLiteral
     :    BinaryLiteral
     |    OctalLiteral
     |    DecimalLiteral
     |    DozenalLiteral
     |    HexadecimalLiteral
     ;

BinaryLiteral : '0b' BinDigit ( BinDigit | '_' )* ;
fragment BinDigit : [01] ;

OctalLiteral : '0o' OctDigit ( OctDigit | '_' )*  ;
fragment OctDigit : [0-7] ;

DecimalLiteral : DecDigit ( DecDigit | '_' )*     ;
fragment DecDigit : [0-9] ;

DozenalLiteral : '0d' DozDigit ( DozDigit | '_' )*     ;
fragment DozDigit : [0-9xeXE] ;

HexadecimalLiteral : '0x' HexDigit HexChars? ;
fragment HexDigit : [0-9a-fA-F] ;
fragment HexChars : ( HexDigit | '_' )+ ;



/*
* floating point literal
*/

FloatingPointLiteral
     :    DecimalLiteral ( '.' DecimalLiteral )? DecimalExponent?
     |    HexadecimalLiteral ( '.' HexDigit HexChars? )? HexadecimalExponent?
     ;
fragment DecimalExponent : [eE] (PLUS|MINUS)? DecimalLiteral ;
fragment HexadecimalExponent : [pP] (PLUS|MINUS)? DecimalLiteral ;



/*
* string literal
*/

StringLiteral
     :    '"' ( StringEscapeChar | ~[\r\n\\"] )*? '"'
     |    '\'' ( StringEscapeChar | ~[\r\n\\'] )*? '\''
     ;
fragment
StringEscapeChar
     :    '\\' [0\\tnr"']
     |    '\\x' HexDigit HexDigit
     |    '\\u' '{' HexDigit HexDigit HexDigit HexDigit '}'
     |    '\\u' '{' HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit '}'
     ;



/*
* comments and whitespace
*/

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

NEWLINE
     :    ( '\r'? '\n' | '\r' )
     {
          if (pendingDent) { setChannel(HIDDEN); }
          pendingDent = true;
          indentCount = 0;
          initialIndentToken = null;
     }
     ;

WS
     :    [ \t]+   //TODO: Swift includes \u000B, \u000C, and \u0000
     {
          setChannel(HIDDEN);
          if (pendingDent) { indentCount += getText().length(); }
     }
     ;
