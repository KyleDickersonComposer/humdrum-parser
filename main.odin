package main

import "core:fmt"
import "core:log"
import "core:unicode/utf8"

import d "humdrum-data"
import t "types"

// NOTE: This isn't used because we are just building the json directly.
// Could use this Token enum later if we want to support arbitrary
// output formats.
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
	Broke_Array_Bounds,
	Reached_End_Of_Array,
	Rune_Match_Failed,
}

Parse_Error :: union {
	Tokenizer_Error,
}

Parser :: struct {
	data:       []rune,
	index:      int,
	line_count: int,
}


Valid_Record_Code :: enum {
	Scholarly_Catalog_Number,
	Publisher_Catalog_Number,
}

Valid_Tandem_Interpretation_Code :: enum {
	IC_Vox,
	I_Bass,
	I_Tenor,
	I_Alto,
	I_Soprn,
	Clef_F4,
	Clef_Gv2,
	Clef_G2,
}

eat :: proc(p: ^Parser) -> rune {
	r := p.data[p.index]
	p.index += 1
	return r
}

eat_until :: proc(p: ^Parser, rune_buffer: ^[dynamic]rune, needle: rune) -> Parse_Error {
	if p.index + 1 > len(p.data) {
		log.error("couldn't find a match and ate entire array")
		return .Broke_Array_Bounds
	}

	for i in 0 ..< 50 {
		if p.data[p.index] != needle {
			append(rune_buffer, p.data[p.index])
			p.index += 1
		} else {
			p.index += 1
			return nil
		}
	}

	log.error("Eat 50 runes and failed to find match. This limit is abritrary and can be adjusted")
	return .Rune_Match_Failed
}

eat_line :: proc(p: ^Parser, eated_list: ^[dynamic]rune) -> Parse_Error {
	for {
		if (peek(p) or_return) != '\n' {
			append(eated_list, eat(p))
		} else {
			append(eated_list, eat(p))
			break
		}
	}

	p.line_count += 1

	return nil
}

peek :: proc(p: ^Parser, offset: int = 1) -> (rune, Parse_Error) {
	if p.index + 1 > len(p.data) {
		return '0', .Reached_End_Of_Array
	}
	pos := p.index + offset

	return p.data[pos], nil
}

// NOTE: Doing this instead of building tokens.
peek_until :: proc(p: ^Parser, peeked_runes: ^[dynamic]rune, needle: rune) -> (err: Parse_Error) {
	for i in 0 ..< 50 {
		p0 := peek(p, i) or_return
		if p0 != needle {
			append(peeked_runes, p0)
		} else {
			return nil
		}
	}

	log.error(
		"Peeked for 50 tokens and failed to find match. This is an arbitrary limit and can be adjusted.",
	)
	return .Rune_Match_Failed
}

match_string :: proc(p: ^Parser, needle: string) -> (pred: bool, err: Parse_Error) {
	str_len := len(needle)
	peek_runes := make([]rune, str_len)
	defer delete(peek_runes)

	for i in 0 ..< str_len {
		if p.index < 0 || p.index > len(p.data) {
			return false, .Broke_Array_Bounds
		}

		peek_runes[i] = p.data[p.index + i]
	}

	peek_string := utf8.runes_to_string(peek_runes)
	defer delete(peek_string)

	if needle == peek_string {
		return true, nil
	}

	return false, nil
}

match_rune :: proc(p: ^Parser, needle: rune) -> (pred: bool, err: Parse_Error) {
	if p.index < 0 || p.index > len(p.data) {
		return false, .Broke_Array_Bounds
	}
	if p.data[p.index] == needle {
		return true, nil
	}

	return false, nil
}

compare_rune_slice :: proc(first: []rune, second: []rune) -> bool {
	if len(first) != len(second) {
		return false
	}

	for i in 0 ..< len(first) {
		if first[i] != second[i] {
			return false
		}
	}

	return true
}

create_valid_record_code_map :: proc(the_map: ^map[Valid_Record_Code]string) {
	the_map[.Scholarly_Catalog_Number] = "SCT"
	the_map[.Publisher_Catalog_Number] = "PC#"
}

create_valid_tandem_interpretation_code_map :: proc(
	the_map: ^map[Valid_Tandem_Interpretation_Code]string,
) {
	the_map[.IC_Vox] = "ICvox"
	the_map[.I_Bass] = "Ibass"
	the_map[.I_Tenor] = "Itenor"
	the_map[.I_Alto] = "Ialto"
	the_map[.I_Soprn] = "Isoprn"
	the_map[.Clef_F4] = "clefF4"
	the_map[.Clef_G2] = "clefG2"
	the_map[.Clef_Gv2] = "clefGv2"
}

is_note_name_rune :: proc(note_name: rune) -> bool {
	for nn in NOTE_NAMES {
		if nn == note_name {
			return true
		}
	}

	return false
}

NOTE_NAMES :: []rune{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'a', 'b', 'c', 'd', 'e', 'f', 'g'}

parse :: proc(parse_data: ^[]rune) -> Parse_Error {
	context.logger = log.create_console_logger()

	parser: Parser

	parser.data = parse_data^
	parser.index = 0

	eated := make([dynamic]rune)
	defer delete(eated)

	for {
		clear(&eated)

		if parser.index > len(parser.data) {
			return nil
		}

		p0 := peek(&parser, 0) or_return

		if p0 == '\n' {
			eat(&parser)
			continue
		}

		switch p0 {
		// reference record
		case '!':
			p1 := peek(&parser, 1) or_return
			p2 := peek(&parser, 2) or_return
			p3 := peek(&parser, 3) or_return

			if p1 == '!' && p2 == '!' && p3 != '!' {
				eat(&parser)
				eat(&parser)
				eat(&parser)


				parsed_code := make([dynamic]rune)
				defer delete(parsed_code)

				peek_until(&parser, &parsed_code, ':') or_return

				valid_record_codes := make(map[Valid_Record_Code]string)
				create_valid_record_code_map(&valid_record_codes)

				is_valid_record_code := false
				for _, valid_code in valid_record_codes {
					valid_code_to_runes := utf8.string_to_runes(valid_code)
					defer delete(valid_code_to_runes)

					if compare_rune_slice(parsed_code[:], valid_code_to_runes) {
						is_valid_record_code = true
						break
					}
				}

				if !is_valid_record_code {
					code := utf8.runes_to_string(parsed_code[:])
					defer delete(code)
					log.warn("unsupported record code:", code, "on line:", parser.line_count + 1)
					eat_line(&parser, &eated) or_return
					continue
				}

				if is_valid_record_code {
					eat(&parser)
					eat(&parser)
					eat(&parser)
				}

				if !(match_rune(&parser, ':') or_return) {
					log.warn("expected ':' after record code on line", parser.line_count + 1)
					eat_line(&parser, &eated) or_return
					continue
				}

				// colon after record code
				if match_rune(&parser, ':') or_return {
					eat(&parser)

					// eat the white space
					if match_rune(&parser, ' ') or_return {
						eat(&parser)
					}

				}

				// discard the eated for now
				eat_line(&parser, &eated) or_return
				continue

			} else {
				log.warn(
					fmt.aprintf(
						"expected '!!!' on line %v, only reference records are supported.",
						parser.line_count + 1,
					),
				)
				eat_line(&parser, &eated) or_return
			}

		// tandem or exclusive interpretation
		case '*':
			p1 := peek(&parser) or_return
			p2 := peek(&parser, 2) or_return

			// matched tandem interpretation
			if p1 != '*' {
				eat(&parser)

				// matched meter declaration
				if p1 == 'M' && p2 != 'M' {
					// TODO: this needs to handle tabs
					eat_line(&parser, &eated)
					continue
				}

				// matched spine terminator
				if p1 == '-' {
					// TODO: this needs to handle tabs
					eat_line(&parser, &eated)
					continue
				}

				// look for tandem interpretation code match
				tic_map := make(map[Valid_Tandem_Interpretation_Code]string)
				create_valid_tandem_interpretation_code_map(&tic_map)

				peek_until(&parser, &eated, '\t')

				// TODO: switch on enum here to handle the things
				found_match := false
				for _, v in tic_map {
					if match_string(&parser, v) or_return {
						eat_line(&parser, &eated) or_return
						found_match = true
						break
					}
				}

				if found_match {
					continue
				}


				// look for key match
				// TODO:Handle tabs and meter parse here
				if is_note_name_rune(p1) {
					// NOTE: peek is one less because we ate the *
					next_rune := peek(&parser, 1) or_return
					// key_name doesn't contain accidental
					if next_rune == ':' {
						eat_line(&parser, &eated) or_return
						continue
					}

					// key name contains accidental
					if next_rune == '-' || next_rune == '#' {
						if (peek(&parser, 2) or_return) != ':' {
							log.error(
								"expected ':' after key declaration on line:",
								parser.line_count + 1,
							)
							eat_line(&parser, &eated) or_return
							continue

						}
						eat_line(&parser, &eated) or_return
						continue
					}
				}

				// handle unsupported
				clear(&eated)
				eat_until(&parser, &eated, '\t') or_return
				data := utf8.runes_to_string(eated[:])
				log.warn(
					"unsupported tandem interpreteation code:",
					data,
					"on line:",
					parser.line_count + 1,
				)

				eat_line(&parser, &eated) or_return
				continue
			}

			// matched exclusive interpretation
			if p1 == '*' {
				eat(&parser)
				eat(&parser)

				if match_string(&parser, "kern") or_return {
					// TODO: this needs to handle the 4 columns thing
					eat_until(&parser, &eated, '\t') or_return
					eat_line(&parser, &eated)
					continue
				} else {
					eat_until(&parser, &eated, '\t') or_return
					data := utf8.runes_to_string(eated[:])
					defer delete(data)

					log.warn("unsupported exclusive record kind: ", data)
					continue
				}
			}

			eat_line(&parser, &eated) or_return

		case '=':
			log.error("= on line:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return

		case '1', '2', '4', '8':
			log.error("number on:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return
		case 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'a', 'b', 'c', 'd', 'e', 'f', 'g':
			log.error("note_name on:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return

		case '.':
			log.error("null record on:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return

		case '[':
			log.error("tie start on:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return

		case:
			log.error("invalid token on line:", parser.line_count + 1)
			eat_line(&parser, &eated) or_return
		}
	}

	return nil
}

main :: proc() {
	parse_data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(parse_data)

	err := parse(&parse_data)
	if err != nil {
		log.error("[error]:", err)
	}
}
