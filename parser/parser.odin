package parser

import "../types"
import "core:log"

parse :: proc(
	tokens: ^[dynamic]types.Token_With_Kind,
) -> (
	tree: types.Syntax_Tree,
	err: types.Parser_Error,
) {
	tree.records = make([dynamic]types.Record_With_Kind)

	token_index := 0
	current_line_tokens: [4][dynamic]types.Token_Note
	current_voice_index := 0
	last_note_voice_index := -1 // Track which voice the last note was added to

	for token_index < len(tokens) {
		token := tokens[token_index]

		switch token.kind {
		case .Exclusive_Interpretation:
			excl := token.token.(types.Token_Exclusive_Interpretation)
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Exclusive_Interpretation,
					record = types.Record_Exclusive_Interpretation{spine_type = excl.spine_type},
					line = token.line,
				},
			)

		case .Tandem_Interpretation:
			tand := token.token.(types.Token_Tandem_Interpretation)
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Tandem_Interpretation,
					record = types.Record_Tandem_Interpretation {
						code = tand.code,
						value = tand.value,
					},
					line = token.line,
				},
			)

		case .Reference_Record:
			ref := token.token.(types.Token_Reference_Record)
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Reference,
					record = types.Record_Reference{code = ref.code, data = ref.data},
					line = token.line,
				},
			)

		case .Comment:
			comm := token.token.(types.Token_Comment)
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Comment,
					record = types.Record_Comment{text = comm.text},
					line = token.line,
				},
			)

		case .Bar_Line:
			bar := token.token.(types.Token_Bar_Line)
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Bar_Line,
					record = types.Record_Bar_Line{bar_number = bar.bar_number},
					line = token.line,
				},
			)

		case .Repeat_Decoration_Barline:
			// Repeat/decoration barlines like =:|! are ornamental for our purposes.
			// They should not create a bar boundary or reset timestamps.
			// Ignore.

		case .Double_Bar:
			append(
				&tree.records,
				types.Record_With_Kind {
					kind = .Double_Bar,
					record = types.Record_Double_Bar{},
					line = token.line,
				},
			)

		case .Tie_Start:
			// Tie_Start must be followed immediately by a Note token
			if token_index + 1 >= len(tokens) {
				log.error(
					"Tie_Start token at line",
					token.line + 1,
					"not followed by a Note token",
				)
				return {}, .Malformed_Note
			}
			next_token := &tokens[token_index + 1]
			if next_token.kind != .Note {
				log.error(
					"Tie_Start token at line",
					token.line + 1,
					"must be followed by a Note token, got:",
					next_token.kind,
				)
				return {}, .Malformed_Note
			}
			// Set tie_start on the next note token
			note := &next_token.token.(types.Token_Note)
			note.tie_start = true
		// Don't increment token_index yet - let the Note case handle it

		case .Tie_End:
			// Tie_End must be preceded by a Note token in the same voice
			if last_note_voice_index < 0 {
				log.error("Tie_End token at line", token.line + 1, "not preceded by a Note token")
				return {}, .Malformed_Note
			}
			if len(current_line_tokens[last_note_voice_index]) == 0 {
				log.error("Tie_End token at line", token.line + 1, "not preceded by a Note token")
				return {}, .Malformed_Note
			}
			// Set tie_end on the last note token added to this voice
			last_note_index := len(current_line_tokens[last_note_voice_index]) - 1
			current_line_tokens[last_note_voice_index][last_note_index].tie_end = true

		case .Note:
			note := token.token.(types.Token_Note)
			if current_voice_index < 4 {
				append(&current_line_tokens[current_voice_index], note)
				last_note_voice_index = current_voice_index
			}

		case .Rest:
			// Convert rest token to a note token with empty note_name to represent a rest
			// This allows us to store rests and notes together, maintaining chronological order
			rest_token := token.token.(types.Token_Rest)
			rest_as_note := types.Token_Note{
				duration          = rest_token.duration,
				dots              = rest_token.dots,
				note_name         = "", // Empty note_name indicates a rest
				accidental        = "",
				tie_start         = false,
				tie_end           = false,
				has_fermata       = false,
				note_repeat_count = 0,
				is_lower_case     = false,
				line              = rest_token.line,
			}
			if current_voice_index < 4 {
				append(&current_line_tokens[current_voice_index], rest_as_note)
			}

		case .Voice_Separator:
			current_voice_index += 1
			last_note_voice_index = -1 // Reset when voice changes

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
					types.Record_With_Kind {
						kind = .Data_Line,
						record = types.Record_Data_Line{voice_tokens = current_line_tokens},
						line = token.line,
					},
				)
				for i in 0 ..< 4 {
					current_line_tokens[i] = make([dynamic]types.Token_Note)
				}
			}
			current_voice_index = 0
			last_note_voice_index = -1

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
					types.Record_With_Kind {
						kind = .Data_Line,
						record = types.Record_Data_Line{voice_tokens = current_line_tokens},
						line = token.line,
					},
				)
			}
			return tree, nil

		case:
		}

		token_index += 1
	}

	return tree, nil
}
