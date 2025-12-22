package parsing

import "../types"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

// Music theory utility functions used by build_ir and other packages
// These functions return types.Shared_Error so they can return errors from any package

convert_runes_to_int :: proc(runes: []rune) -> (int, types.Shared_Error) {
	if len(runes) == 0 {
		log.error("convert_runes_to_int: empty rune array")
		return 0, types.Parsing_Error.Failed_To_Convert_To_Integer
	}

	to_string := utf8.runes_to_string(runes[:])
	defer delete(to_string)

	if len(to_string) == 0 {
		log.error("convert_runes_to_int: empty string from runes")
		return 0, types.Parsing_Error.Failed_To_Convert_To_Integer
	}

	value, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("convert_runes_to_int: failed to parse:", to_string, "from runes:", runes)
		return 0, types.Parsing_Error.Failed_To_Convert_To_Integer
	}

	return value, nil
}

convert_key_signature_to_key_name :: proc(key_sig: string) -> (string, types.Shared_Error) {
	// Remove brackets if present
	cleaned := key_sig
	if strings.has_prefix(cleaned, "[") && strings.has_suffix(cleaned, "]") {
		cleaned = cleaned[1:len(cleaned) - 1]
	}

	// Empty means C major
	if len(cleaned) == 0 {
		return "C", nil
	}

	// Count sharps and flats
	sharps := 0
	flats := 0

	runes := utf8.string_to_runes(cleaned)
	defer delete(runes)

	i := 0
	for i < len(runes) {
		if i + 1 < len(runes) && runes[i + 1] == '#' {
			sharps += 1
			i += 2 // Skip note and #
		} else if i + 1 < len(runes) && runes[i + 1] == '-' {
			flats += 1
			i += 2 // Skip note and -
		} else {
			i += 1
		}
	}

	// Convert to key name based on number of sharps/flats
	if sharps > 0 && flats == 0 {
		switch sharps {
		case 1:
			return "G", nil
		case 2:
			return "D", nil
		case 3:
			return "A", nil
		case 4:
			return "E", nil
		case 5:
			return "B", nil
		case 6:
			return "F#", nil
		case 7:
			return "C#", nil
		}
	} else if flats > 0 && sharps == 0 {
		switch flats {
		case 1:
			return "F", nil
		case 2:
			return "Bb", nil
		case 3:
			return "Eb", nil
		case 4:
			return "Ab", nil
		case 5:
			return "Db", nil
		case 6:
			return "Gb", nil
		case 7:
			return "Cb", nil
		}
	}

	log.error("unsupported key signature:", key_sig, "sharps:", sharps, "flats:", flats)
	return "C", types.Parsing_Error.Key_Lookup_Failed
}

voice_index_to_voice_type :: proc(index: int) -> (string, types.Shared_Error) {
	switch index {
	case 0:
		return "bass", nil
	case 1:
		return "tenor", nil
	case 2:
		return "alto", nil
	case 3:
		return "soprano", nil
	case:
		return "", types.Parsing_Error.Malformed_Note
	}
}

create_scale :: proc(s: ^[7]string, scale: string) -> types.Shared_Error {
	switch scale {
	case "C":
		s^ = C_SCALE
		return nil
	case "D":
		s^ = D_SCALE
		return nil
	case "E":
		s^ = E_SCALE
		return nil
	case "F":
		s^ = F_SCALE
		return nil
	case "G":
		s^ = G_SCALE
		return nil
	case "A":
		s^ = A_SCALE
		return nil
	case "B":
		s^ = B_SCALE
		return nil
	case "C#":
		s^ = C_SHARP_SCALE
		return nil
	case "F#":
		s^ = F_SHARP_SCALE
		return nil
	case "Cb":
		s^ = C_FLAT_SCALE
		return nil
	case "Db":
		s^ = D_FLAT_SCALE
		return nil
	case "Eb":
		s^ = E_FLAT_SCALE
		return nil
	case "Gb":
		s^ = G_FLAT_SCALE
		return nil
	case "Ab":
		s^ = A_FLAT_SCALE
		return nil
	case "Bb":
		s^ = B_FLAT_SCALE
		return nil
	case "Am":
		s^ = A_MINOR_SCALE
		return nil
	case "Bm":
		s^ = B_MINOR_SCALE
		return nil
	case "Cm":
		s^ = C_MINOR_SCALE
		return nil
	case "Dm":
		s^ = D_MINOR_SCALE
		return nil
	case "Em":
		s^ = E_MINOR_SCALE
		return nil
	case "Fm":
		s^ = F_MINOR_SCALE
		return nil
	case "Gm":
		s^ = G_MINOR_SCALE
		return nil
	case "F#m":
		s^ = F_SHARP_MINOR_SCALE
		return nil
	}

	log.error("invalid scale:", scale)
	return types.Parsing_Error.Key_Lookup_Failed
}

get_scale_degree :: proc(note_name: string, scale: ^[7]string) -> (int, types.Shared_Error) {
	// Extract base note name (first rune, ignoring accidentals)
	note_name_rune: rune
	note_name_runes := utf8.string_to_runes(note_name)
	defer delete(note_name_runes)

	if len(note_name_runes) == 0 {
		log.error("get_scale_degree: empty note_name string")
		return 0, types.Parsing_Error.Key_Lookup_Failed
	}

	note_name_rune = note_name_runes[0]

	// Check if first rune is a valid note name (A-G or a-g)
	if !is_note_name_rune(note_name_rune) {
		log.error(
			"get_scale_degree: first rune of note_name is not a valid note name:",
			note_name_rune,
			"from string:",
			note_name,
		)
		return 0, types.Parsing_Error.Key_Lookup_Failed
	}

	// Normalize to uppercase
	if note_name_rune >= 'a' && note_name_rune <= 'g' {
		note_name_rune = rune(int(note_name_rune) - 32) // Convert to uppercase
	}

	scale_degree_index_one_based := 1

	loop_index := 0
	for {
		scale_note := scale[loop_index % 7]
		scale_note_runes := utf8.string_to_runes(scale_note)

		if len(scale_note_runes) == 0 {
			delete(scale_note_runes)
			log.error("get_scale_degree: empty scale note at index", loop_index % 7)
			return 0, types.Parsing_Error.Key_Lookup_Failed
		}

		compare_rune := scale_note_runes[0]
		// Normalize to uppercase
		if compare_rune >= 'a' && compare_rune <= 'g' {
			compare_rune = rune(int(compare_rune) - 32) // Convert to uppercase
		}

		delete(scale_note_runes)

		if compare_rune == note_name_rune {
			return scale_degree_index_one_based, nil
		}

		scale_degree_index_one_based += 1
		loop_index += 1

		if loop_index > 16 {
			log.error(
				"should have found scale_degree in scale:",
				scale,
				"based on note_name",
				note_name,
				"within 16 iterations.",
			)

			return 0, types.Parsing_Error.Key_Lookup_Failed
		}
	}

	return 0, types.Parsing_Error.Key_Lookup_Failed
}

get_duration_as_float :: proc(duration: int) -> (f32, types.Shared_Error) {
	switch duration {
	case 1:
		return 4, nil
	case 2:
		return 2, nil
	case 4:
		return 1, nil
	case 8:
		return 0.5, nil
	case 16:
		return 0.25, nil
	case 32:
		return 0.125, nil

	case:
		log.error("expected valid duration, got:", duration)
		return 0, types.Parsing_Error.Failed_To_Convert_Duration
	}

	return 0, types.Parsing_Error.Failed_To_Convert_Duration
}

get_duration_as_string :: proc(duration: int) -> (string, types.Shared_Error) {
	switch duration {
	case 1:
		return "whole", nil
	case 2:
		return "half", nil
	case 4:
		return "quarter", nil
	case 8:
		return "eighth", nil
	case 16:
		return "sixteenth", nil
	case 32:
		return "thirty-second", nil
	case:
		log.error("expected valid duration, got:", duration)
		return "", types.Parsing_Error.Failed_To_Convert_Duration
	}
	return "", types.Parsing_Error.Failed_To_Convert_Duration
}

convert_humdrum_accidentals_to_normal_accidentals :: proc(
	accid: string,
) -> (
	string,
	types.Shared_Error,
) {
	switch accid {
	case "n":
		return "n", nil
	case "#":
		return "#", nil
	case "##":
		return "##", nil
	case "-":
		return "b", nil
	case "--":
		return "bb", nil
	case:
		log.error("expected valid humdrum accidental, got:", accid)
		return "", types.Parsing_Error.Key_Lookup_Failed
	}

	return "", types.Parsing_Error.Key_Lookup_Failed
}
