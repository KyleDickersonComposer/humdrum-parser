# Humdrum Parser

A parser for the Humdrum music notation format, specifically designed for parsing Bach chorales into a structured JSON representation. Built in Odin.

## Features

- **Tokenization**: Converts raw Humdrum text into a stream of tokens
- **Syntax Parsing**: Builds an Abstract Syntax Tree (AST) from tokens
- **IR Generation**: Converts AST into a structured Intermediate Representation (IR) with metadata, voices, staffs, notes, and layouts
- **Memory Management**: Uses arena allocators for efficient memory management
- **Comprehensive Testing**: Separate integration tests for each phase

## Architecture

The parser uses a three-phase architecture:

1. **Tokenization** (`tokenize/`) - Converts raw Humdrum text into tokens
2. **Syntax Parsing** (`parse_syntax/`) - Builds an AST from tokens
3. **IR Building** (`build_ir/`) - Generates structured IR from AST

## Building

```bash
# Build executable (default platform)
make build

# Platform-specific builds (native compilation only)
make build-macos      # macOS (x86_64) - run on macOS
make build-linux      # Linux (x86_64) - run on Linux
make build-windows    # Windows (x86_64) - run on Windows

# Build as shared library (default platform)
make build-dll

# Platform-specific shared library builds (native compilation only)
make build-dll-macos   # macOS (.dylib) - run on macOS
make build-dll-linux    # Linux (.so) - run on Linux
make build-dll-windows  # Windows (.dll) - run on Windows

# Run the program (requires a Humdrum file)
./bin/humdrum-parser path/to/file.krn

# Run tests
make test
```

**Note**: Cross-compilation is not supported by Odin. Platform-specific build commands must be run on their respective platforms.

### Building as Shared Library

To build as a shared library for use in other projects, use the platform-specific targets on their native platforms:

```bash
# On macOS:
make build-dll-macos   # Creates bin/libhumdrum-parser.dylib

# On Linux:
make build-dll-linux    # Creates bin/libhumdrum-parser.so

# On Windows:
make build-dll-windows  # Creates bin/humdrum-parser.dll
```

The shared library can then be linked into other projects that need to use the parser.

## Usage

### As a Library

The parser can be used as a library in other Odin projects. The main API consists of three functions:

```odin
import "humdrum-parser/tokenize"
import "humdrum-parser/parse_syntax"
import "humdrum-parser/build_ir"

// Phase 1: Tokenize
tokens, err := tokenize.tokenize(&parse_data)
if err != nil {
    // handle error
}

// Phase 2: Parse syntax
tree, err := parse_syntax.parse_syntax(&tokens)
if err != nil {
    // handle error
}
defer parse_syntax.cleanup_tree(&tree)

// Phase 3: Build IR
ir, err := build_ir.build_ir(&tree)
if err != nil {
    // handle error
}
```

### Memory Management

The parser uses arena allocators for memory management. You must set up the context before calling parser functions:

```odin
import "core:mem/virtual"

main_arena: virtual.Arena
virtual.arena_init_growing(&main_arena)
defer virtual.arena_destroy(&main_arena)

scratch_arena: virtual.Arena
virtual.arena_init_growing(&scratch_arena)
defer virtual.arena_destroy(&scratch_arena)

context.allocator = virtual.arena_allocator(&main_arena)
context.temp_allocator = virtual.arena_allocator(&scratch_arena)
```


## Project Structure

```
humdrum-parser/
├── build_ir/          # IR generation from AST
├── parse_syntax/       # Syntax parsing (AST building)
├── tokenize/          # Tokenization
├── parser/            # Shared parser utilities and types
├── types/             # Type definitions
├── tests/             # Integration tests
├── main.odin          # Example main program
└── README.md          # This file
```

## Notes on Humdrum Format

- `[` `_` `]` delimit ties
- `L` and `J` delimit beams
- `X` denotes editorial interpretation (skipped)
- `c` is `c4`, `cc` is `c5`, etc.
- `C` is `c3`, `CC` is `c2`, etc.
- Fermata is `;`
