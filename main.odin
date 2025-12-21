package main

import "core:crypto"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:unicode/utf8"

import "build_ir"
import "parse_syntax"
import tokenize "./tokenize"

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
	// Note: tokens array is in main arena, no delete needed
	
	// Reset scratch arena after tokenize phase (tokens array is in main arena, so safe)
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		log.error("Failed to reinitialize scratch arena")
		os.exit(1)
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// tokenize.debug_print_tokens(tokens[:])

	tree, parse_err := parse_syntax.parse_syntax(&tokens)
	if parse_err != nil {
		log.error("Syntax parsing failed:", parse_err)
		os.exit(1)
	}
	
	// Reset scratch arena after parse phase
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		log.error("Failed to reinitialize scratch arena")
		os.exit(1)
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	log.debug(tree)

	m_IR_json, build_err := build_ir.build_ir(&tree)
	if build_err != nil {
		log.error("IR building failed:", build_err)
		os.exit(1)
	}

	log.debug("Logging metadata...")
	log.debug(m_IR_json.metadata)
	log.debug("Logging voices...")
	log.debug(m_IR_json.voices)
	log.debug("Logging artifacts...")
	log.debug(m_IR_json.artifacts)
	log.debug("Logging staffs...")
	log.debug("Number of staffs:", len(m_IR_json.staffs))
	if len(m_IR_json.staffs) > 0 {
		log.debug("First staff ID:", m_IR_json.staffs[0].ID)
		log.debug("First staff clef:", m_IR_json.staffs[0].clef)
		log.debug("First staff voice_IDs count:", len(m_IR_json.staffs[0].voice_IDs))
		if len(m_IR_json.staffs[0].voice_IDs) > 0 {
			log.debug("First staff first voice_ID:", m_IR_json.staffs[0].voice_IDs[0])
		}
	}
	log.debug(m_IR_json.staffs)
	log.debug("Logging layouts...")
	log.debug(m_IR_json.layouts)
	log.debug("Logging notes...")
	log.debug(m_IR_json.notes)
	log.debug("All logging complete!")
}
