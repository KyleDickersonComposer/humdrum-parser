package tokenize

import "../parser"
import "core:fmt"
import "core:testing"
import "core:unicode/utf8"

@(test)
test_tokenize_note_with_accidental :: proc(t: ^testing.T) {
	// Test parsing a note with accidental like "8G#"
	data := "8G#\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	testing.expect(t, len(tokens) >= 1, "Should have at least one token")
	
	note_token := tokens[0].token.(Token_Note)
	testing.expect_value(t, note_token.note_name, "G")
	testing.expect_value(t, note_token.accidental, "#")
	testing.expect_value(t, note_token.duration, 8)
}

@(test)
test_tokenize_continuation_token :: proc(t: ^testing.T) {
	// Test that continuation tokens (.) are handled correctly
	// A line like "8G#\t.\t8b" should not create a note token for "."
	data := "8G#\t.\t8b"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	
	// Should have: Note (8G#), Voice_Separator, Voice_Separator (for .), Note (8b)
	note_count := 0
	for token, i in tokens {
		if token.kind == .Note {
			note := token.token.(Token_Note)
			// The note_name should never be just "#" or "."
			if note.note_name == "#" || note.note_name == "." || len(note.note_name) == 0 {
				testing.expectf(t, false, "Token %d: Invalid note_name='%s', accidental='%s', duration=%d", i, note.note_name, note.accidental, note.duration)
			}
			note_name_runes := utf8.string_to_runes(note.note_name)
			if len(note_name_runes) > 0 {
				testing.expect(t, parser.is_note_name_rune(note_name_runes[0]), "Note name should be a valid note letter")
			}
			note_count += 1
		}
	}
	
	testing.expect_value(t, note_count, 2)
}

@(test)
test_tokenize_standalone_accidental :: proc(t: ^testing.T) {
	// Test that a standalone "#" (just an accidental) doesn't create a malformed note token
	// This should either error or be skipped, but not create note_name="#"
	data := "#\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	// Standalone accidental should either error (which is fine) or skip it
	// If it doesn't error, check that no note tokens have note_name="#"
	if err == nil {
		for token in tokens {
			if token.kind == .Note {
				note := token.token.(Token_Note)
				testing.expect(t, note.note_name != "#", "Note name should never be just '#'")
				if len(note.note_name) > 0 {
					note_name_runes := utf8.string_to_runes(note.note_name)
					testing.expect(t, parser.is_note_name_rune(note_name_runes[0]), "Note name should be a valid note letter")
				}
			}
		}
	}
	// If it errors, that's also acceptable - standalone accidental is invalid
}

@(test)
test_tokenize_data_line :: proc(t: ^testing.T) {
	// Test parsing a real data line from the humdrum file
	// "8AL	8cL	4e	8aL" - should create 4 note tokens
	data := "8AL\t8cL\t4e\t8aL\n"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	
	note_count := 0
	for token in tokens {
		if token.kind == .Note {
			note := token.token.(Token_Note)
			testing.expect(t, note.note_name != "#", "Note name should not be just '#'")
			testing.expect(t, note.note_name != ".", "Note name should not be just '.'")
			testing.expect(t, len(note.note_name) > 0, "Note name should not be empty")
			note_count += 1
		}
	}
	
	testing.expect_value(t, note_count, 4)
}

@(test)
test_tokenize_note_with_sharp :: proc(t: ^testing.T) {
	// Test parsing "8G#J" - should parse as note_name='G', accidental='#'
	data := "8G#J\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	testing.expect(t, len(tokens) >= 1, "Should have at least one token")
	
	note_token := tokens[0].token.(Token_Note)
	testing.expect_value(t, note_token.note_name, "G")
	testing.expect_value(t, note_token.accidental, "#")
	testing.expect_value(t, note_token.duration, 8)
}

@(test)
test_tokenize_line_with_continuation :: proc(t: ^testing.T) {
	// Test parsing "8G#J	8BJ	.	8bJ" - line 24 from data
	// Voice 0: 8G#J, Voice 1: 8BJ, Voice 2: . (continuation), Voice 3: 8bJ
	data := "8G#J\t8BJ\t.\t8bJ\n"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	
	note_count := 0
	note_tokens: [4]Token_Note
	for token in tokens {
		if token.kind == .Note {
			note := token.token.(Token_Note)
			// Verify note_name is never '#' or '.'
			testing.expect(t, note.note_name != "#", "Note name should never be '#'")
			testing.expect(t, note.note_name != ".", "Note name should never be '.'")
			testing.expect(t, len(note.note_name) > 0, "Note name should not be empty")
			
			if note_count < 4 {
				note_tokens[note_count] = note
			}
			note_count += 1
		}
	}
	
	// Should have exactly 3 note tokens (continuation doesn't create a token)
	testing.expect_value(t, note_count, 3)
	
	// Verify first note: 8G#J
	testing.expect_value(t, note_tokens[0].note_name, "G")
	testing.expect_value(t, note_tokens[0].accidental, "#")
	testing.expect_value(t, note_tokens[0].duration, 8)
	
	// Verify second note: 8BJ
	testing.expect_value(t, note_tokens[1].note_name, "B")
	testing.expect_value(t, note_tokens[1].accidental, "")
	testing.expect_value(t, note_tokens[1].duration, 8)
	
	// Verify third note: 8bJ
	testing.expect_value(t, note_tokens[2].note_name, "B")
	testing.expect_value(t, note_tokens[2].accidental, "")
	testing.expect_value(t, note_tokens[2].duration, 8)
	testing.expect_value(t, note_tokens[2].is_lower_case, true)
}

@(test)
test_tokenize_dotted_note :: proc(t: ^testing.T) {
	// Test parsing "4.e" - dotted quarter note E
	data := "4.e\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	testing.expect(t, len(tokens) >= 1, "Should have at least one token")
	
	note_token := tokens[0].token.(Token_Note)
	testing.expect_value(t, note_token.note_name, "E")
	testing.expect_value(t, note_token.duration, 4)
	testing.expect_value(t, note_token.dots, 1)
}

@(test)
test_tokenize_note_with_flat :: proc(t: ^testing.T) {
	// Test parsing "8B-L" - note with flat accidental
	data := "8B-\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	testing.expect(t, len(tokens) >= 1, "Should have at least one token")
	
	note_token := tokens[0].token.(Token_Note)
	testing.expect_value(t, note_token.note_name, "B")
	testing.expect_value(t, note_token.accidental, "-")
	testing.expect_value(t, note_token.duration, 8)
}

@(test)
test_tokenize_note_with_natural :: proc(t: ^testing.T) {
	// Test parsing "4cn" - note with natural accidental
	data := "4cn\t"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	testing.expect(t, len(tokens) >= 1, "Should have at least one token")
	
	note_token := tokens[0].token.(Token_Note)
	testing.expect_value(t, note_token.note_name, "C")
	testing.expect_value(t, note_token.accidental, "n")
	testing.expect_value(t, note_token.duration, 4)
}

@(test)
test_tokenize_multiple_continuations :: proc(t: ^testing.T) {
	// Test parsing "8DJ	.	.	." - line 27 from data
	// Voice 0: 8DJ, Voices 1-3: continuations
	data := "8DJ\t.\t.\t.\n"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	
	note_count := 0
	voice_separator_count := 0
	for token in tokens {
		if token.kind == .Note {
			note := token.token.(Token_Note)
			testing.expect(t, note.note_name != "#", "Note name should never be '#'")
			testing.expect(t, note.note_name != ".", "Note name should never be '.'")
			testing.expect(t, len(note.note_name) > 0, "Note name should not be empty")
			note_count += 1
		} else if token.kind == .Voice_Separator {
			voice_separator_count += 1
		}
	}
	
	// Should have exactly 1 note token (continuations don't create tokens)
	testing.expect_value(t, note_count, 1)
	// Should have 3 voice separators (tabs between voices)
	testing.expect_value(t, voice_separator_count, 3)
}

@(test)
test_tokenize_no_invalid_note_names :: proc(t: ^testing.T) {
	// Test that no note tokens have invalid note names like '#', 'n', '.', etc.
	data := "4AA\t4c\t4e\t4a\n8G#J\t8BJ\t.\t8bJ\n"
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize(&parse_data)
	defer delete(tokens)
	
	testing.expect_value(t, err, nil)
	
	invalid_names := []string{"#", ".", "n", "-", "L", "J", "X", ";", "[", "]"}
	
	for token in tokens {
		if token.kind == .Note {
			note := token.token.(Token_Note)
			// Note name should be a valid note letter (A-G)
			note_name_runes := utf8.string_to_runes(note.note_name)
			if len(note_name_runes) > 0 {
				testing.expect(t, parser.is_note_name_rune(note_name_runes[0]), 
					fmt.tprintf("Note name '%s' should start with a valid note letter", note.note_name))
			}
			
			// Note name should never be just an accidental or modifier
			for invalid in invalid_names {
				testing.expect(t, note.note_name != invalid, 
					fmt.tprintf("Note name should never be just '%s'", invalid))
			}
		}
	}
}

