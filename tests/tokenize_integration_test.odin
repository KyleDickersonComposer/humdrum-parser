package tests

import "../parser"
import "../tokenize"
import "core:fmt"
import "core:mem/virtual"
import "core:testing"
import "core:unicode/utf8"

// Integration test for tokenizer
// Tests the full tokenization flow including cleanup
@(test)
test_tokenize_integration :: proc(t: ^testing.T) {
	// Setup arenas like main() does
	main_arena: virtual.Arena
	alloc_err := virtual.arena_init_growing(&main_arena)
	if alloc_err != nil {
		testing.fail_now(t, "Failed to initialize main arena")
	}
	defer virtual.arena_destroy(&main_arena)
	
	scratch_arena: virtual.Arena
	scratch_err := virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		testing.fail_now(t, "Failed to initialize scratch arena")
	}
	defer virtual.arena_destroy(&scratch_arena)
	
	context.allocator = virtual.arena_allocator(&main_arena)
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)
	
	// Test data covering various token types
	data := `!!!COM: Bach, Johann Sebastian
!!!SCT: BWV 420
!!!PC#: 145
**kern	**kern	**kern	**kern
*ICvox	*ICvox	*ICvox	*ICvox
*M4/4	*M4/4	*M4/4	*M4/4
8G#	8B	.	8b
4A	4c	4e	4a
`


	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)

	tokens, err := tokenize.tokenize(&parse_data)
	defer tokenize.cleanup_tokens(&tokens)

	testing.expect_value(t, err, nil)

	// Count tokens by type
	note_count := 0
	ref_count := 0
	excl_count := 0
	tandem_count := 0
	line_break_count := 0
	voice_sep_count := 0

	for token in tokens {
		#partial switch token.kind {
		case .Note:
			note := token.token.(parser.Token_Note)
			testing.expect(t, len(note.note_name) > 0, "Note name should not be empty")
			note_count += 1
		case .Reference_Record:
			ref_count += 1
		case .Exclusive_Interpretation:
			excl := token.token.(parser.Token_Exclusive_Interpretation)
			testing.expect_value(t, excl.spine_type, "kern")
			excl_count += 1
		case .Tandem_Interpretation:
			tand := token.token.(parser.Token_Tandem_Interpretation)
			// Verify we have ICvox and Meter tandem interpretations
			testing.expect(
				t,
				tand.code == "ICvox" || tand.code == "Meter",
				fmt.tprintf("Tandem should be ICvox or Meter, got: %s", tand.code),
			)
			if tand.code == "Meter" {
				testing.expect_value(t, tand.value, "4/4")
			}
			tandem_count += 1
		case .Line_Break:
			line_break_count += 1
		case .Voice_Separator:
			voice_sep_count += 1
		}
	}

	// Exact expected counts:
	// Reference records: !!!COM, !!!SCT, !!!PC# = 3
	testing.expect_value(t, ref_count, 3)
	// Exclusive interpretations: **kern (4 spines) = 4
	testing.expect_value(t, excl_count, 4)
	// Tandem interpretations: *ICvox (4 spines) + *M4/4 (4 spines) = 8
	testing.expect_value(t, tandem_count, 8)
	// Notes: Line 1: 8G#, 8B, 8b (3 notes, . is continuation) + Line 2: 4A, 4c, 4e, 4a (4 notes) = 7
	testing.expect_value(t, note_count, 7)
	// Line breaks: 8 lines of data = 8 line breaks
	testing.expect_value(t, line_break_count, 8)
}
