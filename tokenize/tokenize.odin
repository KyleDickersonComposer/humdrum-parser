package tokenize

import "../parser"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:unicode/utf8"

tokenize :: proc(parse_data: ^[]rune) -> (
	tokens: [dynamic]Token_With_Kind,
	err: parser.Parse_Error,
) {
	// Create a virtual arena allocator for all token string allocations
	// Arena is not destroyed here - strings need to persist after return
	// OS will clean up virtual memory on program exit
	arena: virtual.Arena
	alloc_err := virtual.arena_init_growing(&arena)
	if alloc_err != nil {
		return tokens, parser.Tokenizer_Error.Failed_To_Parse_Repeating_Rune
	}
	// Note: Arena intentionally not destroyed - strings must remain valid
	
	// Set context.allocator to use the arena for all string allocations
	saved_allocator := context.allocator
	context.allocator = virtual.arena_allocator(&arena)
	defer context.allocator = saved_allocator

	tokens = make([dynamic]Token_With_Kind)

	p: parser.Parser
	p.data = parse_data^
	p.index = 0
	if len(p.data) > 0 {
		p.current = p.data[0]
	} else {
		append(&tokens, Token_With_Kind{kind = .EOF, line = 0})
		return tokens, nil
	}

	eated := make([dynamic]rune)
	defer delete(eated)

	for {
		clear(&eated)

		switch p.current {
		case '!':
			parse_exclamation_line(&p, &tokens, &eated) or_return
				continue

		case '*':
			parse_asterisk_line(&p, &tokens, &eated) or_return
				continue

		case '=':
			parse_equals_line(&p, &tokens, &eated) or_return
				continue

		case '[':
			// Emit Tie_Start token
			append(
				&tokens,
				Token_With_Kind {
					kind = .Tie_Start,
					token = Token_Tie_Start{line = p.line_count},
					line = p.line_count,
				},
			)
			parser.eat(&p)
			continue

		case '1', '2', '3', '4', '5', '6', '7', '8', '9':
			parse_note(&p, &tokens, &eated) or_return
				continue

		case '#', '-':
			// Standalone accidentals should error - they must appear after a note name
			parse_note(&p, &tokens, &eated) or_return
			continue

		case '\t':
			append(
				&tokens,
				Token_With_Kind {
					kind = .Voice_Separator,
					token = nil,
					line = p.line_count,
				},
			)
			parser.eat(&p)
			continue

		case ']':
			// Emit Tie_End token
			append(
				&tokens,
				Token_With_Kind {
					kind = .Tie_End,
					token = Token_Tie_End{line = p.line_count},
					line = p.line_count,
				},
			)
				parser.eat(&p)
				continue
			
		case '.':
			parse_continuation_token(&p, &tokens, &eated) or_return
			continue

		case '\n':
			append(
				&tokens,
				Token_With_Kind {
					kind = .Line_Break,
					token = nil,
					line = p.line_count,
				},
			)
			parser.eat(&p)
			p.line_count += 1
			continue

		case '\r':
			parser.eat(&p)
			continue

		case 'L', 'J':
			// Beaming characters (beam open/close) - ignore at tokenizer level
			// They can appear standalone (e.g., after a tab) or after a note
			parser.eat(&p)
			continue

		case utf8.RUNE_EOF:
			append(
				&tokens,
				Token_With_Kind {
					kind = .EOF,
					token = nil,
					line = p.line_count,
				},
			)
			return tokens, nil

		case:
			log.error(
				"found unexpected character at the beginning of line:",
				p.line_count,
				"at rune index:",
				p.index,
				"invalid_line_start rune for 'kern', and likely to be an error of some kind",
			)
			return tokens, parser.Tokenizer_Error.Invalid_Token
		}
	}

	return tokens, nil
}

// Cleanup function for integration tests
// Deletes the tokens array. Arena memory is cleaned up by OS on program exit.
cleanup_tokens :: proc(tokens: ^[dynamic]Token_With_Kind) {
	delete(tokens^)
}

