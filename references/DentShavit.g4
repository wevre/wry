/*
	*	DentShavit.g4
	*	https://github.com/wevrem/wry
	*	Author: Mike Weaver
*/

/*
	*	This grammar is rigged up to test the DenterHelper class created by Yuval Shavit.
*/
grammar DentShavit;

tokens { INDENT, DEDENT }

//@lexer::header {
//	import DenterHelper;
//}

@lexer::members {
	private final DenterHelper denter = new DenterHelper(NEWLINE, DentShavitParser.INDENT, DentShavitParser.DEDENT) {
		@Override
		public Token pullToken() {
			return DentShavitLexer.super.nextToken();
		}
	};

	@Override
	public Token nextToken() {
		return denter.nextToken();
	}
}

script : ( NEWLINE | statement )* EOF ;

statement
	:	simpleStatement
	|	blockStatements
	;

simpleStatement : LEGIT+ NEWLINE ;

blockStatements : LEGIT+ INDENT statement+ DEDENT ;

NEWLINE: ('\r'? '\n' ' '*) ;

WS : [ \t]+ ;

BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n]* -> channel(HIDDEN) ;

LEGIT : ~[ \t\r\n]+ ~[\r\n]*;   // Replace with your language-specific rules...
