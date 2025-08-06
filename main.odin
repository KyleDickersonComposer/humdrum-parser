package main

import "core:fmt"
import "core:log"
import "core:unicode/utf8"

import d "humdrum-data"
import t "types"

Token :: enum {
	// Reference Record
	Triple_Bang,
	Record_Code,
	Colon,
	Record_Data,

	// Exclusive Interpretation
	Double_Star,
	Exclusive_Record_Kind,

	// Tandem Interpretation
	Star,
	Instrument_Class,
	Instrument_Voice,
	Spine_Meter,
	Spine_Clef,
	Spine_Key,

	// Data
	Null,
	Spine_Terminal,
	New_Bar,
	Double_Bar,
	Dot,
	Measure_Number,
	Rest,
	Duration,
	Accidental,
	Note_Name,
}

Tokenizer_Error :: enum {
	Reached_End_Of_Array,
	Invalid_Token,
}

Parse_Error :: union {
	Tokenizer_Error,
}

Parser :: struct {
	data:       []rune,
	index:      int,
	line_count: int,
}

DATA := utf8.string_to_runes(d.HUMDRUM_CHORALE)

VALID_RECORD_CODE := [][3]rune{[3]rune{'S', 'C', 'T'}, [3]rune{'P', 'C', '#'}}

eat :: proc(p: ^Parser) -> rune {
	r := p.data[p.index]
	p.index += 1
	return r
}

peek :: proc(p: ^Parser, offset: int = 1) -> (rune, Parse_Error) {
	if p.index + 1 > len(p.data) {
		return '0', .Reached_End_Of_Array
	}
	pos := p.index + offset

	return p.data[pos], nil
}

match :: proc(p: ^Parser, needle: rune) -> (pred: bool, err: Parse_Error) {
	r := peek(p) or_return

	if r == needle {
		return true, nil
	}

	return false, nil
}

eat_line :: proc(p: ^Parser) -> Parse_Error {
	for {
		r := peek(p) or_return

		if r != '\n' {
			eat(p)
		} else {
			eat(p)
			break
		}
	}

	p.line_count += 1

	return nil
}

parse :: proc() -> Parse_Error {
	context.logger = log.create_console_logger()

	parser: Parser

	data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(data)

	parser.data = data
	parser.index = 0

	for {
		if parser.index > len(parser.data) {
			return nil
		}

		p0 := peek(&parser, 0) or_return

		if p0 == '\n' {
			eat(&parser)
			continue
		}

		switch p0 {
		case '!':
			p1 := peek(&parser, 1) or_return
			p2 := peek(&parser, 2) or_return
			p3 := peek(&parser, 3) or_return

			if p1 == '!' && p2 == '!' && p3 != '!' {
				eat(&parser)
				eat(&parser)
				eat(&parser)

				parsed_code: [3]rune
				for i in 0 ..< 3 {
					parsed_code[i] = peek(&parser, i) or_return
				}

				is_valid_record_code := false
				code_index := 0
				for valid_code, i in VALID_RECORD_CODE {
					if valid_code == parsed_code {
						is_valid_record_code = true
						code_index = i
					}
				}

				if !is_valid_record_code {
					code := utf8.runes_to_string(parsed_code[:])
					defer delete(code)
					log.warn("unsupported record code:", code, "on line:", parser.line_count + 1)
				}

				if is_valid_record_code {
					eat(&parser)
					eat(&parser)
					eat(&parser)
				}

				// colon after record code
				is_colon := match(&parser, ':') or_return
				if is_colon {
					eat(&parser)
				}

				is_white_space := peek(&parser) or_return
				if is_white_space == ' ' {
					eat(&parser)
				}

				// eat rest for now
				eat_line(&parser)

			} else {
				log.warn(
					fmt.aprintf(
						"expected '!!!' on line %v, only reference records are supported.",
						parser.line_count + 1,
					),
				)
				eat_line(&parser)
			}

		case '*':
			log.error("* on line:", parser.line_count + 1)
			eat_line(&parser)

		case '=':
			log.error("= on line:", parser.line_count + 1)
			eat_line(&parser)

		case '1', '2', '4', '8':
			log.error("number on:", parser.line_count + 1)
			eat_line(&parser)

		case '.':
			log.error("null record on:", parser.line_count + 1)
			eat_line(&parser)

		case '[':
			log.error("tie start on:", parser.line_count + 1)
			eat_line(&parser)

		case:
			log.error("invalid token on line:", parser.line_count + 1)
			eat_line(&parser)
		}
	}

	return nil
}

main :: proc() {
	err := parse()
	if err != nil {
		log.error("[error]:", err)
	}
}
