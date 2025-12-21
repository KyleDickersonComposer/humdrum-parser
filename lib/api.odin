package lib

import "../build_ir"
import "../parser"
import "../tokenize"
import "../types"
import "base:runtime"
import "core:crypto"
import "core:encoding/json"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:unicode/utf8"

// Global arenas for the library (initialized on first use)
main_arena: virtual.Arena
scratch_arena: virtual.Arena
arenas_initialized: bool = false

// Initialize arenas if not already done
init_arenas :: proc() -> bool {
	if !arenas_initialized {
		alloc_err := virtual.arena_init_growing(&main_arena)
		if alloc_err != nil {
			return false
		}
		
		scratch_err := virtual.arena_init_growing(&scratch_arena)
		if scratch_err != nil {
			virtual.arena_destroy(&main_arena)
			return false
		}
		
		arenas_initialized = true
	}
	return true
}

// Convert Parse_Error to error code for C interop
parse_error_to_code :: proc(err: parser.Parse_Error) -> i32 {
	if err == nil {
		return 0
	}
	
	// Map Parse_Error union to unique error codes
	// Using a simple offset-based approach
	#partial switch e in err {
	case parser.Tokenizer_Error:
		return cast(i32)e + 1
	case parser.Syntax_Error:
		return cast(i32)e + 100
	case parser.Conversion_Error:
		return cast(i32)e + 200
	case parser.Lookup_Error:
		return cast(i32)e + 300
	}
	return -1
}

// Parse_Humdrum_String parses a Humdrum string and writes the result to out_ir
// Returns: 0 on success, non-zero error code on failure
// The error code corresponds to parser.Parse_Error enum values
// out_ir can be nil if the caller doesn't need the result
@(export)
Parse_Humdrum_String :: proc "c" (
	humdrum_data: cstring,
	out_ir: [^]types.Music_IR_Json,
) -> (
	err_code: i32,
) {
	// Initialize context for C calling convention
	context = runtime.default_context()
	
	// Initialize arenas if not already done
	if !init_arenas() {
		return -1 // Arena initialization failed
	}
	
	// Set up context
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator()
	context.allocator = virtual.arena_allocator(&main_arena)
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)
	
	// Convert C string to Odin string, then to runes
	humdrum_str := string(humdrum_data)
	parse_data := utf8.string_to_runes(humdrum_str)
	defer delete(parse_data)

	// Phase 1: Tokenize
	tokens, token_err := tokenize.tokenize(&parse_data)
	if token_err != nil {
		return parse_error_to_code(token_err)
	}

	// Reset scratch arena after tokenization
	virtual.arena_destroy(&scratch_arena)
	scratch_err := virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		return -1 // Failed to reinitialize scratch arena
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Phase 2: Parse syntax
	tree, parse_err := parser.parse(&tokens)
	if parse_err != nil {
		return parse_error_to_code(parse_err)
	}

	// Reset scratch arena after parsing
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		return -1 // Failed to reinitialize scratch arena
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Phase 3: Build IR
	result, build_err := build_ir.build_ir(&tree)
	if build_err != nil {
		return parse_error_to_code(build_err)
	}
	if out_ir != nil {
		out_ir[0] = result
	}

	return 0
}

// Parse_Humdrum_String_To_JSON parses a Humdrum string and returns JSON as a C string
// Returns: C string pointer to JSON (allocated in main arena, persists until next call)
// Returns nil on error (check error code)
// The caller should NOT free the returned string
@(export)
Parse_Humdrum_String_To_JSON :: proc "c" (
	humdrum_data: cstring,
	out_json: [^]cstring,
) -> (
	err_code: i32,
) {
	// Initialize context for C calling convention
	context = runtime.default_context()
	
	// Initialize arenas if not already done
	if !init_arenas() {
		return -1 // Arena initialization failed
	}
	
	// Set up context
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator()
	context.allocator = virtual.arena_allocator(&main_arena)
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)
	
	// Convert C string to Odin string, then to runes
	humdrum_str := string(humdrum_data)
	parse_data := utf8.string_to_runes(humdrum_str)
	defer delete(parse_data)

	// Phase 1: Tokenize
	tokens, token_err := tokenize.tokenize(&parse_data)
	if token_err != nil {
		return parse_error_to_code(token_err)
	}

	// Reset scratch arena after tokenization
	virtual.arena_destroy(&scratch_arena)
	scratch_err := virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		return -1 // Failed to reinitialize scratch arena
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Phase 2: Parse syntax
	tree, parse_err := parser.parse(&tokens)
	if parse_err != nil {
		return parse_error_to_code(parse_err)
	}

	// Reset scratch arena after parsing
	virtual.arena_destroy(&scratch_arena)
	scratch_err = virtual.arena_init_growing(&scratch_arena)
	if scratch_err != nil {
		return -1 // Failed to reinitialize scratch arena
	}
	context.temp_allocator = virtual.arena_allocator(&scratch_arena)

	// Phase 3: Build IR
	result, build_err := build_ir.build_ir(&tree)
	if build_err != nil {
		return parse_error_to_code(build_err)
	}
	
	// Serialize to JSON
	opts := json.Marshal_Options {
		pretty = true,
	}
	json_bytes, json_err := json.marshal(result, opts)
	if json_err != nil {
		return parse_error_to_code(parser.Parse_Error(parser.Conversion_Error.Json_Serialization_Failed))
	}
	
	// Convert to C string (allocated in main arena)
	json_str := strings.clone_to_cstring(string(json_bytes))
	if out_json != nil {
		out_json[0] = json_str
	}

	return 0
}
