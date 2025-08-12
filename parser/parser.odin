package parser

import t "../types"
import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

parse :: proc(json_struct: ^t.Music_IR_Json, parse_data: ^[]rune) -> Parse_Error {
	ref_records := make([dynamic]Reference_Record)

	tandem_interps := make([dynamic]Tandem_Interpretation)

	voices := make([dynamic]t.Voice)

	// TODO: init the voices and build map of IDs

	voice_index_to_voice_ID := make(map[int]string, 4)
	defer delete(voice_index_to_voice_ID)

	for i in 0 ..< 4 {
		voice_type := voice_index_to_voice_type(i) or_return

		id := uuid.generate_v4()
		buf := make([]byte, 36)
		uuid.to_string_buffer(id, buf)

		voice_index_to_voice_ID[i] = transmute(string)buf

		is_bass := false

		if voice_type == "bass" {
			is_bass = true
		}

		append(
			&voices,
			t.Voice {
				ID = transmute(string)buf,
				type = voice_type,
				voice_index_of_staff = i,
				is_CF = false,
				is_bass = true,
				is_editable = true,
			},
		)
	}

	staffs := make([dynamic]t.Staff)
	defer delete(staffs)

	// TODO: init the staffs and build map of IDs
	for i in 0 ..< 2 {
		id := uuid.generate_v4()
		buf := make([]byte, 36)
		uuid.to_string_buffer(id, buf)

		clef := "treble"

		if i == 0 {
			clef = "bass"
		}

		voice_IDs: []string
		if i == 0 {
			voice_IDs = []string{voice_index_to_voice_ID[0], voice_index_to_voice_ID[1]}
		} else if i == 1 {
			voice_IDs = []string{voice_index_to_voice_ID[2], voice_index_to_voice_ID[3]}
		} else {
			log.error("only supports two staff Bach Chorales")
			return .Invalid_Staff_Count
		}

		append(
			&staffs,
			t.Staff {
				ID = transmute(string)buf,
				staff_index = i,
				clef = clef,
				voice_IDs = voice_IDs,
			},
		)

	}

	artifacts := make([dynamic]t.Notation_Artifact)
	defer delete(artifacts)

	note_data_tokens := make([dynamic]t.Note)
	defer delete(note_data_tokens)

	bar_data_tokens := make([dynamic]t.Layout)
	defer delete(bar_data_tokens)

	eated := make([dynamic]rune)
	defer delete(eated)

	key := ""
	meter: t.Meter

	meta := t.Metadata{}

	current_bar := 0

	parser: Parser
	parser.data = parse_data^
	parser.index = 0
	voice_index := 0
	parser.current = parser.data[0]

	timestamp_array := [4]f32{1, 1, 1, 1}

	note_creation_started := false
	for {
		clear(&eated)

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

			eat_until(&parser, &eated, ':')

			match_found := false
			for k, v in vrc_map {
				if to_string == v {
					eat(&parser)
					eat(&parser)
					clear(&eated)
					eat_until(&parser, &eated, '\n')

					eated_to_string := utf8.runes_to_string(eated[:])

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

			has_changed := false
			if bar_number == 1 && len(bar_data_tokens) == 0 {
				has_changed = true
			}

			append(
				&bar_data_tokens,
				t.Layout {
					bar_number = bar_number,
					key = key,
					has_layout_changed = has_changed,
					meter = meter,
				},
			)

			current_bar += 1

			// NOTE: need to reset timestamp_array every newline
			for &i in timestamp_array {
				i = 1
			}

			eat_until(&parser, &eated, '\n') or_return
			continue

		// match first char of note declaration
		case '1', '2', '3', '4', '5', '6', '7', '8', '9', '[', '.':
			note: t.Note

			if parser.current == '.' {
				eat(&parser)
				continue
			}

			if current_bar == 0 {
				append(
					&bar_data_tokens,
					t.Layout{bar_number = 0, has_layout_changed = true, key = key, meter = meter},
				)
			}

			if parser.current == '[' {
				note.tie = "i"
				eat(&parser)
			}

			note_creation_started = true
			is_lower_case_note_name := false

			duration_as_int := parse_int_runes(&parser) or_return

			dots: int
			if parser.current == '.' {
				_, dots_repeat_count := parse_repeating_rune(&parser) or_return
				dots = dots_repeat_count + 1
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

			if parser.current == ']' {
				note.tie = "t"
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

			note_id := uuid.generate_v4()
			buf := make([]byte, 36)
			uuid.to_string_buffer(note_id, buf)

			duration_to_string := fmt.aprintf("%v", duration_as_int)


			if !is_lower_case_note_name {
				note_repeat_count -= 1
			}

			staff_index := 0
			if voice_index > 2 {
				staff_index = 1
			}

			scale: [7]string
			create_scale(&scale, key)

			duration_as_float := get_duration_as_float(duration_as_int) or_return

			//done
			note.ID = transmute(string)buf
			note.duration = duration_to_string
			note.is_rest = false
			note.input_octave = 4 + note_repeat_count
			note.accidental = accid
			note.input_scale = key
			note.dots = dots
			note.voice_ID = voice_index_to_voice_ID[voice_index]
			note.bar_number = current_bar
			note.staff_ID = staffs[staff_index].ID
			note.scale_degree = get_scale_degree(full_note_name, &scale) or_return


			if note.dots == 0 {
				note.timestamp = timestamp_array[voice_index]
				timestamp_array[voice_index] += duration_as_float
			} else {
				account_for_the_dots := f32(note.dots) * (0.5 * duration_as_float)
				note.timestamp = timestamp_array[voice_index]

				timestamp_array[voice_index] += duration_as_float + account_for_the_dots
			}


			append(&note_data_tokens, note)

			if voice_index < 3 {
				eat_until(&parser, &eated, '\t')
			}
			continue

		case 'a' ..< 'Z':
			log.error(
				"found an alphabetical character at the beginning of line:",
				parser.line_count,
				"at rune index:",
				parser.index,
				"invalid_line_start rune for 'kern', and likely to be an error of some kind",
			)
			return .Invalid_Token

		case '\t':
			voice_index += 1
			eat(&parser)
			continue

		case '\n':
			eat(&parser)
			parser.line_count += 1
			voice_index = 0
			continue

		case '\r':
			eat(&parser)

			continue

		case utf8.RUNE_EOF:
			json_struct.voices = voices[:]
			json_struct.notes = note_data_tokens[:]
			json_struct.staffs = staffs[:]
			json_struct.layouts = bar_data_tokens[:]
			json_struct.artifacts = artifacts[:]

			for rec in ref_records {
				if rec.code == .Scholarly_Catalog_Number {
					meta.catalog_number = rec.data
				}

				if rec.code == .Publisher_Catalog_Number {
					meta.publisher_catalog_number = rec.data
				}
			}

			json_struct.metadata = meta

			opts := json.Marshal_Options {
				pretty = true,
			}

			json_music_IR, err := json.marshal(json_struct^, opts)
			if err != nil {
				log.error(err)
				return .Json_Serialization_Failed
			}

			file_name := fmt.aprintf(
				"tmp/chorale-%v-%v",
				meta.publisher_catalog_number,
				meta.catalog_number,
			)
			defer delete(file_name)


			write_file_err := os.write_entire_file_or_err(file_name, json_music_IR)

			return nil
		}
	}

	return nil
}
