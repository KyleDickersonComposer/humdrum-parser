package tokenizer

import "../parsing"
import "../types"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:unicode/utf8"

tokenize :: proc(
	parse_data: ^[]rune,
) -> (
	tokens: [dynamic]types.Token_With_Kind,
	err: types.Tokenizer_Error,
) {
	// Main arena is set in context.allocator (from main) - use for persistent strings
	// Scratch arena is in context.temp_allocator - use for temporary allocations

	// Tokens array uses main arena (needs to persist until after parse phase)
	tokens = make([dynamic]types.Token_With_Kind, 0, context.allocator)

	p: types.Parser
	p.data = parse_data^
	p.index = 0
	if len(p.data) > 0 {
		p.current = p.data[0]
	} else {
		append(&tokens, types.Token_With_Kind{kind = .EOF, line = 0})
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
				types.Token_With_Kind {
					kind = .Tie_Start,
					token = types.Token_Tie_Start{line = p.line_count},
					line = p.line_count,
				},
			)
			parsing.eat(&p)
			continue

		case '1', '2', '3', '4', '5', '6', '7', '8', '9':
			parse_note(&p, &tokens, &eated) or_return
			continue

		case '\t':
			append(
				&tokens,
				types.Token_With_Kind{kind = .Voice_Separator, token = nil, line = p.line_count},
			)
			parsing.eat(&p)
			continue

		case ']':
			// Emit Tie_End token
			append(
				&tokens,
				types.Token_With_Kind {
					kind = .Tie_End,
					token = types.Token_Tie_End{line = p.line_count},
					line = p.line_count,
				},
			)
			parsing.eat(&p)
			continue

		case '.':
			parse_continuation_token(&p, &tokens, &eated) or_return
			continue

		case '\n':
			append(
				&tokens,
				types.Token_With_Kind{kind = .Line_Break, token = nil, line = p.line_count},
			)
			parsing.eat(&p)
			p.line_count += 1
			continue

		case '\r':
			parsing.eat(&p)
			continue

		case 'L', 'J':
			// Beaming characters (beam open/close) - ignore
			parsing.eat(&p)
			continue

		case utf8.RUNE_EOF:
			append(&tokens, types.Token_With_Kind{kind = .EOF, token = nil, line = p.line_count})
			return tokens, nil

		case:
			log.error(
				"found unexpected character at the beginning of line:",
				p.line_count,
				"at rune index:",
				p.index,
				"invalid_line_start rune for 'kern', and likely to be an error of some kind",
			)
			return tokens, .Invalid_Token
		}
	}

	return tokens, nil
}
