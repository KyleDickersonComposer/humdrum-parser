package build_ir

import "../parse_syntax"
import "../parser"
import "../tokenize"
import "../types"
import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

build_ir :: proc(tree: ^parse_syntax.Syntax_Tree) -> (
	json_struct: types.Music_IR_Json,
	err: parser.Parse_Error,
) {
	voices := make([dynamic]types.Voice)
	voice_index_to_voice_ID := make(map[int]string, 4)
	defer delete(voice_index_to_voice_ID)

	for i in 0 ..< 4 {
		voice_type := parser.voice_index_to_voice_type(i) or_return

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
			types.Voice {
				ID = transmute(string)buf,
				type = voice_type,
				voice_index_of_staff = i % 2,
				is_CF = false,
				is_bass = is_bass,
				is_editable = true,
			},
		)
	}

	staffs := make([dynamic]types.Staff)
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
			return json_struct, parser.Tokenizer_Error.Invalid_Staff_Count
		}

		append(
			&staffs,
			types.Staff {
				ID = transmute(string)buf,
				staff_index = i,
				clef = clef,
				voice_IDs = voice_IDs,
			},
		)
	}

	id := uuid.generate_v4()
	buf := make([]byte, 36)
	uuid.to_string_buffer(id, buf)
	staff_grps := make([dynamic]types.Staff_Grp)
	append(
		&staff_grps,
		types.Staff_Grp {
			ID = transmute(string)buf,
			staff_def_IDs = []string{staffs[0].ID, staffs[1].ID},
			parent_staff_grp_ID = "",
			bracket_style = "brace",
		},
	)

	artifacts := make([dynamic]types.Notation_Artifact)
	note_data_tokens := make([dynamic]types.Note)
	bar_data_tokens := make([dynamic]types.Layout)

	key := ""
	meter: types.Meter
	meta := types.Metadata{}
	current_bar := 0
	voice_index := 0
	timestamp_array := [4]f32{1, 1, 1, 1}

	for record in tree.records {
		switch record.kind {
		case .Exclusive_Interpretation:
			// Already handled, skip

		case .Comment:
			// Comments ignored

		case .Double_Bar:
			// Double bars not currently handled

		case .Tandem_Interpretation:
			tand := record.record.(parse_syntax.Record_Tandem_Interpretation)
			if tand.code == "key" {
				key = tand.value
			} else if tand.code == "M" {
				// Parse meter from value like "M4/4"
				meter_str := tand.value
				if strings.has_prefix(meter_str, "M") {
					meter_str = meter_str[1:]
				}
				parts := strings.split(meter_str, "/")
				defer delete(parts)
				if len(parts) == 2 {
					if len(parts[0]) > 0 && len(parts[1]) > 0 {
						meter.numerator = parser.convert_runes_to_int(utf8.string_to_runes(parts[0])) or_return
						meter.denominator = parser.convert_runes_to_int(utf8.string_to_runes(parts[1])) or_return
						if meter.numerator == 6 || meter.numerator == 9 || meter.numerator == 12 {
							meter.type = "compound"
						} else {
							meter.type = "simple"
						}
					}
				}
			}

		case .Reference:
			ref := record.record.(parse_syntax.Record_Reference)
			if ref.code == .Scholarly_Catalog_Number {
				meta.catalog_number = ref.data
			}
			if ref.code == .Publisher_Catalog_Number {
				meta.publisher_catalog_number = ref.data
			}

		case .Bar_Line:
			bar := record.record.(parse_syntax.Record_Bar_Line)
			has_changed := false
			if bar.bar_number == 1 && len(bar_data_tokens) == 0 {
				has_changed = true
			}

			append(
				&bar_data_tokens,
				types.Layout {
					bar_number = bar.bar_number,
					key = key,
					has_layout_changed = has_changed,
					staff_grp_IDs = []string{staff_grps[0].ID},
					meter = meter,
				},
			)

			current_bar += 1
			for &i in timestamp_array {
				i = 1
			}

		case .Data_Line:
			data_line := record.record.(parse_syntax.Record_Data_Line)

			if current_bar == 0 && len(bar_data_tokens) == 0 {
				append(
					&bar_data_tokens,
					types.Layout {
						bar_number = 0,
						has_layout_changed = true,
						key = key,
						meter = meter,
						staff_grp_IDs = []string{staff_grps[0].ID},
					},
				)
			}

			for voice_index in 0 ..< 4 {
				for note_token in data_line.voice_tokens[voice_index] {
					note: types.Note

					note.tie = ""
					if note_token.tie_start {
						note.tie = "i"
					}
					if note_token.tie_end {
						note.tie = "t"
					}

					duration_as_int := note_token.duration
					dots := note_token.dots

					note_name := note_token.note_name
					accid := note_token.accidental

					// Skip if note_name is empty or doesn't start with a valid note letter
					if note_name == "" {
						log.info("Skipping note token with empty note_name at bar", current_bar, "voice", voice_index)
						continue
					}
					
					// Check if first character is a valid note name
					note_name_runes := utf8.string_to_runes(note_name)
					defer delete(note_name_runes)
					if len(note_name_runes) == 0 || !parser.is_note_name_rune(note_name_runes[0]) {
						log.info("Skipping note token with invalid note_name:", note_name, "at bar", current_bar, "voice", voice_index)
						continue
					}

					corrected_accidental := ""
					if accid != "" {
						corrected_accidental = tokenize.convert_humdrum_accidentals_to_normal_accidentals(accid) or_return
					}

					note_id := uuid.generate_v4()
					buf := make([]byte, 36)
					uuid.to_string_buffer(note_id, buf)

					fermata_id := uuid.generate_v4()
					fermata_buf := make([]byte, 36)
					uuid.to_string_buffer(note_id, fermata_buf)

					fermata_staff_ID := ""
					if voice_index > 2 {
						fermata_staff_ID = staffs[1].ID
					} else {
						fermata_staff_ID = staffs[0].ID
					}

					if note_token.has_fermata {
						append(
							&artifacts,
							types.Fermata {
								type = "fermata",
								ID = transmute(string)fermata_buf,
								place = "above",
								bar_number = current_bar,
								staff = fermata_staff_ID,
								start_ID = transmute(string)buf,
							},
						)
					}

					note_repeat_count := note_token.note_repeat_count
					if !note_token.is_lower_case {
						note_repeat_count -= 1
					}

					staff_index := 0
					if voice_index > 2 {
						staff_index = 1
					}

					scale: [7]string
					parser.create_scale(&scale, key)

					duration_as_float := parser.get_duration_as_float(duration_as_int) or_return

					full_note_name := fmt.aprintf("%v%v", note_name, accid)
					defer delete(full_note_name)

					note.ID = transmute(string)buf
					note.duration = parser.get_duration_as_string(duration_as_int) or_return
					note.is_rest = false
					note.input_octave = 4 + note_repeat_count
					note.accidental = corrected_accidental
					note.input_scale = key
					note.dots = dots
					note.voice_ID = voice_index_to_voice_ID[voice_index]
					note.bar_number = current_bar
					note.staff_ID = staffs[staff_index].ID
					note.scale_degree = parser.get_scale_degree(full_note_name, &scale) or_return

					if note.dots == 0 {
						note.timestamp = timestamp_array[voice_index]
						timestamp_array[voice_index] += duration_as_float
					} else {
						account_for_the_dots := f32(note.dots) * (0.5 * duration_as_float)
						note.timestamp = timestamp_array[voice_index]
						timestamp_array[voice_index] += duration_as_float + account_for_the_dots
					}

					append(&note_data_tokens, note)
				}
			}
		}
	}

	json_struct.voices = voices[:]
	json_struct.notes = note_data_tokens[:]
	json_struct.staffs = staffs[:]
	json_struct.layouts = bar_data_tokens[:]
	json_struct.artifacts = artifacts[:]
	json_struct.staff_grps = staff_grps[:]

	if len(json_struct.layouts) > 0 {
		json_struct.layouts[len(json_struct.layouts) - 1].right_barline_type = "end"
	}

	for &n in json_struct.notes {
		for v in json_struct.voices {
			if n.voice_ID == v.ID {
				if v.voice_index_of_staff == 0 {
					n.stem_dir = "down"
				} else {
					n.stem_dir = "up"
				}
			}
		}
	}

	json_struct.metadata = meta

	opts := json.Marshal_Options {
		pretty = true,
	}

	json_music_IR, json_err := json.marshal(json_struct, opts)
	if json_err != nil {
		log.error(json_err)
		return json_struct, parser.Conversion_Error.Json_Serialization_Failed
	}

	file_name := fmt.aprintf(
		"tmp/chorale-%v-%v",
		meta.publisher_catalog_number,
		meta.catalog_number,
	)
	defer delete(file_name)

	write_file_err := os.write_entire_file_or_err(file_name, json_music_IR)
	if write_file_err != nil {
		log.error(write_file_err)
		return json_struct, parser.Conversion_Error.Failed_To_Write_File
	}

	return json_struct, nil
}

