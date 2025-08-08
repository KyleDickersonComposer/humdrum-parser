package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import d "humdrum-data"
import t "types"

Token :: union {
	Reference_Record,
	Tandem_Interpretation,
	Data,
}

Reference_Record :: struct {
	code: Valid_Record_Code,
	data: string,
}

Tandem_Interpretation :: struct {
	code:  Valid_Tandem_Interpretation_Code,
	value: string,
}

VALID_DATA_KIND :: enum {
	Double_Bar = 1,
	Bar,
	Note,
	Rest,
}

Note :: struct {
	note_name:         string,
	timestamp:         f32,
	duration:          int,
	accidental_offset: int,
}

Rest :: struct {
	duration:  int,
	timestamp: f32,
}

Meter :: struct {
	numerator:   int,
	denominator: int,
	type:        string,
}

Bar :: struct {
	double_bar: bool,
	key:        string,
	meter:      Meter,
}

Data :: union {
	Note,
	Bar,
	Rest,
}

Tokenizer_Error :: enum {
	None = 0,
	Invalid_Token,
	Broke_Array_Bounds,
	Reached_End_Of_Array,
	Rune_Match_Failed,
}

Syntax_Error :: enum {
	None = 0,
	Malformed_Note,
	Malformed_Accidental,
	Malformed_Bar_Number,
}

Conversion_Error :: enum {
	None = 0,
	Failed_To_Convert_To_Integer,
}

Lookup_Error :: enum {
	None = 0,
	Key_Lookup_Failed,
}

Parse_Error :: union #shared_nil {
	Syntax_Error,
	Tokenizer_Error,
	Conversion_Error,
	Lookup_Error,
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
	Meter,
	IC_Vox,
	I_Bass,
	I_Tenor,
	I_Alto,
	I_Soprn,
	Clef_F4,
	Clef_Gv2,
	Clef_G2,
}

NOTE_NAMES :: []rune{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'a', 'b', 'c', 'd', 'e', 'f', 'g'}

DURATION_NUMBERS :: []int{1, 2, 3, 4, 5, 6, 7, 8, 9}

LOWER_CASE_NOTE_NAMES :: []rune{'a', 'b', 'c', 'd', 'e', 'f', 'g'}

ACCIDENTAL :: []string{"#", "##", "-", "--", "n"}

ACCIDENTAL_RUNE :: []rune{'#', '-', 'n'}

eat :: proc(p: ^Parser) -> (rune, Parse_Error) {
	r := p.data[p.index]
	p.index += 1
	return r, nil
}

eat_until :: proc(p: ^Parser, rune_buffer: ^[dynamic]rune, needle: rune) -> Parse_Error {
	for i in 0 ..< 50 {
		if p.index + i > len(p.data) {
			return Tokenizer_Error.None
		}

		if p.index + 1 <= len(p.data) && p.data[p.index] == '\n' {
			return nil
		}

		eated := eat(p) or_return
		if eated != needle {
			append(rune_buffer, eated)
		} else {
			return nil
		}
	}

	log.error("Ate 50 runes and failed to find match. This limit is abritrary and can be adjusted")
	return .Rune_Match_Failed
}

peek :: proc(p: ^Parser, offset: int = 1) -> (rune, Parse_Error) {
	if p.index + 1 > len(p.data) {
		return '0', Tokenizer_Error.None
	}
	pos := p.index + offset

	return p.data[pos], nil
}

// NOTE: Doing this instead of building tokens.
peek_until :: proc(p: ^Parser, peeked_runes: ^[dynamic]rune, needle: rune) -> (err: Parse_Error) {
	for i in 0 ..< 50 {
		if p.index + i > len(p.data) {
			return .Reached_End_Of_Array
		}

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

convert_runes_to_int :: proc(runes: ^[dynamic]rune) -> (int, Conversion_Error) {
	to_string := utf8.runes_to_string(runes[:])
	defer delete(to_string)

	log.debug("convert runes:", to_string)

	value, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("got:", value)
		return 0, .Failed_To_Convert_To_Integer
	}

	return value, nil
}

convert_rune_to_int :: proc(r: rune) -> (int, Conversion_Error) {
	switch r {
	case '1':
		return 1, nil
	case '2':
		return 2, nil
	case '3':
		return 3, nil
	case '4':
		return 4, nil
	case '5':
		return 5, nil
	case '6':
		return 6, nil
	case '7':
		return 7, nil
	case '8':
		return 8, nil
	case '9':
		return 9, nil
	}

	log.error("got:", r)
	return 0, .Failed_To_Convert_To_Integer
}

key_table :: proc(note_name: rune, accid: string) -> (string, Lookup_Error) {
	to_string := utf8.runes_to_string([]rune{note_name})
	defer delete(to_string)

	switch note_name {
	case 'a', 'C':
		if accid == "" {
			return "C", nil
		}
		return "", .Key_Lookup_Failed
	case:
		return "", .Key_Lookup_Failed

	// case 'c', 'E':
	// case 'd', 'F':
	// case 'e', 'G':
	// case 'f', 'A':
	// case 'g', 'B':
	}

	return "", .Key_Lookup_Failed
}

is_note_name_rune :: proc(note_name: rune) -> bool {
	for nn in NOTE_NAMES {
		if nn == note_name {
			return true
		}
	}

	return false
}

is_duration_number :: proc(number: int) -> bool {
	for i in DURATION_NUMBERS {
		if i == number {
			return true
		}
	}

	return false
}

parse :: proc(parse_data: ^[]rune) -> Parse_Error {
	ref_records := make([dynamic]Reference_Record)
	defer delete(ref_records)

	tandem_records := make([dynamic]Tandem_Interpretation)
	defer delete(tandem_records)

	note_data_tokens := make([dynamic]Data)
	defer delete(note_data_tokens)

	bar_data_tokens := make([dynamic]Data)
	defer delete(bar_data_tokens)

	eated := make([dynamic]rune)
	defer delete(eated)

	key := ""
	meter: Meter

	parser: Parser

	parser.data = parse_data^
	parser.index = 0

	note_creation_started := false

	for {
		clear(&eated)

		if parser.index > len(parser.data) {
			return nil
		}

		p0 := peek(&parser, 0) or_return

		switch p0 {
		// reference record
		case '!':
			p1 := peek(&parser, 1) or_return
			p2 := peek(&parser, 2) or_return
			p3 := peek(&parser, 3) or_return

			if p1 == '!' && p2 == '!' && p3 != '!' {
				record := Reference_Record{}
				eat(&parser)
				eat(&parser)
				eat(&parser)


				parsed_code := make([dynamic]rune)
				defer delete(parsed_code)

				peek_until(&parser, &parsed_code, ':') or_return

				valid_record_codes := make(map[Valid_Record_Code]string)
				defer delete(valid_record_codes)
				create_valid_record_code_map(&valid_record_codes)

				matched_record_code: Valid_Record_Code

				is_valid_record_code := false
				for valid_code, valid_data in valid_record_codes {
					valid_code_to_runes := utf8.string_to_runes(valid_data)
					defer delete(valid_code_to_runes)

					if compare_rune_slice(parsed_code[:], valid_code_to_runes) {
						is_valid_record_code = true
						matched_record_code = valid_code
						break
					}
				}

				if !is_valid_record_code {
					code := utf8.runes_to_string(parsed_code[:])
					defer delete(code)
					log.warn("unsupported record code:", code, "on line:", parser.line_count + 1)
					eat_until(&parser, &eated, '\n') or_return
					continue
				}

				if is_valid_record_code {
					eat_until(&parser, &eated, ':') or_return

					record.code = matched_record_code
				}

				// colon after record code
				if match_rune(&parser, ':') or_return {
					eat(&parser)

					// eat the white space
					if match_rune(&parser, ' ') or_return {
						eat(&parser)
					}

				}

				if len(eated) > 0 do clear(&eated)

				eat_until(&parser, &eated, '\n') or_return

				eated_to_string := utf8.runes_to_string(eated[:])
				defer delete(eated_to_string)

				record.data = strings.trim_space(eated_to_string)

				continue

			} else {
				log.warn(
					fmt.aprintf(
						"expected '!!!' on line %v, only reference records are supported.",
						parser.line_count + 1,
					),
				)
				eat_until(&parser, &eated, '\n') or_return
			}

		// tandem or exclusive interpretation
		case '*':
			tandem: Tandem_Interpretation
			p1 := peek(&parser) or_return
			p2 := peek(&parser, 2) or_return

			// matched spine terminator
			if p1 == '-' {
				eat_until(&parser, &eated, '\n')
				continue
			}

			// matched exclusive interpretation
			if p1 == '*' {
				eat(&parser)
				eat(&parser)

				peek_until(&parser, &eated, '\t') or_return
				to_string := utf8.runes_to_string(eated[:])
				defer delete(to_string)

				if to_string == "kern" {
					eat_until(&parser, &eated, '\n')
					continue
				} else {
					eat_until(&parser, &eated, '\t') or_return
					data := utf8.runes_to_string(eated[:])
					defer delete(data)

					log.warn("unsupported exclusive record code: ", data)
					continue
				}
			}

			if p1 == 'M' && p2 == 'M' {
				eat_until(&parser, &eated, '\n')
				log.warn(
					"unsupported tandem interpretation code:",
					"'*MM'",
					"on line:",
					parser.line_count + 1,
				)
				continue
			}

			if p1 != '*' {
				eat(&parser)

				// look for tandem interpretation code match
				tic_map := make(map[Valid_Tandem_Interpretation_Code]string)
				create_valid_tandem_interpretation_code_map(&tic_map)

				peek_buffer := make([dynamic]rune)
				defer delete(peek_buffer)

				peek_until(&parser, &peek_buffer, '\t')

				// TODO: switch on enum here to handle the things
				found_match := false
				for _, v in tic_map {
					if match_string(&parser, v) or_return {
						eat_until(&parser, &eated, '\t') or_return
						found_match = true
						break
					}
				}

				if found_match {
					continue
				}

				switch p1 {
				// matched meter declaration
				case 'M':
					eat(&parser) or_return
					eat_until(&parser, &eated, '\t') or_return

					// NOTE: Doesn't handle polymeter
					numerator_runes := make([dynamic]rune)
					defer delete(numerator_runes)

					denominator_runes := make([dynamic]rune)
					defer delete(denominator_runes)

					for r, i in eated {
						if r != '/' {
							if i == 0 || i == 1 {
								append(&numerator_runes, r)
							} else {
								append(&denominator_runes, r)
							}
						}
					}

					log.debug("num_runes:", numerator_runes)
					log.debug("denom_runes:", denominator_runes)
					num_int := convert_runes_to_int(&numerator_runes) or_return
					denom_int := convert_runes_to_int(&denominator_runes) or_return


					meter_kind := "simple"

					if denom_int == 12 || denom_int == 9 || denom_int == 6 {
						meter_kind = "compound"
					}

					meter = Meter {
						numerator   = num_int,
						denominator = denom_int,
						type        = meter_kind,
					}
					to_string_eated := utf8.runes_to_string(eated[:])
					defer delete(to_string_eated)
					append(
						&tandem_records,
						Tandem_Interpretation{code = .Meter, value = to_string_eated},
					)
					log.debug(meter)
					eat_until(&parser, &eated, '\n') or_return
					continue

				case 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'A', 'B', 'C', 'D', 'E', 'F', 'G':
					eat_until(&parser, &eated, ':')

					// NOTE: peek is one less because we ate the *
					// key_name doesn't contain accidental
					if p2 == ':' {
						key = key_table(p1, "") or_return
						eat_until(&parser, &eated, '\n') or_return
						continue
					}

					// key name contains accidental
					if p2 == '-' || p2 == '#' {
						if (peek(&parser, 2) or_return) != ':' {
							log.error(
								"expected ':' after key declaration on line:",
								parser.line_count + 1,
							)
							eat_until(&parser, &eated, ':') or_return
							continue

						}
						if len(eated) > 0 do clear(&eated)

						eat_until(&parser, &eated, '\t') or_return
						to_string := utf8.runes_to_string(eated[:])
						defer delete(to_string)
						key = to_string

						eat_until(&parser, &eated, '\n') or_return
						continue
					}

				case:
					// handle unsupported
					clear(&eated)
					eat_until(&parser, &eated, '\t') or_return
					data := utf8.runes_to_string(eated[:])
					log.warn(
						"unsupported tandem interpretation code:",
						data,
						"on line:",
						parser.line_count + 1,
					)

					eat_until(&parser, &eated, '\n') or_return
					continue
				}

			}


		case '=':
			if (peek(&parser) or_return) == '=' {
				log.debug("found double_bar on line:", parser.line_count + 1)
				eat_until(&parser, &eated, '\n') or_return
				continue
			}

			// bar numbers
			val := eat(&parser) or_return
			log.debug("val:", val)
			eat_until(&parser, &eated, '\t') or_return
			log.debug("eated:", eated)

			if eated[0] == '\t' {
				log.error("couldn't parse bar_number:", eated)
				return .Malformed_Bar_Number
			}

			log.debug("bar_nums:", eated)
			bar_number := convert_runes_to_int(&eated) or_return

			append(&note_data_tokens, Bar{double_bar = false, key = key})

			log.debug(note_data_tokens)

			log.debug("creating bar number:", bar_number, "on line:", parser.line_count + 1)
			eat_until(&parser, &eated, '\n') or_return
			continue


		// match first char of note declaration
		case '1', '2', '3', '4', '5', '6', '7', '8', '9', '[':
			p0 := peek(&parser, 0) or_return
			p1 := peek(&parser) or_return

			note_creation_started = true
			is_lower_case_note_name := false
			val := eat(&parser) or_return
			log.debug("eated:", val)
			converted_val := convert_rune_to_int(val) or_return

			for n in LOWER_CASE_NOTE_NAMES {
				if p1 == n {
					is_lower_case_note_name = true
				}
			}

			if !is_note_name_rune(p1) {
				log.error("Invalid note_name:", p1, "on line:", parser.line_count + 1)
				return .Malformed_Note
			}

			note_name := eat(&parser) or_return
			log.debug("eated:", note_name)

			octave_offset := 0
			for i in 0 ..< 6 {
				note_repetition := peek(&parser, i) or_return

				if note_repetition != note_name do break
				octave_offset += 1
			}

			for i in 0 ..< octave_offset {
				eat(&parser) or_return
			}

			if !is_lower_case_note_name do octave_offset *= -1

			is_accid_0 := peek(&parser, 0) or_return
			is_accid_1 := peek(&parser, 1) or_return

			accid := ""

			is_accidental := false
			for accid in ACCIDENTAL_RUNE {
				if is_accid_0 == accid {
					is_accidental = true
				}
			}

			double_accidental := false
			if is_accidental && (is_accid_1 == '#' || is_accid_1 == '-') {
				double_accidental = true

				if is_accid_0 != is_accid_1 {
					log.error(
						"got:",
						is_accid_0,
						is_accid_1,
						"expected an accidental from this set:",
						ACCIDENTAL,
						"on line:",
						parser.line_count + 1,
					)
					return .Malformed_Accidental
				}

				runes := []rune{is_accid_0, is_accid_1}
				string_accid := utf8.runes_to_string(runes)
				defer delete(string_accid)

				accid = string_accid

				eat(&parser) or_return
				eat(&parser) or_return
			}

			if is_accidental && !double_accidental {
				to_string := eat(&parser) or_return

				temp_accid := utf8.runes_to_string([]rune{to_string})
				defer delete(temp_accid)
				accid = temp_accid
			}

			if (peek(&parser) or_return) == '\t' {
				log.debug("hit tab in note parsing")
				continue
			}

			if (peek(&parser) or_return) == '.' {
				log.debug("hit '.' in note parsing")
				continue
			}


			log.debug(
				"build note:",
				note_name,
				"accid:",
				accid,
				"dur:",
				converted_val,
				"oct:",
				4 + octave_offset,
				"on line:",
				parser.line_count + 1,
			)

			test_eat := eat_until(&parser, &eated, '\t')
			continue

		case '.':
			log.debug("ate '.' on line:", parser.line_count + 1)
			eat(&parser)
			continue

		case '\t':
			log.debug("ate tab on line:", parser.line_count + 1)
			eat(&parser)
			continue

		case ' ':
			log.debug("ate space on line:", parser.line_count + 1)
			eat(&parser)
			continue

		case '\n':
			eat(&parser)
			parser.line_count += 1
			continue

		case:
			log.debug(parser.data[parser.index:parser.index + 10])

			if parser.index + 1 > len(parser.data) {
				return Tokenizer_Error.None
			}
			log.error(
				"invalid token:",
				parser.data[parser.index],
				"on line:",
				parser.line_count + 1,
			)

			return .Invalid_Token
		}
	}

	return nil
}

main :: proc() {
	context.logger = log.create_console_logger()

	parse_data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(parse_data)

	err := parse(&parse_data)
	if err != nil {
		log.error(err)
		os.exit(1)
	}

	log.info("[SUCCESS]: Parsed Humdrum file successfully!")
}
