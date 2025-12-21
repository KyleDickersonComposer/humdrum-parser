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
	// Main arena is set in context.allocator (from main) - use for persistent strings
	// Scratch arena is in context.temp_allocator - use for temporary allocations
	
	// Tokens array uses main arena (needs to persist until after parse phase)
	tokens = make([dynamic]Token_With_Kind, 0, context.allocator)

	p: parser.Parser
	p.data = parse_data^
	p.index = 0
	if len(p.data) > 0 {
		p.current = p.data[0]
	} else {
		append(&tokens, Token_With_Kind{kind = .EOF, line = 0})
		return tokens, nil
	}

	// Temporary buffer uses scratch allocator (no delete needed - arena handles it)
	eated := make([dynamic]rune, 0, context.temp_allocator)

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
// Tokens array uses default allocator, so it can be safely deleted
cleanup_tokens :: proc(tokens: ^[dynamic]Token_With_Kind) {
	delete(tokens^)
}

