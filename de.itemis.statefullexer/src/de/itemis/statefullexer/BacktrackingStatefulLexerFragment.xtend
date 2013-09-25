package de.itemis.statefullexer

import java.util.Set
import org.eclipse.xtext.Grammar
import org.eclipse.xtext.TerminalRule
import org.eclipse.xtext.generator.parser.antlr.AntlrGrammarGenUtil
import org.eclipse.xtext.generator.parser.antlr.ex.common.KeywordHelper

import static extension org.eclipse.xtext.generator.parser.antlr.TerminalRuleToLexerBody.*
import static extension org.eclipse.xtext.util.Strings.*
import org.eclipse.xtext.common.parseTreeConstruction.TerminalsParsetreeConstructor$ThisRootNode

class BacktrackingStatefulLexerFragment extends StatefulLexerFragment {
	override genLexer(Grammar grammar, ILexerStatesProvider$ILexerStates nfa) '''
		lexer grammar «lexerGrammar.lastToken(".")»;
		
«««		options {
«««			backtrack=true;
«««			//memoize=true;
«««		}

		tokens {
			«FOR s : getStateTokens(grammar, nfa)»
				«genTokenName(grammar, s.sources, s.token)»
			«ENDFOR»
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
		
		SYNTHETIC_ALL_KEYWORDS :
			«FOR s : getStateTokens(grammar, nfa) SEPARATOR "|"»
				«genDispatch(grammar, s.sources, s.token, s.target)»
			«ENDFOR»
		;
		
		«FOR s : getStateTokens(grammar, nfa)»
			«genToken(grammar, s.sources, s.token)»
		«ENDFOR»
		
«««		«FOR rule : getStatelessTerminalRules(grammar, nfa)»
«««			RULE_«rule.name»: «rule.toLexerBody»;
«««		«ENDFOR»
	'''

	def guardAction(Set<ILexerStatesProvider$ILexerState> sources, String name) {
		val id = sources.map[ID].reduce[Integer a, Integer b|a + b]
//		if (name != "ANY_OTHER") '''(FRAGMENT_«name»)=> ''' else ''''''
//		if (name != "RULE_ANY_OTHER") '''(FRAGMENT_«name» {(tokenstate & «id») != 0}?)=> ''' else ''''''
		if (name != "RULE_ANY_OTHER") '''{(tokenstate & «id») != 0}?=> ''' else ''''''
//		if (name != "ANY_OTHER") '''(FRAGMENT_«name»)=> ''' else ''''''
//		if (name != "ANY_OTHER") '''(FRAGMENT_«name»)=> ''' else ''''''
	}
	
	def guardAction2(Set<ILexerStatesProvider$ILexerState> sources, String name) {
		val id = sources.map[ID].reduce[Integer a, Integer b|a + b]
//		if (name != "ANY_OTHER") '''{(tokenstate & «id») != 0}?=> ''' else ''''''
		 ''''''
	}

	def transitionAction(ILexerStatesProvider$ILexerState target) {
		"{tokenstate=" + target.ID + ";}"
	}

	def dispatch genTokenName(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword) '''
		«val name = KeywordHelper::getHelper(grammar).getRuleName(keyword)»
		«name»;
	'''

	def dispatch genTokenName(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule) '''
		RULE_«rule.name»;
	'''
	
	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword) '''
		«val name = KeywordHelper::getHelper(grammar).getRuleName(keyword)»
		fragment FRAGMENT_«name»: «sources.guardAction2(name)»'«AntlrGrammarGenUtil::toAntlrString(keyword)»';
	'''

	def dispatch genToken(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule) '''
		fragment FRAGMENT_RULE_«rule.name»: «sources.guardAction2("RULE_"+rule.name)»«rule.toLexerBody2»;
	'''

	def dispatch genDispatch(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword, Void target) '''
		«val name = KeywordHelper::getHelper(grammar).getRuleName(keyword)»
		«sources.guardAction(name)»((FRAGMENT_«name»)=>FRAGMENT_«name» {$type = «name»; } | . {$type = RULE_ANY_OTHER; }) 
	'''

	def dispatch genDispatch(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule, Void target) '''
		«sources.guardAction("RULE_"+rule.name)»FRAGMENT_RULE_«rule.name»{$type = RULE_«rule.name»; }
	'''
	
	def dispatch genDispatch(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, String keyword, ILexerStatesProvider$ILexerState target) '''
		«val name = KeywordHelper::getHelper(grammar).getRuleName(keyword)»
		«sources.guardAction(name)»((FRAGMENT_«name»)=>FRAGMENT_«name» {$type = «name»; tokenstate=«target.ID»; } | . {$type = RULE_ANY_OTHER; })
	'''

	def dispatch genDispatch(Grammar grammar, Set<ILexerStatesProvider$ILexerState> sources, TerminalRule rule, ILexerStatesProvider$ILexerState target) '''
		«sources.guardAction("RULE_"+rule.name)»FRAGMENT_RULE_«rule.name»{$type = RULE_«rule.name»; tokenstate=«target.ID»; }
	'''
	
	def String toLexerBody2(TerminalRule rule) {
		rule.toLexerBody
	}
}
