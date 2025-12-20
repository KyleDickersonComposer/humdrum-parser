package parse_syntax

import "../tokenize"
import "../parser"
import "core:log"

parse_syntax :: proc(tokens: ^[dynamic]tokenize.Token_With_Kind) -> (
	tree: Syntax_Tree,
	err: parser.Parse_Error,
) {
	tree.records = make([dynamic]Record_With_Kind)

	token_index := 0
	current_line_tokens: [4][dynamic]tokenize.Token_Note
	current_voice_index := 0

	for token_index < len(tokens) {
		token := tokens[token_index]

		switch token.kind {
		case .Exclusive_Interpretation:
			excl := token.token.(tokenize.Token_Exclusive_Interpretation)
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Exclusive_Interpretation,
					record = Record_Exclusive_Interpretation{spine_type = excl.spine_type},
					line = token.line,
				},
			)

		case .Tandem_Interpretation:
			tand := token.token.(tokenize.Token_Tandem_Interpretation)
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Tandem_Interpretation,
					record = Record_Tandem_Interpretation{code = tand.code, value = tand.value},
					line = token.line,
				},
			)

		case .Reference_Record:
			ref := token.token.(tokenize.Token_Reference_Record)
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Reference,
					record = Record_Reference{code = ref.code, data = ref.data},
					line = token.line,
				},
			)

		case .Comment:
			comm := token.token.(tokenize.Token_Comment)
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Comment,
					record = Record_Comment{text = comm.text},
					line = token.line,
				},
			)

		case .Bar_Line:
			bar := token.token.(tokenize.Token_Bar_Line)
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Bar_Line,
					record = Record_Bar_Line{bar_number = bar.bar_number},
					line = token.line,
				},
			)

		case .Double_Bar:
			append(
				&tree.records,
				Record_With_Kind {
					kind = .Double_Bar,
					record = Record_Double_Bar{},
					line = token.line,
				},
			)

		case .Note:
			note := token.token.(tokenize.Token_Note)
			if current_voice_index < 4 {
				append(&current_line_tokens[current_voice_index], note)
			}

		case .Rest:
			// Rests not currently handled, skip
			log.warn("Rest tokens not yet implemented")

		case .Voice_Separator:
			current_voice_index += 1

		case .Line_Break:
			has_notes := false
			for i in 0 ..< 4 {
				if len(current_line_tokens[i]) > 0 {
					has_notes = true
					break
				}
			}
			if has_notes {
				append(
					&tree.records,
					Record_With_Kind {
						kind = .Data_Line,
						record = Record_Data_Line{voice_tokens = current_line_tokens},
						line = token.line,
					},
				)
				for i in 0 ..< 4 {
					current_line_tokens[i] = make([dynamic]tokenize.Token_Note)
				}
			}
			current_voice_index = 0

		case .EOF:
			has_notes := false
			for i in 0 ..< 4 {
				if len(current_line_tokens[i]) > 0 {
					has_notes = true
					break
				}
			}
			if has_notes {
				append(
					&tree.records,
					Record_With_Kind {
						kind = .Data_Line,
						record = Record_Data_Line{voice_tokens = current_line_tokens},
						line = token.line,
					},
				)
			}
			return tree, nil

		case:
			log.warn("unhandled token kind in syntax parser:", token.kind)
		}

		token_index += 1
	}

	return tree, nil
}

