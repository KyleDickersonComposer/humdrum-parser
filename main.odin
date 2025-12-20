package main

import "core:crypto"
import "core:fmt"
import "core:log"
import "core:os"
import "core:unicode/utf8"

import d "humdrum-data"
// import build_ir "./build_ir"
// import parse_syntax "./parse_syntax"
import tokenize "./tokenize"
// import t "./types"

main :: proc() {
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator()

	parse_data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(parse_data)

	tokens, token_err := tokenize.tokenize(&parse_data)
	if token_err != nil {
		log.error("Tokenization failed:", token_err)
		os.exit(1)
	}
	defer delete(tokens)

	// Print all tokens
	fmt.printf("=== TOKENIZER OUTPUT ===\n")
	fmt.printf("Total tokens: %d\n\n", len(tokens))
	
	for token, i in tokens {
		fmt.printf("[%d] Line %d: ", i, token.line + 1)
		switch token.kind {
		case .Note:
			note := token.token.(tokenize.Token_Note)
			fmt.printf("Note - name:'%s' duration:%d accidental:'%s' dots:%d\n", 
				note.note_name, note.duration, note.accidental, note.dots)
		case .Voice_Separator:
			fmt.printf("Voice_Separator\n")
		case .Line_Break:
			fmt.printf("Line_Break\n")
		case .Bar_Line:
			bar := token.token.(tokenize.Token_Bar_Line)
			fmt.printf("Bar_Line - bar_number:%d\n", bar.bar_number)
		case .Double_Bar:
			fmt.printf("Double_Bar\n")
		case .Exclusive_Interpretation:
			excl := token.token.(tokenize.Token_Exclusive_Interpretation)
			fmt.printf("Exclusive_Interpretation - spine_type:'%s'\n", excl.spine_type)
		case .Tandem_Interpretation:
			tand := token.token.(tokenize.Token_Tandem_Interpretation)
			fmt.printf("Tandem_Interpretation - code:'%s' value:'%s'\n", tand.code, tand.value)
		case .Reference_Record:
			ref := token.token.(tokenize.Token_Reference_Record)
			fmt.printf("Reference_Record - code:'%s' data:'%s'\n", ref.code, ref.data)
		case .Comment:
			comm := token.token.(tokenize.Token_Comment)
			fmt.printf("Comment - text:'%s'\n", comm.text)
		case .Rest:
			fmt.printf("Rest\n")
		case .Tie_Start:
			fmt.printf("Tie_Start\n")
		case .Tie_End:
			fmt.printf("Tie_End\n")
		case .EOF:
			fmt.printf("EOF\n")
		case:
			fmt.printf("UNKNOWN: %v\n", token.kind)
		}
	}

	// tree, parse_err := parse_syntax.parse_syntax(&tokens)
	// if parse_err != nil {
	// 	log.error("Syntax parsing failed:", parse_err)
	// 	os.exit(1)
	// }

	// m_IR_json, build_err := build_ir.build_ir(&tree)
	// if build_err != nil {
	// 	log.error("IR building failed:", build_err)
	// 	os.exit(1)
	// }

	fmt.printf("\n=== TOKENIZER COMPLETE ===\n")
}
