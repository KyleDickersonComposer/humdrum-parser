package tests

import "../build_ir"
import "../parser"
import "../tokenize"
import "core:crypto"
import "core:mem/virtual"
import "core:testing"
import "core:unicode/utf8"

// Integration test for IR building phase
// Tests: AST -> IR structure
@(test)
test_ir_building_integration :: proc(t: ^testing.T) {
	context.random_generator = crypto.random_generator()
	
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

	// Step 1: Tokenize (prerequisite)
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

	// Step 2: Parse AST (prerequisite)
	tree, parse_err := parser.parse(&tokens)
	testing.expect_value(t, parse_err, nil)
	
	// Reset scratch arena after parse
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		testing.fail_now(t, "Failed to reinitialize scratch arena")
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Step 3: Build IR (this is what we're testing)
	ir, build_err := build_ir.build_ir(&tree)
	testing.expect_value(t, build_err, nil)

	// Validate IR structure
	testing.expect_value(t, len(ir.voices), 4)
	testing.expect_value(t, len(ir.staffs), 2)
	testing.expect(t, len(ir.staff_grps) > 0, "Should have at least one staff group")
	testing.expect(t, len(ir.notes) > 0, "Should have notes")
	testing.expect(t, len(ir.layouts) > 0, "Should have layouts")
	
	// Check metadata
	testing.expect_value(t, ir.metadata.catalog_number, "BWV 420")
	testing.expect_value(t, ir.metadata.publisher_catalog_number, "145")
	
	// Basic validation - check IDs are populated
	testing.expect(t, len(ir.voices[0].ID) > 0, "First voice should have an ID")
	testing.expect(t, len(ir.staffs[0].ID) > 0, "First staff should have an ID")
	testing.expect(t, len(ir.notes[0].ID) > 0, "First note should have an ID")
	testing.expect(t, len(ir.staffs[0].voice_IDs) == 2, "First staff should have 2 voice IDs")
	testing.expect(t, len(ir.layouts[0].staff_grp_IDs) > 0, "First layout should have staff group IDs")
}

