/*
* Wry.g4
*
* ANTLR4 grammar for wry.
*
* Author: Mike Weaver
* Created: 2017-03-15
*
*/


//   Another thought I had: we can compose an object with a function, without calling the function, and save that.
//   Doing so creates a sort of "bundle" with the function and a built-in $obj. But what about allowing the same thing
//   with a pre-composed, or bundled, $arg? So maybe we allow this:
//        saved = my_obj -> my_func < my_arg >
//   Then that can be saved and called later. It can also be composed later, so we might see something like this:
//        oth_obj -> saved( oth_args... )
//   And in this case, the $obj will be equivalent to `oth_obj -> my_obj` and the $arg will be equivalent to oth_args replayed
//   on top of (i.e. overwriting) my_arg.
//   The thing to note here is that the object provided at the call will be composed "behind" the original (searched last),
//   but the args will be combined with original, replacing any that have the same key. Another way to think about this is $args will not be
//   composed into a hierarchy. There is only 1 $args and if it composed multiple times, it will be the result of overwriting each time. And during function execution, the $arg scope will be marked as "read-only" so attempts to modify it will blow up.


//   Another thing I want to provide for is composing and defining at the same time. This allows for a form of inheritance.
//   So instead of this:
//        copy = base_obj
//        a = copy -> []   // or however we designate an empty array? maybe with a comma?
//        with a
//             ...
//        // update: based on my answer below dated 2017-04-18, we could write the example like this:
//        a = ~~base_obj -> []
//        with a
//             ...
//   All of the above can be accomplished with:
//        a <- base_obj
//             ...
//   Something to note: normally composing would create a reference to the original objects, but in this case we probably don't want a reference,
//   we want a copy. So what mechanism do we have to allow the alternative? In other words, how do we get a copy of `base_obj`, if that is what we want, in the following:
//        a = base_obj -> []
//   instead of a reference, which would be the normal result?
//   [2017-04-18] I know the answer: we use expansion:
//        a = ~~base_obj -> []
//   That will make a composition of a _copy_ of `base_obj`above an empty object and the result will be stored in `a`.

//   So maybe the one remaining question is how do we assign a reference of an object? or store a reference to an object:
//        a = ( parent=<ref to some object>, name="fred" )
//   The C-like syntax (also PHP) would be to use `&` as a prefix in front of the object name.

//   [Updated on 2017-04-17] When composing, we can assign a "badge" to an object so that we can do name lookup directly on that object,
//   rather than up the normal hierarchy chain.
//   Use the pound sign (octothorp) to badge an object during composition:
//        base_obj#base -> oth_obj#child -> some_func()
//   Later use the ampersand to access the badged object directly (for example inside a function with an $obj in scope):
//        @base.parent_func()
//   Or, if we are saving the composition:
//        comp = base_obj#base -> oth_obj#child
//        comp@base.some_func()   //(1)
//        comp.some_func()   //(2)
//   Version 1 will grab the function `some_func` defined on the original base_obj array, ignoring it if it exists on `oth_obj`; whereas version 2
//   will undergo a normal name resolution search starting with `oth_obj`.

//   Also need to sort out how strong and weak references will work. They only make sense in assignments
//   (so a new name is pointing at a reference to an existing name) or maybe return statements from functions.
//   This includes assignments that are happening inside an array construction. Let's go see how PHP handles this.


grammar Wry;

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
                    tokenQueue.offer(createToken(WryParser.INDENT, "INDENT" + indentCount, next));
               } else {
                    indentStack.pop();
                    tokenQueue.offer(createToken(WryParser.DEDENT, "DEDENT"+getSavedIndent(), next));
               }
          }
          pendingDent = false;
          tokenQueue.offer(next);
          return tokenQueue.poll();
     }

}

script
     :    ( NEWLINE | statement )* EOF
     ;

/*
* statement
*/

statement
     :    inlineStatementList NEWLINE
     |    compoundStatement
     ;

inlineStatementList
     :    smallStatement ( ';' smallStatement )*  ';'? ;

/*
* smallStatement
*/

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
* compound statement
*/

compoundStatement
     :    ifStatement
     |    doStatement
     |    forStatement
     |    tryStatement
     |    withStatement
     |    assignBlock
     ;

ifStatement
     :    'if' exprList doableBlock ( 'else' 'if' exprList doableBlock )* ( 'else' doableBlock )?
     ;

doStatement
     :    'do' ( Label )? block ( 'then' block )?
     |    'do' 'if' exprList ( Label )? block ( 'then' block )?
     ;

forStatement
     :    'for' exprList ( Label )? block ( 'then' block )?
     |    'for' exprList 'if' exprList ( Label )? block ( 'then' block )?
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
     :    expr ( ',' expr)* ','?
     ;

expr
     :    '(' exprList ')'                         #groupExpr
     |    expr '->' expr                           #composeExpr
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
     |<assoc=right>  expr ':' expr                 #assocExpr
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

// funcBlock
//   :    inlineStatementList
//   |    blockStatements
//   ;

atom
     :    nameExpression
     |    functionExpression
     |    literal
     |    TildeName
     |    DubTildeName
     ;
TildeName : '~' Name ;
DubTildeName : '~~' Name ;

/*
* names
*/

nameExpression
     :    nameRef
     |    '&' nameRef
     |    '&&' nameRef
     ;

nameRef
     :    Name trailer*
     ;

trailer
     :    '[' expr ']'
     |    '.' PlainName
     ;

Name
     :    PlainName
     |    SpecialName
     ;

PlainName : NameHead NameChar*     ;
fragment NameHead : [_a-zA-Z] ;
fragment NameChar : [0-9] | NameHead ;

SpecialName : '$' PlainName ;

Label : '#' NameChar+ ;

/*
*    What does it mean to type `&a.fred` as opposed to `a.&fred`? I don't think we want to put the & in the middle of the dot operator. So it seems more natural to come first.
*    So does that make it a token? Or is it an operator?
*    It can't be just in front of a name, it needs to be in front of a reference.
*    Will this ever be used other than in assignment? YES: it could be in a return statement or in an array assignment used as an argument to a function.
*    So it seems like it is part of object reference, not really an operator
*/

/*
* literals
*/

literal
     :    numericLiteral
     |    StringLiteral
     |    booleanLiteral
     |    nullLiteral
     ;

booleanLiteral : 'true' | 'false' ;

nullLiteral : 'null' ;

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

NEWLINE : ( '\r'? '\n' | '\r' ) { if (pendingDent) { setChannel(HIDDEN); } pendingDent = true; indentCount = 0; initialIndentToken = null; } ;

WS : [ \t]+ { setChannel(HIDDEN); if (pendingDent) { indentCount += getText().length(); } } ;   //TODO: Swift includes \u000B, \u000C, and \u0000
