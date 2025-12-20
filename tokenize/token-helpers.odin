package tokenize

import "../parser"
import "core:fmt"
import "core:log"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"


is_accidental_rune :: proc(the_accidental: rune) -> bool {
	for check_match in parser.ACCIDENTAL_RUNE {
		if the_accidental == check_match {
			return true
		}
	}
	return false
}

parse_accidental :: proc(
	p: ^parser.Parser,
	out_runes: ^[dynamic]rune,
) -> (
	length: int,
	err: parser.Parse_Error,
) {
	append(out_runes, p.current)
	parser.eat(p)

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
	return 0, parser.Syntax_Error.Malformed_Accidental
}

parse_int_runes :: proc(p: ^parser.Parser) -> (value: int, err: parser.Parse_Error) {
	if p.current < '0' || p.current > '9' {
		log.error("parse_int_runes: current character is not a digit:", p.current)
		return 0, parser.Conversion_Error.Failed_To_Convert_To_Integer
	}

	integer_runes: [3]rune
	integer_runes[0] = p.current
	parser.eat(p)
	count := 1
	for i in 1 ..< 3 {
		if p.current >= '0' && p.current <= '9' {
			integer_runes[i] = p.current
			parser.eat(p)
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
		return 0, parser.Conversion_Error.Failed_To_Convert_To_Integer
	}

	to_int, ok := strconv.parse_int(to_string)
	if !ok {
		log.error(
			"parse_int_runes: failed to parse integer from:",
			to_string,
			"at line:",
			p.line_count,
		)
		return 0, parser.Conversion_Error.Failed_To_Convert_To_Integer
	}

	return to_int, nil
}

parse_repeating_rune :: proc(
	p: ^parser.Parser,
) -> (
	repeated_rune: rune,
	repeat_count: int,
	err: parser.Parse_Error,
) {
	rune_to_match := p.current
	parser.eat(p)
	count := 0

	if p.current != rune_to_match {
		return rune_to_match, 0, nil
	}

	for i in 0 ..< 8 {
		if p.current != rune_to_match {
			return rune_to_match, count, nil
		}
		parser.eat(p)
		count += 1
	}

	log.error("ate more than 7 repeating runes")
	return '0', 0, parser.Tokenizer_Error.Failed_To_Parse_Repeating_Rune
}

convert_humdrum_accidentals_to_normal_accidentals :: proc(
	accid: string,
) -> (
	string,
	parser.Parse_Error,
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
		return "", parser.Tokenizer_Error.Failed_To_Match_Accidental
	}

	return "", parser.Tokenizer_Error.Failed_To_Match_Accidental
}

Exclamation_Line_Kind :: enum {
	Comment,
	Reference_Record,
}

Asterisk_Line_Kind :: enum {
	Null_Interpretation,
	Exclusive_Interpretation,
	Tandem_Interpretation,
}

Tandem_Interpretation_Type :: enum {
	Valid_Code,
	Key,
	Meter,
	Unknown,
}

// Classify what kind of exclamation mark line this is (doesn't eat anything)
classify_exclamation_line :: proc(
	p: ^parser.Parser,
) -> (
	kind: Exclamation_Line_Kind,
	err: parser.Parse_Error,
) {
	saved_index := p.index
	saved_current := p.current
	defer {
		p.index = saved_index
		p.current = saved_current
	}

	_, repeat_count := parse_repeating_rune(p) or_return

	if repeat_count <= 1 || repeat_count >= 3 {
		return .Comment, nil
	}

	// repeat_count == 2 means reference record
	return .Reference_Record, nil
}

// Classify what kind of asterisk line this is (doesn't eat anything)
classify_asterisk_line :: proc(
	p: ^parser.Parser,
) -> (
	kind: Asterisk_Line_Kind,
	err: parser.Parse_Error,
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
	p: ^parser.Parser,
) -> (
	ti_type: Tandem_Interpretation_Type,
	err: parser.Parse_Error,
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
	parser.eat_until(p, &ti_code, '\t') or_return

	if len(ti_code) == 0 {
		return .Unknown, nil
	}

	// Check if it's a valid code
	vtic_map := make(map[parser.Valid_Tandem_Interpretation_Code]string)
	defer delete(vtic_map)
	parser.create_valid_tandem_interpretation_code_map(&vtic_map)

	ti_code_string := utf8.runes_to_string(ti_code[:])
	for _, v in vtic_map {
		if v == ti_code_string {
			return .Valid_Code, nil
		}
	}

	// Check if it's a key (starts with note name, length 2-3)
	if (len(ti_code) == 2 || len(ti_code) == 3) && parser.is_note_name_rune(ti_code[0]) {
		return .Key, nil
	}

	// Check if it's a meter (starts with 'M', length >= 3, second char is not 'M')
	if len(ti_code) >= 3 && ti_code[0] == 'M' && ti_code[1] != 'M' {
		return .Meter, nil
	}

	return .Unknown, nil
}

// Parse a valid tandem interpretation code
parse_valid_tandem_code :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	parser.eat_until(p, &ti_code, '\t') or_return
	ti_code_string := utf8.runes_to_string(ti_code[:])

	// Match against valid codes
	vtic_map := make(map[parser.Valid_Tandem_Interpretation_Code]string)
	defer delete(vtic_map)
	parser.create_valid_tandem_interpretation_code_map(&vtic_map)

	for k, v in vtic_map {
		if v == ti_code_string {
			append(
				tokens,
				Token_With_Kind {
					kind = .Tandem_Interpretation,
					token = Token_Tandem_Interpretation{code = v, value = ti_code_string},
					line = p.line_count,
				},
			)
			parser.eat_until(p, eated, '\n') or_return
			return nil
		}
	}

	// Shouldn't happen if classification was correct
	log.warn("valid code not found:", ti_code_string)
	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse a key tandem interpretation
parse_key_tandem :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	parser.eat_until(p, &ti_code, '\t') or_return

	// Extract key (remove first char which is the 'k')
	ti_code_copy := make([dynamic]rune, len(ti_code))
	copy(ti_code_copy[:], ti_code[:])
	pop(&ti_code_copy)
	defer delete(ti_code_copy)

	out_buffer := ""
	parser.key_table(ti_code_copy[:], &out_buffer) or_return

	append(
		tokens,
		Token_With_Kind {
			kind = .Tandem_Interpretation,
			token = Token_Tandem_Interpretation{code = "key", value = out_buffer},
			line = p.line_count,
		},
	)

	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse a meter tandem interpretation
parse_meter_tandem :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return

	// Get the code
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	parser.eat_until(p, &ti_code, '\t') or_return

	// Parse meter (M<numerator>/<denominator>)
	without_m := ti_code[1:]
	slice_index := -1
	for r, i in without_m {
		if r == '/' {
			slice_index = i
			break
		}
	}

	if slice_index == -1 {
		log.warn("Meter format invalid, no '/' found:", utf8.runes_to_string(without_m))
		parser.eat_until(p, eated, '\n')
		return nil
	}

	numerator_runes := without_m[:slice_index]
	if len(numerator_runes) == 0 {
		log.warn("Meter numerator is empty")
		parser.eat_until(p, eated, '\n')
		return nil
	}

	numerator := parser.convert_runes_to_int(numerator_runes) or_return

	without_slash := without_m[slice_index + 1:]
	denom_slice_index := len(without_slash)
	for r, i in without_slash {
		if r == '\t' || r == ':' {
			denom_slice_index = i
			break
		}
	}

	denominator_runes := without_slash[:denom_slice_index]
	if len(denominator_runes) == 0 {
		log.warn("Meter denominator is empty")
		parser.eat_until(p, eated, '\n')
		return nil
	}

	denominator := parser.convert_runes_to_int(denominator_runes) or_return
	meter_value := fmt.aprintf("M%v/%v", numerator, denominator)
	defer delete(meter_value)

	append(
		tokens,
		Token_With_Kind {
			kind = .Tandem_Interpretation,
			token = Token_Tandem_Interpretation{code = "M", value = meter_value},
			line = p.line_count,
		},
	)

	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse an unknown/unsupported tandem interpretation
parse_unknown_tandem :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return

	// Get the code for logging
	ti_code := make([dynamic]rune)
	defer delete(ti_code)
	parser.eat_until(p, &ti_code, '\t') or_return
	ti_code_string := utf8.runes_to_string(ti_code[:])

	log.warn(
		"unsupported tandem interpretation code:",
		ti_code_string,
		"on line:",
		p.line_count + 1,
	)

	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse exclamation line - shows consumption flow
parse_exclamation_line :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	line_kind := classify_exclamation_line(p) or_return

	switch line_kind {
	case .Comment:
		log.info("comments are ignored, line:", p.line_count + 1)
		// Eat entire comment line
		parser.eat_until(p, eated, '\n')
		text := utf8.runes_to_string(eated[:])
		append(
			tokens,
			Token_With_Kind {
				kind = .Comment,
				token = Token_Comment{text = text},
				line = p.line_count,
			},
		)
		return nil

	case .Reference_Record:
		// Eat the !!
		_, _ = parse_repeating_rune(p) or_return

		// Eat code until ':'
		record_code := make([dynamic]rune)
		defer delete(record_code)
		parser.eat_until(p, &record_code, ':')
		code_string := utf8.runes_to_string(record_code[:])

		// Eat until next ':'
		parser.eat_until(p, eated, ':')

		// Match against valid codes (matching logic hidden)
		vrc_map := make(map[parser.Valid_Record_Code]string)
		defer delete(vrc_map)
		parser.create_valid_record_code_map(&vrc_map)

		match_found := false
		for k, v in vrc_map {
			if code_string == v {
				// Eat the ':' chars
				parser.eat(p)
				parser.eat(p)
				// Eat data until newline
				clear(eated)
				parser.eat_until(p, eated, '\n')
				data_string := utf8.runes_to_string(eated[:])
				match_found = true
				append(
					tokens,
					Token_With_Kind {
						kind = .Reference_Record,
						token = Token_Reference_Record{code = k, data = data_string},
						line = p.line_count,
					},
				)
				return nil
			}
		}

		// Unsupported code - treat as comment
		if !match_found {
			log.warn(
				"unsupported reference record code:",
				code_string,
				"on line:",
				p.line_count + 1,
			)
			// Eat rest of line
			parser.eat_until(p, eated, '\n')
			append(
				tokens,
				Token_With_Kind {
					kind = .Comment,
					token = Token_Comment{text = code_string},
					line = p.line_count,
				},
			)
			return nil
		}
		return nil
	}

	return nil
}

// Parse asterisk line - shows consumption flow
parse_asterisk_line :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	line_kind := classify_asterisk_line(p) or_return

	switch line_kind {
	case .Null_Interpretation:
		return parse_null_interpretation(p, tokens, eated)

	case .Exclusive_Interpretation:
		return parse_exclusive_interpretation(p, tokens, eated)

	case .Tandem_Interpretation:
		ti_type := classify_tandem_interpretation(p) or_return
		switch ti_type {
		case .Valid_Code:
			return parse_valid_tandem_code(p, tokens, eated)
		case .Key:
			return parse_key_tandem(p, tokens, eated)
		case .Meter:
			return parse_meter_tandem(p, tokens, eated)
		case .Unknown:
			return parse_unknown_tandem(p, tokens, eated)
		}
	}

	return nil
}

// Parse null interpretation (*-...)
parse_null_interpretation :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the asterisks
	_, _ = parse_repeating_rune(p) or_return
	// Eat the '-'
	parser.eat(p)
	// Eat rest of line
	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse exclusive interpretation (*kern)
parse_exclusive_interpretation :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the single *
	parser.eat(p)
	// Eat spine type until tab
	parser.eat_until(p, eated, '\t')
	spine_type := utf8.runes_to_string(eated[:])

	// Validate (matching logic)
	if spine_type != "kern" {
		log.error("expected: kern", "got:", spine_type, "on line:", p.line_count + 1)
		return parser.Tokenizer_Error.Unsupported_Exclusive_Interpretation_Code
	}

	append(
		tokens,
		Token_With_Kind {
			kind = .Exclusive_Interpretation,
			token = Token_Exclusive_Interpretation{spine_type = spine_type},
			line = p.line_count,
		},
	)

	// Eat rest of line
	parser.eat_until(p, eated, '\n')
	return nil
}

// Parse equals line - shows consumption flow
parse_equals_line :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Peek for double bar
	if (parser.peek(p) or_return) == '=' {
		// Double bar - eat both '=' chars
		parser.eat(p)
		parser.eat(p)
		append(
			tokens,
			Token_With_Kind{kind = .Double_Bar, token = Token_Double_Bar{}, line = p.line_count},
		)
		// Eat rest of line
		parser.eat_until(p, eated, '\n') or_return
		return nil
	}

	// Single bar line
	return parse_bar_line(p, tokens, eated)
}

// Parse bar line (=<number>)
parse_bar_line :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Eat the '='
	parser.eat(p)
	// Eat bar number until tab
	clear(eated)
	parser.eat_until(p, eated, '\t') or_return

	if len(eated) == 0 {
		log.error("couldn't parse bar_number: empty at line:", p.line_count)
		return parser.Syntax_Error.Malformed_Bar_Number
	}

	bar_str := utf8.runes_to_string(eated[:])
	defer delete(bar_str)
	log.debug("Parsing bar number from:", bar_str, "at line:", p.line_count)

	bar_number := parser.convert_runes_to_int(eated[:]) or_return

	append(
		tokens,
		Token_With_Kind {
			kind = .Bar_Line,
			token = Token_Bar_Line{bar_number = bar_number},
			line = p.line_count,
		},
	)

	// Eat rest of line
	parser.eat_until(p, eated, '\n') or_return
	return nil
}

// Parse note - shows consumption flow
parse_note :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
	tie_start: bool = false,
) -> parser.Parse_Error {
	note_token := Token_Note{}

	// Set tie_start from parameter (explicit)
	note_token.tie_start = tie_start
	note_token.tie_end = false
	note_token.has_fermata = false
	note_token.is_lower_case = false

	// Eat duration
	if p.current < '0' || p.current > '9' {
		log.error("Expected digit for note duration, got:", p.current, "at line:", p.line_count)
		return parser.Syntax_Error.Malformed_Note
	}
	note_token.duration = parse_int_runes(p) or_return

	// Eat dots if present
	if p.current == '.' {
		_, dots_repeat_count := parse_repeating_rune(p) or_return
		note_token.dots = dots_repeat_count + 1
	}

	// Eat note name
	if !parser.is_note_name_rune(p.current) {
		log.error("malformed note_name:", p.current, "on line:", p.line_count + 1)
		return parser.Syntax_Error.Malformed_Note
	}
	note_rune, note_repeat_count := parse_repeating_rune(p) or_return
	note_token.note_repeat_count = note_repeat_count

	// Eat accidental if present
	if is_accidental_rune(p.current) {
		out_runes := make([dynamic]rune)
		length := parse_accidental(p, &out_runes) or_return
		to_string := utf8.runes_to_string(out_runes[:length])
		note_token.accidental = to_string
	}

	// Eat courtesy accidental if present
	if p.current == 'X' {
		log.info("hit courtesy accidental, ignoring")
		parser.eat(p)
	}

	// Determine if lowercase (matching logic)
	for n in parser.LOWER_CASE_NOTE_NAMES {
		if note_rune == n {
			note_token.is_lower_case = true
			break
		}
	}

	if !note_token.is_lower_case do note_token.note_repeat_count *= -1

	// Eat beam open if present
	if p.current == 'L' {
		log.info("hit beam_open token, ignoring ")
		parser.eat(p)
	}

	// Eat beam close if present
	if p.current == 'J' {
		log.info("hit beam_close token, ignoring ")
		parser.eat(p)
	}

	// Eat tie end if present
	if p.current == ']' {
		note_token.tie_end = true
		parser.eat(p)
	}

	// Eat fermata if present
	if p.current == ';' {
		note_token.has_fermata = true
		parser.eat(p)
	}

	if !note_token.is_lower_case {
		note_token.note_repeat_count -= 1
	}

	// Set note name
	note_name := ""
	to_runes := utf8.runes_to_string([]rune{note_rune})
	defer delete(to_runes)
	to_string := strings.to_upper(to_runes)
	defer delete(to_string)
	note_token.note_name = to_string

	append(tokens, Token_With_Kind{kind = .Note, token = note_token, line = p.line_count})

	// Eat until tab
	parser.eat_until(p, eated, '\t')
	return nil
}

// Parse continuation token - shows consumption flow
parse_continuation_token :: proc(
	p: ^parser.Parser,
	tokens: ^[dynamic]Token_With_Kind,
	eated: ^[dynamic]rune,
) -> parser.Parse_Error {
	// Check if this is a continuation token (not start of note)
	peeked := parser.peek(p) or_return
	is_digit_or_bracket := (peeked >= '0' && peeked <= '9') || peeked == '['
	if !is_digit_or_bracket {
		// This is a continuation token
		// Eat the '.'
		parser.eat(p)
		// Eat until tab
		parser.eat_until(p, eated, '\t')
		return nil
	}
	// Otherwise, skip the '.' and let next char trigger note parsing
	parser.eat(p)
	return nil
}
