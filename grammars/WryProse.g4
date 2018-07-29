/*
project : WryProse.g4
	author : Mike Weaver
	created : 2018-07-29

section : Introduction

	This is a test of pushing the core Dent functionality into a separate lexer
	grammar, and then including it in a regular grammar file.

*/

grammar WryProse;

@lexer::members {
	private int INDENT_TOKEN = WryProseParser.INDENT;
	private int DEDENT_TOKEN = WryProseParser.DEDENT;
}

import DentLexer;

script : ( NEWLINE | prose )* EOF ;

prose
	:	flow
	|	fieldStatement
	|	blockStatement
	;

flow : (Name|NonName)+ NEWLINE ;

nameAndTitle : Name (Colon title)? NEWLINE ;

title : (Name|NonName)+ ;

fieldStatement : nameAndTitle ;

blockStatement : nameAndTitle INDENT prose+ DEDENT ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

Name : NameHead NameChar* ;
fragment NameHead : [_a-zA-Z] ;
fragment NameChar : [0-9] | NameHead;

Colon : ':' ;

NonName : ~[ \t\r\n]+ ~[\r\n]* ;
