/*
project : TestDent.g4
	author : Mike Weaver
	created : 2018-07-28

section : Introduction

	This is a test of pushing the core Dent functionality into a separate lexer
	grammar, and then including it in a regular grammar file.

*/

grammar TestDent;

@lexer::members {
	private int INDENT_TOKEN = TestDentParser.INDENT;
	private int DEDENT_TOKEN = TestDentParser.DEDENT;
}

import DentLexer;

script : ( NEWLINE | statement )* EOF ;

statement
	:	simpleStatement
	|	blockStatements
	;

simpleStatement : LEGIT+ NEWLINE ;

blockStatements : LEGIT+ NEWLINE INDENT statement+ DEDENT ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

LEGIT : ~[ \t\r\n]+ ~[\r\n]* ;   // Replace with language-specific rules...
