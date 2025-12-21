package parser

import "../parsing"
import "../types"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

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

create_valid_record_code_map :: proc(the_map: ^map[types.Valid_Record_Code]string) {
	the_map[.Composer] = "COM"
	the_map[.Scholarly_Catalog_Number] = "SCT"
	the_map[.Publisher_Catalog_Number] = "PC#"
}

create_valid_tandem_interpretation_code_map :: proc(
	the_map: ^map[types.Valid_Tandem_Interpretation_Code]string,
) {
	the_map[.Meter] = "M"
	the_map[.Key_Signature] = "k"
	the_map[.IC_Vox] = "ICvox"
	the_map[.I_Bass] = "Ibass"
	the_map[.I_Tenor] = "Itenor"
	the_map[.I_Alto] = "Ialto"
	the_map[.I_Soprn] = "Isoprn"
	the_map[.Clef_F4] = "clefF4"
	the_map[.Clef_G2] = "clefG2"
	the_map[.Clef_Gv2] = "clefGv2"
}

key_table :: proc(note_name: []rune, out: ^string) -> (err: types.Parser_Error) {
	if len(note_name) == 0 {
		log.error("key_table: empty note_name")
		return .Key_Lookup_Failed
	}

	if !parsing.is_note_name_rune(note_name[0]) {
		log.error("expected first rune of :", note_name, "to be a valid note_name")
		return .Malformed_Note
	}

	rest := note_name[1:]
	to_string := utf8.runes_to_string(rest)
	defer delete(to_string)

	if len(rest) > 0 {
		match_accidental(to_string) or_return
	}

	// Normalize to uppercase
	note_char := note_name[0]
	if note_char >= 'a' && note_char <= 'g' {
		note_char = rune(int(note_char) - 32) // Convert to uppercase
	}

	// Build the key name
	if len(rest) > 0 {
		out^ = fmt.aprintf("%c%v", note_char, to_string)
	} else {
		out^ = fmt.aprintf("%c", note_char)
	}

	return nil
}

match_accidental :: proc(possible_accidental: string) -> (string, types.Parser_Error) {
	for acc in parsing.ACCIDENTAL {
		if possible_accidental == acc {
			return acc, nil
		}
	}

	log.error("expected accidental to match a valid accidental, got:", possible_accidental)
	return "", .Key_Lookup_Failed
}

is_duration_number :: proc(number: int) -> bool {
	if number >= '0' && number <= '9' {
		return true
	}

	return false
}


is_accidental_string :: proc(accidental_string: string) -> bool {
	for accid in parsing.ACCIDENTAL {
		if accid == accidental_string {
			return true
		}
	}
	return false
}

