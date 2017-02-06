/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

grammar wren;

script : statement* ;

statement : assignmentStatement
          | flowStatement
          ;

assignmentStatement : assignmentList '=' expression ;

assignmentList : identifier ( ',' identifier )* ','?;

identifier : name ( namePostfix )* ;

namePostfix : '[' expression ']'
            | '.' name // this name actually can start with a digit
            | '::' name // also this one
            | ':' expression ':'
            ;

flowStatement : ifStatement
             // | whileStatement
              | forStatement
             // | doStatement
              ;

ifStatement : 'if' condition '{' statement* '}' ;

forStatment : 'for' array_pattern 'in' expression '{' statement* '}' ;

arrayLiteral : arrayField ( ',' arrayField)* (',')? ;

arrayField : expression
           | expression ':' expression
           | '~' name // this name could start with a digit
           ;

name : NAME ;

NAME : ALPHA ( ALPHA | DIGIT )*;

fragment DIGIT : '0'..'9' ;
fragment ALPHA : 'a'..'z'|'A'..'Z'|'_' ;

expression : binOpExpr
           | callExpr
           | literalExpr
           ;

binOpExpr : expression binOp expression ;

binOp : '*' | '/' | '-' | '+' | '->' ;

callExpr : identifier '(' expression ')' ;

literalExpr : numericLiteral
            | stringLiteral
            | booleanLiteral
            | nullLiteral
            | arrayLiteral
            ;

numericLiteral : intLiteral | floatLiteral ;

intLiteral : '-'? INT ;
floatLiteral : '-'? INT EXP
             | '-'? INT '.' DIGIT+ EXP? ;

booleanLiteral : TRUE | FALSE ;

nullLiteral : NULL ;

stringLiteral : '"' ( ESC | ~[\"\\] )* '"' ;

ESC : '\\' [\\/nrtbf\"] ;

INT : '0' | [1-9] [0-9]* ;
EXP : [Ee] [+\-]? INT ;

TRUE : [Tt] [Rr] [Uu] [Ee] ;
FALSE : [Ff] [Aa] [Ll] [Ss] [Ee] ;
NULL : [Nn] [Uu] [Ll] [Ll] ;
