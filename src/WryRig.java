/*
* WryRig.java
*
* A test program to interpret a Wry script.
*
* Author: Mike Weaver
* Created: 2017-05-02
*
*/

import org.antlr.v4.runtime.ANTLRInputStream;
import org.antlr.v4.runtime.CommonTokenStream;
import org.antlr.v4.runtime.ParserRuleContext;
import org.antlr.v4.runtime.Token;
import org.antlr.v4.runtime.tree.*;

import java.io.FileInputStream;
import java.io.InputStream;

public class WryRig {
	public static void main(String[] args) throws Exception {
		String inputFile = null;
		if (args.length>0) inputFile = args[0];
		InputStream is = System.in;
		if (inputFile!=null) { is = new FileInputStream(inputFile); }
		ANTLRInputStream input = new ANTLRInputStream(is);

		WryLexer lexer = new WryLexer(input);
		CommonTokenStream tokens = new CommonTokenStream(lexer);
		WryParser parser = new WryParser(tokens);
		ParseTree tree = parser.script(); // parse

		ParseTreeWalker walker = new ParseTreeWalker(); // create standard walker
		WryRigListener generator = new WryRigListener(parser);
		walker.walk(generator, tree); // initiate walk of tree with listener
	}
}
