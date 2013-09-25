package de.itemis.statefullexer

import java.util.Set
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.generator.parser.antlr.AntlrGrammarGenUtil
import org.eclipse.xtext.generator.parser.antlr.ex.common.KeywordHelper

import static extension org.eclipse.xtext.generator.parser.antlr.TerminalRuleToLexerBody.*
import static extension org.eclipse.xtext.util.Strings.*

class DefaultBacktrackingLexerFragment extends StatefulLexerFragment {
	override genLexer(Grammar grammar, ILexerStatesProvider$ILexerStates nfa) '''
		lexer grammar «lexerGrammar.lastToken(".")»;
		
		options {
			tokenVocab=Internal«grammar.name.lastToken(".") + "Lexer"»;
		}
		
		@header {
		package «lexerGrammar.skipLastToken(".")»;
		
		// Use our own Lexer superclass by means of import.
		«IF contentAssist»
			import org.eclipse.xtext.ui.editor.contentassist.antlr.internal.Lexer;
		«ELSE» 
			import org.eclipse.xtext.parser.antlr.Lexer;
		«ENDIF»
		}
		
		@members{
			«FOR s : nfa.allStates»
				// state «s.name» = «s.ID»
			«ENDFOR»
			private int tokenstate = «nfa.start.ID»;
		}
		
		«FOR s : getStateTokens(grammar, nfa)»
			«genToken(grammar, s.sources, s.token, s.target)»
		«ENDFOR»
		
		«FOR rule : getStatelessTerminalRules(grammar, nfa)»
			RULE_«rule.name»: «rule.toLexerBody»;
		«ENDFOR»
	'''

	def guardAction(Set<ILexerStatesProvider$ILexerState> sources) {
		val id = sources.map[ID].reduce[Integer a, Integer b|a + b]
		"{(tokenstate & " + id + ") != 0}?=>"
	}

	def transitionAction(ILexerStatesProvider$ILexerState target) {
		"{tokenstate=" + target.ID + ";}"
	}

	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword, Void NULL) '''
		«val keywords = KeywordHelper::getHelper(grammar)»
		«keywords.getRuleName(keyword)»: «sources.guardAction» '«AntlrGrammarGenUtil::toAntlrString(keyword)»';
	'''

	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule, Void NULL) '''
		RULE_«rule.name»: «if("ANY_OTHER" != rule.name) sources.guardAction» «rule.toLexerBody»;
	'''

	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword,
		ILexerStatesProvider$ILexerState target) '''
		«val keywords = KeywordHelper::getHelper(grammar)»
		«keywords.getRuleName(keyword)»: «sources.guardAction» '«AntlrGrammarGenUtil::toAntlrString(keyword)»' «target.
			transitionAction»;
	'''

	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule,
		ILexerStatesProvider$ILexerState target) '''
		RULE_«rule.name»: «if("ANY_OTHER" != rule.name) sources.guardAction» «rule.toLexerBody»  «target.transitionAction»;
	'''
}
