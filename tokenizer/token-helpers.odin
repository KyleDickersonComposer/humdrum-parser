package tokenizer

import "../parsing"
import "../types"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

debug_print_tokens :: proc(tokens: []types.Token_With_Kind) {
	// Print all tokens
	fmt.printf("=== TOKENIZER OUTPUT ===\n")
	fmt.printf("Total tokens: %d\n\n", len(tokens))

	for token, i in tokens {
		fmt.printf("[%d] Line %d: ", i, token.line + 1)
		switch token.kind {
		case .Note:
			note := token.token.(types.Token_Note)
			fmt.printf(
				"Note - name:'%s' duration:%d accidental:'%s' dots:%d\n",
				note.note_name,
				note.duration,
				note.accidental,
				note.dots,
			)
		case .Voice_Separator:
			fmt.printf("Voice_Separator\n")
		case .Line_Break:
			fmt.printf("Line_Break\n")
		case .Bar_Line:
			bar := token.token.(types.Token_Bar_Line)
			fmt.printf("Bar_Line - bar_number:%d\n", bar.bar_number)
		case .Repeat_Decoration_Barline:
			fmt.printf("Repeat_Decoration_Barline\n")
		case .Double_Bar:
			fmt.printf("Double_Bar\n")
		case .Exclusive_Interpretation:
			excl := token.token.(types.Token_Exclusive_Interpretation)
			fmt.printf("Exclusive_Interpretation - spine_type:'%s'\n", excl.spine_type)
		case .Tandem_Interpretation:
			tand := token.token.(types.Token_Tandem_Interpretation)
			fmt.printf("Tandem_Interpretation - code:'%s' value:'%s'\n", tand.code, tand.value)
		case .Reference_Record:
			ref := token.token.(types.Token_Reference_Record)
			fmt.printf("Reference_Record - code:'%s' data:'%s'\n", ref.code, ref.data)
		case .Comment:
			comm := token.token.(types.Token_Comment)
			fmt.printf("Comment - text:'%s'\n", comm.text)
		case .Rest:
			fmt.printf("Rest\n")
		case .Tie_Start:
			fmt.printf("Tie_Start\n")
		case .Tie_End:
			fmt.printf("Tie_End\n")
		case .EOF:
			fmt.printf("EOF\n")
		case:
			fmt.printf("UNKNOWN: %v\n", token.kind)
		}
	}
}

is_accidental_rune :: proc(the_accidental: rune) -> bool {
	for check_match in parsing.ACCIDENTAL_RUNE {
		if the_accidental == check_match {
			return true
		}
	}
	return false
}

// Tokenizer-specific helper functions that return types.Tokenizer_Error

eat_until :: proc(p: ^types.Parser, rune_buffer: ^[dynamic]rune, needle: rune) -> types.Tokenizer_Error {
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
			parsing.eat(p)
		}
	}

	return nil
}

// Eat the rest of the line until newline or EOF (without storing characters)
eat_line :: proc(p: ^types.Parser) -> types.Tokenizer_Error {
	for {
		if p.index >= len(p.data) {
			return nil
		}
		if p.current == '\n' || p.current == utf8.RUNE_EOF {
			return nil
		}
		parsing.eat(p)
	}
	return nil
}

peek :: proc(p: ^types.Parser, offset: int = 1) -> (rune, types.Tokenizer_Error) {
	pos := p.index + offset
	if pos < 0 {
		return '0', .Invalid_Token
	}
	if pos >= len(p.data) {
		return utf8.RUNE_EOF, nil
	}

	return p.data[pos], nil
}

convert_runes_to_int :: proc(runes: []rune) -> (int, types.Tokenizer_Error) {
	if len(runes) == 0 {
		log.error("convert_runes_to_int: empty rune array")
		return 0, .Failed_To_Match_Rune
	}

	to_string := utf8.runes_to_string(runes[:])
	defer delete(to_string)

	if len(to_string) == 0 {
		log.error("convert_runes_to_int: empty string from runes")
		return 0, .Failed_To_Match_Rune
	}

	value, ok := strconv.parse_int(to_string)
	if !ok {
		log.error("convert_runes_to_int: failed to parse:", to_string, "from runes:", runes)
		return 0, .Failed_To_Match_Rune
	}

	return value, nil
}

key_table :: proc(note_name: []rune, out: ^string) -> (err: types.Tokenizer_Error) {
	if len(note_name) == 0 {
		log.error("key_table: empty note_name")
		return .Failed_To_Match_Rune
	}

	if !parsing.is_note_name_rune(note_name[0]) {
		log.error("expected first rune of :", note_name, "to be a valid note_name")
		return .Invalid_Token
	}

	rest := note_name[1:]
	to_string := utf8.runes_to_string(rest)
	defer delete(to_string)

	converted_accidental := ""
	if len(rest) > 0 {
		// Convert Humdrum accidental notation (e.g., "-") to standard (e.g., "b")
		accidental_converted, acc_err := convert_humdrum_accidentals_to_normal_accidentals(to_string)
		if acc_err != nil {
			return .Failed_To_Match_Accidental
		}
		converted_accidental = accidental_converted
	}

	// Normalize to uppercase
	note_char := note_name[0]
	if note_char >= 'a' && note_char <= 'g' {
		note_char = rune(int(note_char) - 32) // Convert to uppercase
	}

	// Build the key name with converted accidental
	if len(rest) > 0 {
		out^ = fmt.aprintf("%c%v", note_char, converted_accidental)
	} else {
		out^ = fmt.aprintf("%c", note_char)
	}

	return nil
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

create_valid_record_code_map :: proc(the_map: ^map[types.Valid_Record_Code]string) {
	the_map[.Composer] = "COM"
	the_map[.Scholarly_Catalog_Number] = "SCT"
	the_map[.Publisher_Catalog_Number] = "PC#"
}

parse_accidental :: proc(
	p: ^types.Parser,
	out_runes: ^[dynamic]rune,
) -> (
	length: int,
	err: types.Tokenizer_Error,
) {
	first_rune := p.current
	append(out_runes, first_rune)
	parsing.eat(p)

	count := 1

	for i in 1 ..< 4 { // Allow up to 3 characters for parsing, then validate
		if p.current != first_rune {
			break // Different character, stop collecting
		}

		if is_accidental_rune(p.current) {
			count += 1
			append(out_runes, p.current)
			parsing.eat(p)
		} else {
			break
		}
	}

	to_string := utf8.runes_to_string(out_runes[:count])
	defer delete(to_string)

	// Validate against the list of known valid accidentals
	is_valid_accidental := false
	for acc in parsing.ACCIDENTAL {
		if acc == to_string {
			is_valid_accidental = true
			break
		}
	}

	if !is_valid_accidental {
		log.error(
			"Invalid accidental:",
			fmt.tprintf("'%s'", to_string),
			fmt.tprintf("(%d characters) at line:", count),
			p.line_count + 1,
			"- not a valid Humdrum accidental (expected #, ##, -, --, n)",
		)
	return 0, .Failed_To_Match_Accidental
	}

	return count, nil
}

parse_int_runes :: proc(p: ^types.Parser) -> (value: int, err: types.Tokenizer_Error) {
	if p.current < '0' || p.current > '9' {
		log.error("parse_int_runes: current character is not a digit:", p.current)
		return 0, .Failed_To_Match_Rune
	}

	integer_runes: [3]rune
	integer_runes[0] = p.current
	parsing.eat(p)
	count := 1
	for i in 1 ..< 3 {
		if p.current >= '0' && p.current <= '9' {
			integer_runes[i] = p.current
			parsing.eat(p)
			count += 1
		} else {
			break
		}
	}

	to_string := utf8.runes_to_string(integer_runes[:count])
	defer delete(to_string)

	if len(to_string) == 0 {
		log.error(
			"parse_int_runes: empty string, current char:",
			p.current,
			"at line:",
			p.line_count,
		)
		return 0, .Failed_To_Match_Rune
	}

	to_int, ok := strconv.parse_int(to_string)
	if !ok {
		log.error(
			"parse_int_runes: failed to parse integer from:",
			to_string,
			"at line:",
			p.line_count,
		)
		return 0, .Failed_To_Match_Rune
	}

	return to_int, nil
}

parse_repeating_rune :: proc(
	p: ^types.Parser,
) -> (
	repeated_rune: rune,
	repeat_count: int,
	err: types.Tokenizer_Error,
) {
	rune_to_match := p.current
	parsing.eat(p)
	count := 0

	if p.current != rune_to_match {
		return rune_to_match, 0, nil
	}

	for i in 0 ..< 8 {
		if p.current != rune_to_match {
			return rune_to_match, count, nil
		}
		parsing.eat(p)
		count += 1
	}

	log.error("ate more than 7 repeating runes")
	return '0', 0, .Failed_To_Parse_Repeating_Rune
}

convert_humdrum_accidentals_to_normal_accidentals :: proc(
	accid: string,
) -> (
	string,
	types.Tokenizer_Error,
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
		return "", .Failed_To_Match_Accidental
	}

	return "", .Failed_To_Match_Accidental
}


// Classify what kind of exclamation mark line this is (doesn't eat anything)
classify_exclamation_line :: proc(
	p: ^types.Parser,
) -> (
	kind: types.Exclamation_Line_Kind,
	err: types.Tokenizer_Error,
) {
	saved_index := p.index
	saved_current := p.current
	defer {
		p.index = saved_index
		p.current = saved_current
	}

	_, repeat_count := parse_repeating_rune(p) or_return

	// repeat_count == 0 means ! (single) = comment (ignore, don't store)
	// repeat_count == 1 means !! (double) = comment (ignore, don't store)
	// repeat_count == 2 means !!! (triple) = reference record (metadata)
	// repeat_count >= 3 means !!!! or more = comment (ignore, don't store)
	if repeat_count == 2 {
		return .Reference_Record, nil
	}

	// Single !, double !!, or 4+ exclamation marks are comments (not stored)
	return .Comment, nil
}

// Classify what kind of asterisk line this is (doesn't eat anything)
classify_asterisk_line :: proc(
	p: ^types.Parser,
) -> (
	kind: types.Asterisk_Line_Kind,
	err: types.Tokenizer_Error,
) {
	saved_index := p.index
	saved_current := p.current
	defer {
		p.index = saved_index
		p.current = saved_current
	}

	_, repeat_count := parse_repeating_rune(p) or_return

	if p.current == '-' {
		return .Null_Interpretation, nil
	}

	if repeat_count == 1 {
		return .Exclusive_Interpretation, nil
	}

	return .Tandem_Interpretation, nil
}

// Classify what type of tandem interpretation this is (doesn't eat anything)
classify_tandem_interpretation :: proc(
	p: ^types.Parser,
) -> (
	ti_type: types.Tandem_Interpretation_Type,
	err: types.Tokenizer_Error,
) {
	saved_index := p.index
	saved_current := p.current
	defer {
		p.index = saved_index
		p.current = saved_current
	}

	// Eat asterisks first
	_, _ = parse_repeating_rune(p) or_return

	// Peek at the code until tab
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	eat_until(p, &ti_code, '\t') or_return

	if len(ti_code) == 0 {
		return .Unknown, nil
	}

	ti_code_string := utf8.runes_to_string(ti_code[:])

	// Check if it's a key (starts with note name, length 2-3) FIRST
	// This must come before valid code check
	if (len(ti_code) == 2 || len(ti_code) == 3) && parsing.is_note_name_rune(ti_code[0]) {
		return .Key, nil
	}

	// Check if it's a meter (starts with 'M', length >= 3, second char is not 'M')
	// This MUST come before valid code check, otherwise "M" in the map will match "M4/4"
	if len(ti_code) >= 3 && ti_code[0] == 'M' && ti_code[1] != 'M' {
		return .Meter, nil
	}

	// Check if it's a valid code
	vtic_map := make(map[types.Valid_Tandem_Interpretation_Code]string)
	defer delete(vtic_map)
	create_valid_tandem_interpretation_code_map(&vtic_map)

	for _, v in vtic_map {
		// Exact match OR code starts with this valid code (e.g., "k" matches "k[]")
		// BUT exclude patterns starting with "MM" (metronome marks like MM100)
		if v == ti_code_string {
			return .Valid_Code, nil
		}
		// For prefix matches, make sure it's not "MM" (metronome marks)
		if len(ti_code_string) > len(v) && ti_code_string[:len(v)] == v {
			// Special case: if matching "M", exclude "MM" patterns (metronome marks)
			if v == "M" && len(ti_code_string) > 1 && ti_code_string[1] == 'M' {
				continue
			}
			return .Valid_Code, nil
		}
	}

	return .Unknown, nil
}

// Parse a valid tandem interpretation code (one spine)
parse_valid_tandem_code :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Match against valid codes (create map once)
	vtic_map := make(map[types.Valid_Tandem_Interpretation_Code]string)
	defer delete(vtic_map)
	create_valid_tandem_interpretation_code_map(&vtic_map)

	// Eat the asterisk
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
		append(&ti_code, p.current)
		parsing.eat(p)
	}
	ti_code_string := utf8.runes_to_string(ti_code[:])

	// Match against valid codes
	found := false
	matched_code := ""
	for k, v in vtic_map {
		// Exact match OR code starts with this valid code (e.g., "k" matches "k[]")
		if v == ti_code_string || (len(ti_code_string) > len(v) && ti_code_string[:len(v)] == v) {
			matched_code = v
			// Special handling for "k" - treat as key and parse the rest
			if v == "k" {
				// Parse as key with the full pattern as value
				key_value := ""
				if len(ti_code_string) > 1 {
					key_value = ti_code_string[1:] // Everything after 'k' (e.g., "[]" or "[b-]")
				}
				append(
					tokens,
					types.Token_With_Kind {
						kind = .Tandem_Interpretation,
						token = types.Token_Tandem_Interpretation {
							code = "key",
							value = key_value,
							line = p.line_count,
						},
						line = p.line_count,
					},
				)
			} else {
				// Regular valid code
				append(
					tokens,
					types.Token_With_Kind {
						kind = .Tandem_Interpretation,
						token = types.Token_Tandem_Interpretation {
							code = v,
							value = ti_code_string,
							line = p.line_count,
						},
						line = p.line_count,
					},
				)
			}
			found = true
			break
		}
	}

	if !found {
		// Shouldn't happen if classification was correct
	}

	return nil
}

// Parse a key tandem interpretation (one spine)
parse_key_tandem :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Eat the asterisk
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
		append(&ti_code, p.current)
		parsing.eat(p)
	}

	// Extract key - handle *a: format (note name keys)
	// k[] patterns are handled in parse_valid_tandem_code
	if len(ti_code) > 0 {
		out_buffer := ""
		// Format: *a: - remove ':' if present, pass note name
		key_code := make([dynamic]rune)
		defer delete(key_code)
		end_idx := len(ti_code)
		if len(ti_code) > 1 && ti_code[len(ti_code) - 1] == ':' {
			end_idx = len(ti_code) - 1
		}
		for r in ti_code[:end_idx] {
			append(&key_code, r)
		}
		
		// Check if first character is lowercase (indicates minor key in Humdrum)
		is_minor := false
		if len(key_code) > 0 && key_code[0] >= 'a' && key_code[0] <= 'g' {
			is_minor = true
		}
		
		key_table(key_code[:], &out_buffer) or_return
		
		// Append 'm' suffix for minor keys
		if is_minor {
			out_buffer = fmt.aprintf("%sm", out_buffer)
		}

		append(
			tokens,
			types.Token_With_Kind {
				kind = .Tandem_Interpretation,
				token = types.Token_Tandem_Interpretation {
					code = "key",
					value = out_buffer,
					line = p.line_count,
				},
				line = p.line_count,
			},
		)
	}

	return nil
}

// Parse a meter tandem interpretation (one spine)
parse_meter_tandem :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Eat the asterisk
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
		append(&ti_code, p.current)
		parsing.eat(p)
	}

	// Parse meter value (e.g., M4/4 -> "4/4")
	if len(ti_code) >= 3 && ti_code[0] == 'M' && ti_code[1] != 'M' {
		// Skip the 'M' and parse the rest (e.g., "4/4")
		without_m := ti_code[1:]

		// Find the slash
		slash_index := -1
		for r, i in without_m {
			if r == '/' {
				slash_index = i
				break
			}
		}

		if slash_index > 0 {
			// Extract numerator and denominator
			numerator_runes := without_m[:slash_index]
			numerator := convert_runes_to_int(numerator_runes) or_return

			denominator_runes := without_m[slash_index + 1:]
			if len(denominator_runes) > 0 {
				denominator := convert_runes_to_int(denominator_runes) or_return
				meter_value := fmt.aprintf("%v/%v", numerator, denominator)

				append(
					tokens,
					types.Token_With_Kind {
						kind = .Tandem_Interpretation,
						token = types.Token_Tandem_Interpretation {
							code = "Meter",
							value = meter_value,
							line = p.line_count,
						},
						line = p.line_count,
					},
				)
			}
		}
	}

	return nil
}

// Parse an unknown/unsupported tandem interpretation (one spine)
parse_unknown_tandem :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Eat the asterisk
	_, _ = parse_repeating_rune(p) or_return

	// Get the code for potential warning
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
		append(&ti_code, p.current)
		parsing.eat(p)
	}

	ti_code_string := utf8.runes_to_string(ti_code[:])
	if len(ti_code_string) > 0 {
		// Unsupported tandem interpretation code - ignoring
	}
	// After warning, eat the rest of the line to avoid duplicate warnings for other spines
	eat_line(p)
	return nil
}

// Parse exclamation line - shows consumption flow
parse_exclamation_line :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	line_kind := classify_exclamation_line(p) or_return

	switch line_kind {
	case .Comment:
		// Comments are ignored - just eat the line without creating a token
		// Comments are ignored
		// Eat all the exclamation marks
		_, _ = parse_repeating_rune(p) or_return
		// Eat rest of comment line (no token created)
		clear(eated)
		eat_until(p, eated, '\n')
		return nil

	case .Reference_Record:
		// Eat the !!!
		_, _ = parse_repeating_rune(p) or_return

		// Eat code until ':'
		record_code := make([dynamic]rune)
		defer delete(record_code)
		eat_until(p, &record_code, ':')
		code_string := utf8.runes_to_string(record_code[:])

		// Eat until next ':'
		eat_until(p, eated, ':')

		// Match against valid codes (matching logic hidden)
		vrc_map := make(map[types.Valid_Record_Code]string)
		defer delete(vrc_map)
		create_valid_record_code_map(&vrc_map)

		match_found := false
		for k, v in vrc_map {
			if code_string == v {
				// Eat the ':' chars
				parsing.eat(p)
				parsing.eat(p)
				// Eat data until newline
				clear(eated)
				eat_until(p, eated, '\n')
				data_string := utf8.runes_to_string(eated[:])
				match_found = true
				append(
					tokens,
					types.Token_With_Kind {
						kind = .Reference_Record,
						token = types.Token_Reference_Record {
							code = k,
							data = data_string,
							line = p.line_count,
						},
						line = p.line_count,
					},
				)
				return nil
			}
		}

		// Unsupported code - ignore (no token created)
		if !match_found {
			// Eat rest of line (no token created)
			clear(eated)
			eat_until(p, eated, '\n')
			return nil
		}
		return nil
	}

	return nil
}

// Parse asterisk line - shows consumption flow
parse_asterisk_line :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	line_kind := classify_asterisk_line(p) or_return

	switch line_kind {
	case .Null_Interpretation:
		return parse_null_interpretation(p, tokens, eated)

	case .Exclusive_Interpretation:
		return parse_exclusive_interpretation(p, tokens, eated)

	case .Tandem_Interpretation:
		// Parse each spine on the line - classify each spine individually
		for {
			// Save position before classification
			saved_index := p.index
			saved_current := p.current

			// Classify this spine
			ti_type := classify_tandem_interpretation(p) or_return

			// Restore position after classification
			p.index = saved_index
			p.current = saved_current

			switch ti_type {
			case .Valid_Code:
				// Parse just this spine (will consume until tab or newline)
				parse_valid_tandem_code(p, tokens, eated) or_return
			case .Key:
				// Parse just this spine (will consume until tab or newline)
				parse_key_tandem(p, tokens, eated) or_return
			case .Meter:
				// Parse just this spine (will consume until tab or newline)
				parse_meter_tandem(p, tokens, eated) or_return
			case .Unknown:
				// Parse just this spine (will consume until tab or newline)
				parse_unknown_tandem(p, tokens, eated) or_return
			}

			// If we hit a tab, continue to next spine; if newline, we're done
			if p.current == '\t' {
				parsing.eat(p) // Eat the tab
				continue
			} else {
				// Newline or EOF - done with this line
				break
			}
		}
		return nil
	}

	return nil
}

// Parse null interpretation (*-...)
parse_null_interpretation :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return
	// Eat the '-'
	parsing.eat(p)
	// Eat rest of line
	eat_until(p, eated, '\n')
	return nil
}

// Parse exclusive interpretation (**kern)
parse_exclusive_interpretation :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Parse each spine on the line (tab-separated)
	for {
		// Eat both asterisks (**)
		_, _ = parse_repeating_rune(p) or_return
		// Clear buffer and eat spine type until tab or newline
		clear(eated)
		for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
			append(eated, p.current)
			parsing.eat(p)
		}
		spine_type := utf8.runes_to_string(eated[:])

		// Validate (matching logic)
		if spine_type != "kern" {
			log.error("expected: kern", "got:", spine_type, "on line:", p.line_count + 1)
			return .Unsupported_Exclusive_Interpretation_Code
		}

		append(
			tokens,
			types.Token_With_Kind {
				kind = .Exclusive_Interpretation,
				token = types.Token_Exclusive_Interpretation {
					spine_type = spine_type,
					line = p.line_count,
				},
				line = p.line_count,
			},
		)

		// If we hit a tab, continue to next spine; if newline, we're done
		if p.current == '\t' {
			parsing.eat(p) // Eat the tab
			continue
		} else {
			// Newline or EOF - done with this line
			break
		}
	}
	return nil
}

// Parse equals line - shows consumption flow
parse_equals_line :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Peek for double bar
	peeked := peek(p) or_return
	if peeked == '=' {
		// Double bar - eat both '=' chars
		parsing.eat(p)
		parsing.eat(p)
		append(
			tokens,
			types.Token_With_Kind {
				kind = .Double_Bar,
				token = types.Token_Double_Bar{line = p.line_count},
				line = p.line_count,
			},
		)
		// Eat rest of line
		eat_until(p, eated, '\n') or_return
		return nil
	}

	// Single bar line
	return parse_bar_line(p, tokens, eated)
}

// Parse bar line (=<number>)
parse_bar_line :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Eat the '='
	parsing.eat(p)

	// Check for double barline (==)
	if p.current == '=' {
		parsing.eat(p)
		// Double barline - use previous bar number or 0
		bar_number := 0
		if len(tokens) > 0 {
			// Try to get last bar number
			for i := len(tokens) - 1; i >= 0; i -= 1 {
				if tokens[i].kind == .Bar_Line {
					bar_line := tokens[i].token.(types.Token_Bar_Line)
					bar_number = bar_line.bar_number
					break
				}
			}
		}

		append(
			tokens,
			types.Token_With_Kind {
				kind = .Bar_Line,
				token = types.Token_Bar_Line{bar_number = bar_number, line = p.line_count},
				line = p.line_count,
			},
		)

		// Eat rest of line
		clear(eated)
		eat_until(p, eated, '\n')
		return nil
	}

	// Parse bar number - only digits, stop at first non-digit
	clear(eated)
	for p.current >= '0' && p.current <= '9' {
		append(eated, p.current)
		parsing.eat(p)
	}

	if len(eated) == 0 {
		// No number found - might be special barline like =:|! or just =
		// Check if this is a special barline (has :, |, or !) or a regular barline
		is_special_barline := false
		if p.current == ':' || p.current == '|' || p.current == '!' {
			is_special_barline = true
		}

		bar_number := 0
		if len(tokens) > 0 {
			// Try to get last bar number
			for i := len(tokens) - 1; i >= 0; i -= 1 {
				if tokens[i].kind == .Bar_Line {
					bar_line := tokens[i].token.(types.Token_Bar_Line)
					bar_number = bar_line.bar_number
					break
				}
			}
		}

		// For regular barlines (just =), increment the bar number
		// For special barlines (e.g. =:|!), treat as decoration and keep same bar number
		if !is_special_barline && bar_number >= 0 {
			bar_number += 1
		}

		if is_special_barline {
			append(
				tokens,
				types.Token_With_Kind {
					kind = .Repeat_Decoration_Barline,
					token = types.Token_Repeat_Decoration_Barline{line = p.line_count},
					line = p.line_count,
				},
			)
		} else {
			append(
				tokens,
				types.Token_With_Kind {
					kind = .Bar_Line,
					token = types.Token_Bar_Line{bar_number = bar_number, line = p.line_count},
					line = p.line_count,
				},
			)
		}

		// Eat rest of line (including special characters like :|!)
		eat_until(p, eated, '\n')
		return nil
	}

	bar_number := convert_runes_to_int(eated[:]) or_return

	append(
		tokens,
		types.Token_With_Kind {
			kind = .Bar_Line,
			token = types.Token_Bar_Line{bar_number = bar_number, line = p.line_count},
			line = p.line_count,
		},
	)

	// Eat rest of line (including any special characters after the number)
	clear(eated)
	eat_until(p, eated, '\n')
	return nil
}

// Parse note - shows consumption flow
parse_note :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	note_token := types.Token_Note{}

	// Initialize note token
	note_token.tie_start = false
	note_token.tie_end = false
	note_token.has_fermata = false
	note_token.is_lower_case = false

	// Eat duration
	if p.current < '0' || p.current > '9' {
		return .Invalid_Token
	}
	note_token.duration = parse_int_runes(p) or_return

	// Eat dots if present
	if p.current == '.' {
		_, dots_repeat_count := parse_repeating_rune(p) or_return
		note_token.dots = dots_repeat_count + 1
	}

	// Check if this is a rest ('r') instead of a note
	if p.current == 'r' {
		// Eat the 'r'
		parsing.eat(p)
		
		// If followed by 'y', silently eat it (y hides the rest)
		if p.current == 'y' {
			parsing.eat(p)
		}
		
		// Create a rest token
		rest_token := types.Token_Rest {
			duration = note_token.duration,
			dots = note_token.dots,
			line = p.line_count,
		}
		append(tokens, types.Token_With_Kind{kind = .Rest, token = rest_token, line = p.line_count})
		
		// Eat until tab, newline, or EOF (skip any remaining characters)
		for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
			parsing.eat(p)
		}
		
		return nil
	}

	// HARD ERROR: # and - are accidentals and MUST appear AFTER a note name
	// Standalone "4#" or "4-" should never exist - these must error
	if p.current == '#' || p.current == '-' {
		log.error(
			"Invalid note: found standalone accidental '",
			p.current,
			"' after duration. Accidentals must appear after a note name (e.g., '4G#', not '4#'). Line:",
			p.line_count + 1,
		)
		return .Invalid_Token
	}

	// Eat note name
	if !parsing.is_note_name_rune(p.current) {
		log.error(
			"malformed note_name: character '",
			p.current,
			"' (rune:",
			p.current,
			") is not a valid note name rune on line:",
			p.line_count + 1,
		)
		return .Invalid_Token
	}
	note_rune, note_repeat_count := parse_repeating_rune(p) or_return
	note_token.note_repeat_count = note_repeat_count

	// Eat accidental if present (# = sharp, - = flat)
	if is_accidental_rune(p.current) {
		out_runes := make([dynamic]rune)
		defer delete(out_runes)
		length := parse_accidental(p, &out_runes) or_return
		to_string := utf8.runes_to_string(out_runes[:length])
		note_token.accidental = to_string
	}

	// Eat courtesy accidental if present
	if p.current == 'X' {
		parsing.eat(p)
	}

	// Determine if lowercase (matching logic)
	for n in parsing.LOWER_CASE_NOTE_NAMES {
		if note_rune == n {
			note_token.is_lower_case = true
			break
		}
	}

	if !note_token.is_lower_case do note_token.note_repeat_count *= -1

	// Note: 'L' (beam open) and 'J' (beam close) are now handled at the tokenizer level
	// They are ignored whether they appear standalone or after a note

	// Note: ']' (tie end) is now handled as a separate token in the tokenizer

	// Eat fermata if present
	if p.current == ';' {
		note_token.has_fermata = true
		parsing.eat(p)
	}

	if !note_token.is_lower_case {
		note_token.note_repeat_count -= 1
	}

	// Set note name - note_name is just the single letter (A-G)
	// The octave offset is stored in note_repeat_count (handled by parse_repeating_rune)
	to_runes := utf8.runes_to_string([]rune{note_rune})
	defer delete(to_runes)
	to_string := strings.to_upper(to_runes)
	// Note: Don't defer delete to_string here - it's stored in the token

	// Validate note name - must be a valid note letter (A-G)
	// Note: Repeated note names (CC, cc) are valid - the repeat count is in note_repeat_count
	if len(to_string) == 0 {
		log.error("Invalid note: empty note name at line:", p.line_count + 1)
		return .Invalid_Token
	}

	// Check that the note name is a valid note letter A-G
	note_name_runes := utf8.string_to_runes(to_string)
	defer delete(note_name_runes)

	if len(note_name_runes) != 1 || !parsing.is_note_name_rune(note_name_runes[0]) {
		log.error(
			"Invalid note name:",
			to_string,
			"rune:",
			note_rune,
			"(expected single letter A-G) at line:",
			p.line_count + 1,
		)
		return .Invalid_Token
	}

	note_token.note_name = to_string
	note_token.line = p.line_count

	append(tokens, types.Token_With_Kind{kind = .Note, token = note_token, line = p.line_count})

	// Eat until tab, but validate characters we encounter
	for p.current != '\t' && p.current != '\n' && p.current != utf8.RUNE_EOF {
		// Hard error: '.' (continuation token) should not appear after a note
		if p.current == '.' {
			log.error(
				"Invalid token: continuation token '.' found after note. Line:",
				p.line_count + 1,
			)
			return .Invalid_Token
		}
		// Beaming characters (J, L, k) and slur characters ((), ) - just consume them
		// These are part of the note data but don't need to be stored
		if p.current == 'J' || p.current == 'L' || p.current == 'k' || p.current == '(' || p.current == ')' {
			parsing.eat(p)
			continue
		}
		append(eated, p.current)
		parsing.eat(p)
	}
	return nil
}

// Parse continuation token - shows consumption flow
parse_continuation_token :: proc(
	p: ^types.Parser,
	tokens: ^[dynamic]types.Token_With_Kind,
	eated: ^[dynamic]rune,
) -> types.Tokenizer_Error {
	// Check if this is a continuation token (not start of note)
	peeked, _ := peek(p)
	is_digit_or_bracket := (peeked >= '0' && peeked <= '9') || peeked == '['
	if !is_digit_or_bracket {
		// This is a continuation token
		// Eat the '.'
		parsing.eat(p)
		// Eat until tab
		eat_until(p, eated, '\t')
		return nil
	}
	// Otherwise, skip the '.' and let next char trigger note parsing
	parsing.eat(p)
	return nil
}
