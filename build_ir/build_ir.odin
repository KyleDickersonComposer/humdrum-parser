package build_ir

import "../parsing"
import "../types"
import "core:encoding/uuid"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:unicode/utf8"

build_ir :: proc(
	tree: ^types.Syntax_Tree,
) -> (
	json_struct: types.Music_IR_Json,
	err: types.Shared_Error,
) {
	// Main arena is set in context.allocator (from main) - use for persistent data
	// Scratch arena is in context.temp_allocator - use for temporary allocations

	// Temporary buffer uses scratch allocator
	alloc_uuid_string :: proc() -> string {
		id := uuid.generate_v4()
		buf := make([]byte, 36, context.temp_allocator)
		uuid.to_string_buffer(id, buf)
		return strings.clone(transmute(string)buf) // Clone to main arena
	}

	voices := make([dynamic]types.Voice)

	// Map uses scratch allocator - temporary lookup, arena handles cleanup
	voice_index_to_voice_ID := make(map[int]string, 4, context.temp_allocator)

	for i in 0 ..< 4 {
		voice_type, parse_err := parsing.voice_index_to_voice_type(i)
		if parse_err != nil {
			return json_struct, parse_err
		}

		voice_id := alloc_uuid_string()
		voice_index_to_voice_ID[i] = voice_id

		is_bass := false
		if voice_type == "bass" {
			is_bass = true
		}

		append(
			&voices,
			types.Voice {
				ID = voice_id,
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
		clef := strings.clone("treble")
		if i == 0 {
			clef = strings.clone("bass")
		}

		voice_IDs := make([]string, 2)
		if i == 0 {
			voice_IDs[0] = voice_index_to_voice_ID[0]
			voice_IDs[1] = voice_index_to_voice_ID[1]
		} else if i == 1 {
			voice_IDs[0] = voice_index_to_voice_ID[2]
			voice_IDs[1] = voice_index_to_voice_ID[3]
		} else {
			log.error("only supports two staff Bach Chorales")
			return json_struct, types.Build_IR_Error.Unsupported_Staff_Count
		}

		staff_id := alloc_uuid_string()

		append(
			&staffs,
			types.Staff{ID = staff_id, staff_index = i, clef = clef, voice_IDs = voice_IDs},
		)
	}

	staff_grp_id := alloc_uuid_string()
	staff_grps := make([dynamic]types.Staff_Grp)
	staff_def_IDs := make([]string, 2)
	staff_def_IDs[0] = staffs[0].ID
	staff_def_IDs[1] = staffs[1].ID
	append(
		&staff_grps,
		types.Staff_Grp {
			ID = staff_grp_id,
			staff_def_IDs = staff_def_IDs,
			parent_staff_grp_ID = "",
			bracket_style = strings.clone("brace"),
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
			tand := record.record.(types.Record_Tandem_Interpretation)
			if tand.code == "key" {
				if len(tand.value) > 0 {
					// Check if it's key signature notation (e.g., "[f#]") or key name (e.g., "G:")
					if strings.has_prefix(tand.value, "[") {
						// Convert key signature to key name
						key_name, key_err := parsing.convert_key_signature_to_key_name(tand.value)
						if key_err != nil {
							return json_struct, key_err
						}
						key = strings.clone(key_name)
					} else {
						// Already a key name, use as-is
						key = strings.clone(tand.value)
					}
				}
			} else if tand.code == "Meter" {
				// Parse meter from value like "4/4" (already parsed from "M4/4")
				meter_str := tand.value
				parts := strings.split(meter_str, "/", context.temp_allocator)
				// No delete needed - scratch arena handles cleanup
				if len(parts) == 2 {
					if len(parts[0]) > 0 && len(parts[1]) > 0 {
						numerator, num_err := parsing.convert_runes_to_int(
							utf8.string_to_runes(parts[0]),
						)
						if num_err != nil {
							return json_struct, num_err
						}
						meter.numerator = numerator

						denominator, den_err := parsing.convert_runes_to_int(
							utf8.string_to_runes(parts[1]),
						)
						if den_err != nil {
							return json_struct, den_err
						}
						meter.denominator = denominator
						if meter.numerator == 6 || meter.numerator == 9 || meter.numerator == 12 {
							meter.type = strings.clone("compound")
						} else {
							meter.type = strings.clone("simple")
						}
					}
				}
			}

		case .Reference:
			ref := record.record.(types.Record_Reference)
			if ref.code == .Scholarly_Catalog_Number {
				meta.catalog_number = ref.data
			}
			if ref.code == .Publisher_Catalog_Number {
				meta.publisher_catalog_number = ref.data
			}

		case .Bar_Line:
			bar := record.record.(types.Record_Bar_Line)
			has_changed := false
			if bar.bar_number == 1 && len(bar_data_tokens) == 0 {
				has_changed = true
			}

			// If first barline is =1 and we have bar 0 notes, update bar 0 meter to match bar 1
			// (Notes before the first barline are always a pickup measure in bar 0)
			if bar.bar_number == 1 &&
			   len(bar_data_tokens) > 0 &&
			   bar_data_tokens[0].bar_number == 0 {
					// Real pickup - update bar 0 meter to match bar 1 (same meter for pickup and bar 1)
					bar_data_tokens[0].meter = meter
			}

			staff_grp_IDs := make([]string, 1)
			staff_grp_IDs[0] = staff_grps[0].ID
			append(
				&bar_data_tokens,
				types.Layout {
					bar_number = bar.bar_number,
					key = key,
					has_layout_changed = has_changed,
					staff_grp_IDs = staff_grp_IDs,
					meter = meter,
				},
			)

			// Set current_bar to the bar number from the bar line (ground truth)
			current_bar = bar.bar_number
			for &i in timestamp_array {
				i = 1
			}

		case .Data_Line:
			data_line := record.record.(types.Record_Data_Line)

			if current_bar == 0 && len(bar_data_tokens) == 0 {
				// Meter should already be set from tandem interpretation before data lines
				// If not set, we'll update bar 0's meter when we hit bar 1
				staff_grp_IDs := make([]string, 1)
				staff_grp_IDs[0] = staff_grps[0].ID
				append(
					&bar_data_tokens,
					types.Layout {
						bar_number         = 0,
						has_layout_changed = true,
						key                = key,
						meter              = meter, // Same meter as bar 1 (will be updated if not set yet)
						staff_grp_IDs      = staff_grp_IDs,
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

					// Handle rest tokens (empty note_name indicates a rest)
					is_rest := note_name == ""
					
					corrected_accidental := ""
					
					if !is_rest {

						// Skip if note_name doesn't start with a valid note letter
						// Check if first character is a valid note name
						note_name_runes := utf8.string_to_runes(note_name)
						// No delete needed - scratch arena handles cleanup
						if len(note_name_runes) == 0 ||
						   !parsing.is_note_name_rune(note_name_runes[0]) {
							log.info(
								"Skipping note token with invalid note_name:",
								note_name,
								"at bar",
								current_bar,
								"voice",
								voice_index,
							)
							continue
						}

						// Get scale first to check for implicit naturals
						scale: [7]string
						scale_err := parsing.create_scale(&scale, key)
						if scale_err != nil {
							return json_struct, scale_err
						}

						if accid != "" {
							// Explicit accidental in Humdrum - convert it
							corrected, acc_err :=
								parsing.convert_humdrum_accidentals_to_normal_accidentals(accid)
							if acc_err != nil {
								return json_struct, acc_err
							}
							corrected_accidental = corrected
						} else {
							// No explicit accidental in Humdrum - check if scale note has accidental
							// If scale note has accidental, Humdrum is using implicit natural
							temp_note_name_for_scale_lookup := fmt.aprintf("%v", note_name, allocator = context.temp_allocator)
							temp_scale_degree, temp_scale_deg_err := parsing.get_scale_degree(temp_note_name_for_scale_lookup, &scale)
							if temp_scale_deg_err == nil {
								// Check what note is at this scale degree
								scale_note_at_degree := scale[(temp_scale_degree - 1) % 7]
								scale_note_runes := utf8.string_to_runes(scale_note_at_degree)
								defer delete(scale_note_runes)
								
								// If scale note has an accidental (length > 1), and Humdrum has no accidental,
								// it's an implicit natural
								if len(scale_note_runes) > 1 {
									// Scale note has accidental (e.g., "F#"), Humdrum just has "F"
									// This means they want F natural (implicit natural)
									corrected_accidental = "n"
								}
							}
						}
					}

					note_id := alloc_uuid_string()

					fermata_staff_ID := ""
					if voice_index > 2 {
						fermata_staff_ID = staffs[1].ID
					} else {
						fermata_staff_ID = staffs[0].ID
					}

					if note_token.has_fermata {
						fermata_id := alloc_uuid_string()
						append(
							&artifacts,
							types.Fermata {
								type = "fermata",
								ID = fermata_id,
								place = "above",
								bar_number = current_bar,
								staff = fermata_staff_ID,
								start_ID = note_id,
							},
						)
					}

					note_repeat_count := note_token.note_repeat_count
					// Note: note_repeat_count is already adjusted for case in the tokenizer
					// (uppercase notes have negative repeat_count, and 1 is subtracted)

					staff_index := 0
					if voice_index > 2 {
						staff_index = 1
					}

					duration_as_float, dur_err := parsing.get_duration_as_float(duration_as_int)
					if dur_err != nil {
						return json_struct, dur_err
					}

					note.ID = note_id
					duration_str, dur_str_err := parsing.get_duration_as_string(duration_as_int)
					if dur_str_err != nil {
						return json_struct, dur_str_err
					}
					note.duration = duration_str
					note.is_rest = is_rest
					note.dots = dots
					note.voice_ID = voice_index_to_voice_ID[voice_index]
					note.bar_number = current_bar
					note.staff_ID = staffs[staff_index].ID
					
					if !is_rest {
						full_note_name := fmt.aprintf(
							"%v%v",
							note_name,
							accid,
							allocator = context.temp_allocator,
						)
						note.input_octave = 4 + note_repeat_count
						note.accidental = corrected_accidental
						note.input_scale = key
						
						// Get scale for scale degree calculation
						scale: [7]string
						scale_err := parsing.create_scale(&scale, key)
						if scale_err != nil {
							return json_struct, scale_err
						}
						scale_degree, scale_deg_err := parsing.get_scale_degree(full_note_name, &scale)
						if scale_deg_err != nil {
							return json_struct, scale_deg_err
						}
						note.scale_degree = scale_degree
					} else {
						// For rests, set default values
						note.input_octave = 4
						note.accidental = ""
						note.input_scale = key
						note.scale_degree = 0 // Rests don't have scale degrees
					}

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

	return json_struct, nil
}
