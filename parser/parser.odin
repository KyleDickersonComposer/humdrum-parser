package parser

import "core:fmt"
import "core:log"
import "core:strings"
import "core:unicode/utf8"

parse :: proc(parse_data: ^[]rune) -> Parse_Error {
	ref_records := make([dynamic]Reference_Record)
	defer delete(ref_records)

	tandem_interps := make([dynamic]Tandem_Interpretation)
	defer delete(tandem_interps)

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
	voice_index := 0
	parser.current = parser.data[0]

	note_creation_started := false

	for {
		clear(&eated)

		if parser.index >= len(parser.data) {
			return nil
		}

		switch parser.current {
		case '!':
			first_rune_of_line, repeat_count_of_rune := parse_repeating_rune(&parser) or_return

			if repeat_count_of_rune >= 3 {
				log.warn("only supporting reference records, line:", parser.line_count + 1)
				eat_until(&parser, &eated, '\n')
				continue
			}

			if repeat_count_of_rune <= 1 {
				log.warn("comments are ignored, line:", parser.line_count + 1)
				eat_until(&parser, &eated, '\n')
				continue
			}

			vrc_map := make(map[Valid_Record_Code]string)
			defer delete(vrc_map)

			create_valid_record_code_map(&vrc_map)

			record_code := make([dynamic]rune)
			defer delete(record_code)

			eat_until(&parser, &record_code, ':')

			to_string := utf8.runes_to_string(record_code[:])
			defer delete(to_string)

			eated_to_string := utf8.runes_to_string(eated[:])

			match_found := false
			for k, v in vrc_map {
				if to_string == v {
					eat_until(&parser, &eated, '\n')

					match_found = true
					append(&ref_records, Reference_Record{code = k, data = eated_to_string})
					continue
				}
			}

			if !match_found {
				code_to_string := utf8.runes_to_string(record_code[:])
				log.warn(
					"unsupported reference record code:",
					code_to_string,
					"on line:",
					parser.line_count + 1,
				)

				eat_until(&parser, &eated, '\n')
				continue
			}

		case '*':
			repeated_rune, repeat_count := parse_repeating_rune(&parser) or_return

			if parser.current == '-' {
				eat_until(&parser, &eated, '\n')
				continue
			}

			// matched exclusive interpretation
			if repeat_count == 1 {
				eat_until(&parser, &eated, '\t')

				eated_to_string := utf8.runes_to_string(eated[:])

				if eated_to_string != "kern" {
					log.error(
						"expected: kern",
						"got:",
						eated_to_string,
						"on line:",
						parser.line_count + 1,
					)
					return .Unsupported_Exclusive_Interpretation_Code
				}

				eat_until(&parser, &eated, '\n')
				continue
			}

			ti_code := make([dynamic]rune)
			eat_until(&parser, &ti_code, '\t') or_return

			ti_code_to_string := utf8.runes_to_string(ti_code[:])
			defer delete(ti_code_to_string)

			vtic_map := make(map[Valid_Tandem_Interpretation_Code]string)
			defer delete(vtic_map)

			create_valid_tandem_interpretation_code_map(&vtic_map)

			match_found := false
			for k, v in vtic_map {
				if v == ti_code_to_string {
					match_found = true

					append(
						&tandem_interps,
						Tandem_Interpretation {
							code = k,
							value = ti_code_to_string,
							voice_index = voice_index,
						},
					)

					eat_until(&parser, &eated, '\n') or_return
					continue
				}
			}

			// matched key
			if (len(ti_code) == 2 || len(ti_code) == 3) && is_note_name_rune(ti_code[0]) {
				// remove the ':' after the key declaration
				pop(&ti_code)

				out_buffer := ""
				key_table(ti_code[:], &out_buffer) or_return

				key = out_buffer

				eat_until(&parser, &eated, '\n')
				continue
			}

			// matched meter
			if len(ti_code) >= 3 && ti_code[0] == 'M' && ti_code[1] != 'M' {
				without_m := ti_code[1:]

				slice_index := 0
				for r, i in without_m {
					if r == '/' {
						slice_index = i
					}
				}

				meter.numerator = convert_runes_to_int(without_m[:slice_index]) or_return

				without_slash := without_m[slice_index + 1:]

				for r, i in without_slash {
					if r == '\t' {
						slice_index = i
					}
				}

				meter.denominator = convert_runes_to_int(without_m[slice_index + 1:]) or_return

				if meter.numerator == 6 || meter.numerator == 9 || meter.numerator == 12 {
					meter.type = "compound"
					eat_until(&parser, &eated, '\n')
					continue
				} else {
					meter.type = "simple"
					eat_until(&parser, &eated, '\n')
					continue
				}
			}

			if !match_found {
				log.warn(
					"unsupported tandem interpretation code:",
					ti_code_to_string,
					"on line:",
					parser.line_count + 1,
				)
				eat_until(&parser, &eated, '\n')
				continue
			}

		case '=':
			// double bar
			if (peek(&parser) or_return) == '=' {
				eat_until(&parser, &eated, '\n') or_return
				continue
			}

			// bar numbers
			eat_until(&parser, &eated, '\t') or_return

			if eated[0] == '\t' {
				log.error("couldn't parse bar_number:", eated)
				return .Malformed_Bar_Number
			}

			bar_number := convert_runes_to_int(eated[1:]) or_return

			append(&note_data_tokens, Bar{double_bar = false, key = key})

			eat_until(&parser, &eated, '\n') or_return
			continue

		// match first char of note declaration
		case '1', '2', '3', '4', '5', '6', '7', '8', '9', '[', '.':
			note: Note

			if parser.current == '.' {
				eat(&parser)
				continue
			}

			if parser.current == '[' {
				note.tie = 'i'
				eat(&parser)
			}

			note_creation_started = true
			is_lower_case_note_name := false

			duration_as_int := parse_int_runes(&parser) or_return

			dots: int
			if parser.current == '.' {
				_, dots_repeat_count := parse_repeating_rune(&parser) or_return
				dots = dots_repeat_count
			}

			if !is_note_name_rune(parser.current) {
				log.error(
					"malformed note_name:",
					parser.current,
					"on line:",
					parser.line_count + 1,
				)
				return .Malformed_Note
			}

			note_rune, note_repeat_count := parse_repeating_rune(&parser) or_return

			accid: string
			defer delete(accid)
			if is_accidental_rune(parser.current) {
				out_runes := make([dynamic]rune)
				length := parse_accidental(&parser, &out_runes) or_return
				to_string := utf8.runes_to_string(out_runes[:length])

				accid = to_string
			}

			if parser.current == 'X' {
				log.warn("hit courtesy accidental, ignoring")
				eat(&parser)
			}

			for n in LOWER_CASE_NOTE_NAMES {
				if note_rune == n {
					is_lower_case_note_name = true
					break
				}
			}

			if !is_lower_case_note_name do note_repeat_count *= -1

			if parser.current == 'L' {
				log.warn("hit beam_open token, ignoring ")
				eat(&parser)
			}

			if parser.current == 'J' {
				log.warn("hit beam_close token, ignoring ")
				eat(&parser)
			}

			// TODO: implement the fermata logic
			if parser.current == ';' {
				log.warn("ignoring fermatas for now!")
				eat(&parser)
			}

			note_name := ""
			to_runes := utf8.runes_to_string([]rune{note_rune})
			defer delete(to_runes)
			to_string := strings.to_upper(to_runes)
			defer delete(to_string)
			note_name = to_string

			full_note_name := fmt.aprintf("%v%v", note_name, accid)
			defer delete(full_note_name)

			note.note_name = full_note_name
			note.duration = duration_as_int
			note.octave = 4 + note_repeat_count
			note.voice_index = voice_index

			if !is_lower_case_note_name {
				note.octave -= 1
			}

			append(&note_data_tokens, note)

			if voice_index < 3 {
				eat_until(&parser, &eated, '\t')
			}
			continue

		case '\t':
			voice_index += 1
			eat(&parser)
			continue

		case '\n':
			eat(&parser)
			parser.line_count += 1
			voice_index = 0
			continue

		case ' ':
			eat(&parser)
			continue

		case '\r':
			eat(&parser)
			continue

		case utf8.RUNE_EOF:
			return nil
		}
	}

	return nil
}
