grammar Dent;

tokens { INDENT, DEDENT }

@lexer::members {

	private java.util.LinkedList<Token> tokenQueue = new java.util.LinkedList<>();

	private java.util.Stack<Integer> indentStack = new java.util.Stack<>();

	@Override
	public Token nextToken() {
		if (!tokenQueue.isEmpty()) { return tokenQueue.poll(); }
		Token next = super.nextToken();
		if (null == next || next.getType() != NEWLINE) { return next; }
		tokenQueue.offer(next);
		int indent = 0;
		do {
			Token grab = super.nextToken();
			if (null == grab) { break; }
			if (grab.getType() == DentParser.WS) {
				indent += grab.getText().length();
				tokenQueue.offer(grab);
			} else if (grab.getType() == DentParser.NEWLINE) {
				indent = 0;
				CommonToken token = new CommonToken(grab);
				token.setChannel(Token.HIDDEN_CHANNEL);
				tokenQueue.offer(token);
			} else if (grab.getType() == DentParser.COMMENT) {
				tokenQueue.offer(grab);
			} else {
				int prevIndent = indentStack.isEmpty() ? 0 : indentStack.peek();
				if (indent == prevIndent) {
					;
				} else if (indent > prevIndent) {
					indentStack.push(indent);
					CommonToken token = new CommonToken(DentParser.INDENT, "INDENT");
					//TODO: set the tokens start and end character indices...
					tokenQueue.offer(token);
				} else {
					//TODO: how to handle a DEDENT to a previously unknown indentation level...
					//TODO: we need to not just check for greater than, but eventually it should be equal to an original indent amount...
					while (!indentStack.isEmpty() && indentStack.peek() > indent) {
						CommonToken token = new CommonToken(DentParser.DEDENT, "DEDENT");
						tokenQueue.offer(token);
						indentStack.pop();
					}
				}
				tokenQueue.offer(grab);
				break;
			}
		} while (true);
		return tokenQueue.poll();
	}

}

script : ( NEWLINE | statement )* EOF ;

statement
	:	singleLineStatement
	|	blockStatements
	;

singleLineStatement : LEGIT+ NEWLINE ;

blockStatements : LEGIT+ NEWLINE INDENT statement+ DEDENT ;

LEGIT : ~[ \t\r\n]+ ;

NEWLINE : '\r'? '\n' | '\r' ;

WS : [ \t]+ -> channel(HIDDEN) ;

COMMENT
	:	BlockComment
	|	LineComment
	;
BlockComment : '/*' ( BlockComment | . )*? '*/' -> channel(HIDDEN) ;   // allow nesting comments
LineComment : '//' ~[\r\n] -> channel(HIDDEN) ;
