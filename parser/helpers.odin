package parser

import "core:fmt"
import "core:log"
import "core:strconv"
import "core:unicode/utf8"

eat :: proc(p: ^Parser) {
	p.index += 1
	if p.index >= len(p.data) {
		p.current = utf8.RUNE_EOF
		return
	}
	p.current = p.data[p.index]
}

eat_until :: proc(p: ^Parser, rune_buffer: ^[dynamic]rune, needle: rune) -> Parse_Error {
	for {
		if p.index >= len(p.data) {
			return nil
		}

		if p.data[p.index] == '\n' {
			return nil
		}

		if p.current == needle {
			return nil
		} else {
			append(rune_buffer, p.current)
			eat(p)
		}

	}

	return nil
}

peek :: proc(p: ^Parser, offset: int = 1) -> (rune, Parse_Error) {
	pos := p.index + offset
	if pos < 0 {
		return '0', .Broke_Array_Bounds
	}
	if pos >= len(p.data) {
		return utf8.RUNE_EOF, nil
	}

	return p.data[pos], nil
}

match_string :: proc(p: ^Parser, needle: string) -> (pred: bool, err: Parse_Error) {
	str_len := len(needle)
	peek_runes := make([]rune, str_len)
	defer delete(peek_runes)

	for i in 0 ..< str_len {
		if p.index < 0 || p.index > len(p.data) {
			return false, .Broke_Array_Bounds
		}
		if p.index + i >= len(p.data) {
			return false, nil
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

convert_runes_to_int :: proc(runes: []rune) -> (int, Conversion_Error) {
	if len(runes) == 0 {
		log.error("convert_runes_to_int: empty rune array")
		return 0, .Failed_To_Convert_To_Integer
	}

	to_string := utf8.runes_to_string(runes[:])
	defer delete(to_string)

	if len(to_string) == 0 {
		log.error("convert_runes_to_int: empty string from runes")
		return 0, .Failed_To_Convert_To_Integer
	}

	value, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("convert_runes_to_int: failed to parse:", to_string, "from runes:", runes)
		return 0, .Failed_To_Convert_To_Integer
	}

	return value, nil
}

key_table :: proc(note_name: []rune, out: ^string) -> (err: Parse_Error) {
	if !is_note_name_rune(note_name[0]) {
		log.error("expected first rune of :", note_name, "to be a valid note_name")
		return .Malformed_Note
	}

	rest := note_name[1:]
	to_string := utf8.runes_to_string(rest)
	defer delete(to_string)

	if len(rest) > 0 {
		match_accidental(to_string) or_return
	}

	switch note_name[0] {
	case 'a', 'C':
		if len(rest) > 0 {
			out^ = fmt.aprintf("%v%v", 'C', rest)
			return nil
		}

		out^ = "C"
		return nil

	case:
		catted := fmt.aprintf("%v%v", note_name[0], rest)
		log.error("unsupported key:", catted)
		return .Key_Lookup_Failed
	}

	return .Key_Lookup_Failed
}

match_accidental :: proc(possible_accidental: string) -> (string, Parse_Error) {
	for acc in ACCIDENTAL {
		if possible_accidental == acc {
			return acc, nil
		}
	}

	log.error("expected accidental to match a valid accidental, got:", possible_accidental)
	return "", .Failed_To_Match_Accidental
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
	if number >= '0' && number <= '9' {
		return true
	}

	return false
}

is_accidental_rune :: proc(the_accidental: rune) -> bool {
	for check_match in ACCIDENTAL_RUNE {
		if the_accidental == check_match {
			return true
		}
	}
	return false
}

is_accidental_string :: proc(accidental_string: string) -> bool {
	for accid in ACCIDENTAL {
		if accid == accidental_string {
			return true
		}
	}
	return false
}

parse_repeating_rune :: proc(
	p: ^Parser,
) -> (
	repeated_rune: rune,
	repeat_count: int,
	err: Parse_Error,
) {
	rune_to_match := p.current
	eat(p)
	count := 0

	if p.current != rune_to_match {
		return rune_to_match, 0, nil
	}

	for i in 0 ..< 8 {
		if p.current != rune_to_match {
			return rune_to_match, count, nil
		}
		eat(p)
		count += 1
	}

	log.error("ate more than 7 repeating runes")
	return '0', 0, .Failed_To_Parse_Repeating_Rune
}

parse_int_runes :: proc(p: ^Parser) -> (value: int, err: Parse_Error) {
	integer_runes: [3]rune
	integer_runes[0] = p.current
	eat(p)
	for i in 1 ..< 3 {
		if p.current >= '0' && p.current <= '9' {
			integer_runes[i] = p.current
			eat(p)
		}
	}

	to_string := utf8.runes_to_string(integer_runes[:])
	defer delete(to_string)

	to_int, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("parse_int_runes: failed to parse:", to_string)
		return 0, .Failed_To_Convert_To_Integer
	}

	return to_int, nil
}

parse_accidental :: proc(
	p: ^Parser,
	out_runes: ^[dynamic]rune,
) -> (
	length: int,
	err: Parse_Error,
) {
	append(out_runes, p.current)
	eat(p)

	count := 1

	for i in 1 ..< 4 {
		if p.current != out_runes[0] {
			return count, nil
		}

		if is_accidental_rune(p.current) && p.current == out_runes[0] {
			count += 1
			append(out_runes, p.current)
		}
	}

	to_string := utf8.runes_to_string(out_runes[:])
	defer delete(to_string)

	log.error("expected valid accidental, got:", out_runes)
	return 0, .Malformed_Accidental
}

voice_index_to_voice_type :: proc(index: int) -> (string, Parse_Error) {
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
		return "", .Invalid_Voice_Index
	}
}

create_scale :: proc(s: ^[7]string, scale: string) -> Parse_Error {
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
	}

	log.error("invalid scale:", scale)
	return .Key_Lookup_Failed
}

get_scale_degree :: proc(note_name: string, scale: ^[7]string) -> (int, Parse_Error) {
	// Extract base note name (first rune, ignoring accidentals)
	note_name_rune: rune
	note_name_runes := utf8.string_to_runes(note_name)
	defer delete(note_name_runes)
	
	if len(note_name_runes) == 0 {
		log.error("get_scale_degree: empty note_name string")
		return 0, .Failed_To_Determine_Scale_Degree
	}
	
	note_name_rune = note_name_runes[0]
	
	// Check if first rune is a valid note name (A-G or a-g)
	if !is_note_name_rune(note_name_rune) {
		log.error("get_scale_degree: first rune of note_name is not a valid note name:", note_name_rune, "from string:", note_name)
		return 0, .Failed_To_Determine_Scale_Degree
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
			return 0, .Failed_To_Determine_Scale_Degree
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

			return 0, .Failed_To_Determine_Scale_Degree
		}
	}

	return 0, .Failed_To_Determine_Scale_Degree
}

get_duration_as_float :: proc(duration: int) -> (f32, Parse_Error) {
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

	case:
		log.error("expected valid duration, got:", duration)
		return 0, .Failed_To_Convert_Duration
	}

	return 0, .Failed_To_Convert_Duration
}

get_duration_as_string :: proc(duration: int) -> (string, Parse_Error) {
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
	case:
		log.error("expected valid duration, got:", duration)
		return "", .Failed_To_Convert_Duration
	}
	return "", .Failed_To_Convert_Duration
}

convert_humdrum_accidentals_to_normal_accidentals :: proc(accid: string) -> (string, Parse_Error) {
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
		return "", .Failed_To_Match_Accidental
	}

	return "", .Failed_To_Match_Accidental
}
