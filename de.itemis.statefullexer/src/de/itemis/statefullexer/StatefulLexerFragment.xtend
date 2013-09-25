package de.itemis.statefullexer

import java.util.Set
import org.eclipse.xpand2.XpandExecutionContext
import org.eclipse.xtext.AbstractElement
import org.eclipse.xtext.AbstractRule
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.generator.Generator
import org.eclipse.xtext.generator.parser.antlr.ex.ExternalAntlrLexerFragment
import org.eclipse.xtext.generator.parser.antlr.ex.common.KeywordHelper
import org.eclipse.xtext.grammaranalysis.impl.GrammarElementTitleSwitch
import org.eclipse.xtext.util.formallang.PdaToDot
import org.eclipse.xtext.xbase.lib.Pair

import static extension org.eclipse.xtext.GrammarUtil.*
import static extension org.eclipse.xtext.util.Strings.*

abstract class StatefulLexerFragment extends ExternalAntlrLexerFragment {
	
//	override getGuiceBindingsRt(Grammar grammar) {
//		if (runtime)
//			return new BindFactory()
//				.addConfiguredBinding("RuntimeLexer",
//						"binder.bind(" + typeof(Lexer).getName() + ".class)"+
//						".annotatedWith(com.google.inject.name.Names.named(" +
//						"org.eclipse.xtext.parser.antlr.LexerBindings.RUNTIME" +
//						")).to(" + lexerGrammar +".class)")
//					.addTypeToType(typeof(Lexer).getName(), lexerGrammar)
//			.addTypeToProviderInstance(lexerGrammar, "org.eclipse.xtext.parser.antlr.LexerProvider.create(" + lexerGrammar + ".class)")
//				.getBindings();
//	}
	
	override generate(Grammar grammar, XpandExecutionContext ctx) {
//		println("begin")
		new KeywordHelper(grammar, false);
		lexerGrammar = grammar.namespace + ".lexer." + grammar.name.lastToken(".") + (if(runtime) "RT" else if(contentAssist) "CA" else "HI")
		val srcGen = if (contentAssist || highlighting) Generator::SRC_GEN_UI else Generator::SRC_GEN;
		val srcGenPath = ctx.output.getOutlet(srcGen).getPath();
		val grammarFile = lexerGrammar.replace('.', '/') + ".g";
//		println("writing " + grammarFile)

		val nfa2dot = new NfaToDot2()
		nfa2dot.stateFormatter.add[TokenNFA$TokenNfaState<AbstractElement> s | 
			switch(s.type) { 
				case(TokenNFA$NFAStateType::START): "start"
				case(TokenNFA$NFAStateType::ELEMENT): new GrammarElementTitleSwitch().doSwitch(s.token)
				case(TokenNFA$NFAStateType::STOP): "stop"
			}
		]
		nfa2dot.groupFormatter.add[LexicalGroup r | r.group.name + "\\n" + r.hidden.map[name].join(", ")]
		
		val pda2dot = new PdaToDot<TokenPDA$TokenPDAState<AbstractElement>, RuleCall>()
		pda2dot.setStateFormatter[
			switch(type) { 
				case(TokenPDA$PDAStateType::START): "start"
				case(TokenPDA$PDAStateType::ELEMENT): new GrammarElementTitleSwitch().showQualified.showAssignments.doSwitch(token)
				case(TokenPDA$PDAStateType::PUSH): new GrammarElementTitleSwitch().showQualified.showAssignments.doSwitch(token)
				case(TokenPDA$PDAStateType::POP): new GrammarElementTitleSwitch().showQualified.showAssignments.doSwitch(token)
				case(TokenPDA$PDAStateType::STOP): "stop"
			}
		]
		val pda = new LexerStatesProvider().getPda(grammar)
		ctx.output.openFile(lexerGrammar.replace('.', '/') + "GrammarPda.dot", srcGen)
		ctx.output.write(pda2dot.draw(pda))
		ctx.output.closeFile()
		
		nfa2dot.groupFormatter.add[AbstractRule r | r.name]
		val nfa1 = new LexerStatesProvider().getNfa(grammar)
		ctx.output.openFile(lexerGrammar.replace('.', '/') + "GrammarNfa.dot", srcGen)
		ctx.output.write(nfa2dot.draw(nfa1))
		ctx.output.closeFile()

		val nfa = new LexerStatesProvider().getStates(grammar)
		ctx.output.openFile(lexerGrammar.replace('.', '/') + "States.dot", srcGen)
		ctx.output.write(new NfaToDot2().draw(nfa))
		ctx.output.closeFile()

		ctx.output.openFile(grammarFile, srcGen)
		ctx.output.write(genLexer(grammar, nfa).toString)
		ctx.output.closeFile()

		var generateTo = if (lexerGrammar.lastIndexOf('.') != -1) lexerGrammar.substring(0, lexerGrammar.lastIndexOf('.')) else "";
		generateTo = srcGenPath + "/" + generateTo.replace('.', '/');
		addAntlrParam("-dfa");
//		addAntlrParam("-nfa");
//		addAntlrParam("-Xdfa");
//		addAntlrParam("-Xdfaverbose");
		addAntlrParam("-fo");
		addAntlrParam(generateTo);
		getAntlrTool().runWithParams(srcGenPath + "/" + grammarFile, getAntlrParams());

		val javaFile = srcGenPath+"/"+getLexerGrammar().replace('.', '/')+".java";
		suppressWarningsImpl(javaFile);
		
//		println("end")
	}
	
	def create it: <AbstractRule, Integer>newHashMap() getRule2Index(Grammar grammar) {
		var i = -1
		for(rule:grammar.allRules)
			put(rule, i = i + 1)
	}
	
	def getStateTokens(Grammar grammar, ILexerStatesProvider$ILexerStates nfa) {
		val groups = <Pair<Object, ILexerStatesProvider$ILexerState>, Token>newLinkedHashMap()
		for(s: nfa.allStates) {
			for(t : s.tokens) {
				var x = groups.get(t -> null)
				if(x == null)
					groups.put(t -> null, x = new Token(newLinkedHashSet(), t, null))
				x.sources.add(s)  
			} 
			for(t : nfa.getOutgoingTransitions(s)) {
				var x = groups.get(t.token -> t.target)
				if(x == null)
					groups.put(t.token -> t.target, x = new Token(newLinkedHashSet(), t.token, t.target))
				x.sources.add(s)  
			} 
		}
		val rule2index = grammar.rule2Index
		groups.values.sortBy[switch(it.token) { AbstractRule: rule2index.get(it.token) String: 0 }]
	}
	
	def getStatelessTerminalRules(Grammar grammar, ILexerStatesProvider$ILexerStates nfa) {
		val stateful = nfa.allStates.map[tokens + outgoingTransitions.map[token]].flatten.filter(typeof(TerminalRule)).toSet
		grammar.allTerminalRules.filter[!stateful.contains(it)]
	}
	
	def CharSequence genLexer(Grammar grammar, ILexerStatesProvider$ILexerStates nfa)
}

@Data class Token {
	Set<ILexerStatesProvider$ILexerState> sources
	Object token
	ILexerStatesProvider$ILexerState target
}