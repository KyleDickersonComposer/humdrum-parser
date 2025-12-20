package tokenize

import "../parser"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"

tokenize :: proc(parse_data: ^[]rune) -> (
	tokens: [dynamic]Token_With_Kind,
	err: parser.Parse_Error,
) {
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
			// Eat tie start '[' and parse note with tie_start=true
			parser.eat(&p)
			if p.current == utf8.RUNE_EOF {
				break
			}
			parse_note(&p, &tokens, &eated, tie_start = true) or_return
			continue

		case '1', '2', '3', '4', '5', '6', '7', '8', '9':
			if p.current == utf8.RUNE_EOF {
				break
			}
			parse_note(&p, &tokens, &eated, tie_start = false) or_return
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

