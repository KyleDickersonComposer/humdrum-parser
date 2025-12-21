package tests

import "../parser"
import "../tokenize"
import "core:mem/virtual"
import "core:testing"
import "core:unicode/utf8"

// Integration test for AST parsing phase
// Tests: tokens -> AST records
@(test)
test_ast_parsing_integration :: proc(t: ^testing.T) {
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
	
	// Simple test data
	data := `!!!COM: Bach, Johann Sebastian
!!!SCT: BWV 420
!!!PC#: 145
**kern	**kern	**kern	**kern
*ICvox	*ICvox	*ICvox	*ICvox
*Ibass	*Itenor	*Ialto	*Isoprn
*clefF4	*clefGv2	*clefG2	*clefG2
*k[]	*k[]	*k[]	*k[]
*kC	*kC	*kC	*kC
*M4/4	*M4/4	*M4/4	*M4/4
4A	4c	4e	4a
=1
8A	8c	4e	8a
4A	4A	4E	4c
==
`

	// Step 1: Tokenize (prerequisite for AST parsing)
	parse_data := utf8.string_to_runes(data)
	defer delete(parse_data)
	
	// Reset scratch arena after tokenize
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		testing.fail_now(t, "Failed to reinitialize scratch arena")
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	tokens, token_err := tokenize.tokenize(&parse_data)
	defer tokenize.cleanup_tokens(&tokens)
	testing.expect_value(t, token_err, nil)

	// Step 2: Parse AST (this is what we're testing)
	tree, parse_err := parser.parse(&tokens)
	testing.expect_value(t, parse_err, nil)
	
	// Validate AST structure
	testing.expect(t, len(tree.records) > 0, "AST should have records")
	
	// Check for expected record types
	has_exclusive_interpretation := false
	has_reference := false
	has_data_line := false
	has_bar_line := false
	
	for record in tree.records {
		#partial switch record.kind {
		case .Exclusive_Interpretation:
			has_exclusive_interpretation = true
		case .Reference:
			has_reference = true
		case .Data_Line:
			has_data_line = true
		case .Bar_Line:
			has_bar_line = true
		}
	}
	
	testing.expect(t, has_exclusive_interpretation, "Should have exclusive interpretation records")
	testing.expect(t, has_reference, "Should have reference records")
	testing.expect(t, has_data_line, "Should have data line records")
	testing.expect(t, has_bar_line, "Should have bar line records")
}

