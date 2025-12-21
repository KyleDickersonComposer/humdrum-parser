package main

import "core:crypto"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:unicode/utf8"

import tokenize "./tokenize"
import "build_ir"
import "parser"

reset_scratch_arena :: proc(scratch_arena: ^virtual.Arena) -> bool {
	virtual.arena_destroy(scratch_arena)
	scratch_err := virtual.arena_init_growing(scratch_arena)
	if scratch_err != nil {
		log.error("Failed to reinitialize scratch arena")
		return false
	}
	context.temp_allocator = virtual.arena_allocator(scratch_arena)
	return true
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.printf("Usage: %s <humdrum-file>\n", os.args[0])
		os.exit(1)
	}

	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator()

	// Main arena for all persistent data across all phases
	main_arena: virtual.Arena
	alloc_err := virtual.arena_init_growing(&main_arena)
	if alloc_err != nil {
		log.error("Failed to initialize main arena")
		os.exit(1)
	}
	defer virtual.arena_destroy(&main_arena)

	// Scratch arena for temporary allocations (can be reset between phases)
	scratch_arena: virtual.Arena
	scratch_err := virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		log.error("Failed to initialize scratch arena")
		os.exit(1)
	}
	defer virtual.arena_destroy(&scratch_arena)

	// Set main arena as context allocator for persistent data
	context.allocator = virtual.arena_allocator(&main_arena)
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Read Humdrum file
	file_path := os.args[1]
	data, ok := os.read_entire_file(file_path)
	if !ok {
		log.error("Failed to read file:", file_path)
		os.exit(1)
	}
	defer delete(data)

	parse_data := utf8.string_to_runes(string(data))
	defer delete(parse_data)

	tokens, token_err := tokenize.tokenize(&parse_data)
	if token_err != nil {
		log.error("Tokenization failed:", token_err)
		os.exit(1)
	}

	// Reset scratch arena after tokenize phase (tokens array is in main arena, so safe)
	if !reset_scratch_arena(&scratch_arena) {
		os.exit(1)
	}

	tree, parse_err := parser.parse(&tokens)
	if parse_err != nil {
		log.error("Syntax parsing failed:", parse_err)
		os.exit(1)
	}

	// Reset scratch arena after parse phase
	if !reset_scratch_arena(&scratch_arena) {
		os.exit(1)
	}

	m_IR_json, build_err := build_ir.build_ir(&tree)
	if build_err != nil {
		log.error("IR building failed:", build_err)
		os.exit(1)
	}
}
