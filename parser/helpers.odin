package parser

import "core:fmt"
import "core:log"
import "core:strconv"
import "core:unicode/utf8"

eat :: proc(p: ^Parser) -> rune {
	r := p.data[p.index]
	p.index += 1
	return r
}

eat_until :: proc(p: ^Parser, rune_buffer: ^[dynamic]rune, needle: rune) -> Parse_Error {
	for {
		if p.index >= len(p.data) {
			return nil
		}

		if p.data[p.index] == '\n' {
			return nil
		}

		current := peek(p, 0) or_return
		if current == needle {
			return nil
		} else {
			eat(p)
		}

		append(rune_buffer, current)
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
	to_string := utf8.runes_to_string(runes[:])
	defer delete(to_string)

	value, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("got:", value)
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
	rune_to_match := eat(p)
	count := 0

	if (peek(p, 0) or_return) != rune_to_match {
		return rune_to_match, 0, nil
	}

	for i in 0 ..< 8 {
		peeked := (peek(p, 0) or_return)
		if peeked != rune_to_match {
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
	integer_runes[0] = eat(p)
	for i in 1 ..< 3 {
		peeked := (peek(p, 0) or_return)
		if peeked >= '0' && peeked <= '9' {
			integer_runes[i] = eat(p)
		}
	}

	to_string := utf8.runes_to_string(integer_runes[:])
	defer delete(to_string)

	to_int := strconv.atoi(to_string)

	return to_int, nil
}

parse_accidental :: proc(
	p: ^Parser,
	out_runes: ^[dynamic]rune,
) -> (
	length: int,
	err: Parse_Error,
) {
	append(out_runes, eat(p))

	count := 1

	for i in 1 ..< 4 {
		peeked := peek(p, 0) or_return

		if peeked != out_runes[0] {
			append(out_runes, peeked)
			return count, nil
		}

		if is_accidental_rune(peeked) && peeked == out_runes[0] {
			count += 1
			append(out_runes, peeked)
		}
	}

	to_string := utf8.runes_to_string(out_runes[:])
	defer delete(to_string)

	log.error("expected valid accidental, got:", out_runes)
	return 0, .Malformed_Accidental
}
