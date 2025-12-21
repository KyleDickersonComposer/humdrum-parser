# Humdrum Parser

A parser for the Humdrum music notation format, specifically designed for parsing Bach chorales into a structured JSON representation. Built in Odin.

## Architecture

The parser uses a three-phase architecture:

1. **Tokenization** (`tokenize/`) - Converts raw Humdrum text into tokens
2. **Syntax Parsing** (`parser/`) - Builds an AST from tokens
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

The parser can be used from any language that can call C functions. It provides a C-compatible API through the shared library, as well as Python bindings.

### C API (Any Language)

The shared library exposes a C API that can be called from any language (C, C++, Python, Go, Rust, etc.):

```c
// Parse Humdrum string and get JSON result
cstring json_result;
int err_code = Parse_Humdrum_String_To_JSON(humdrum_data, &json_result);
if (err_code == 0) {
    // Use json_result (allocated in library, persists until next call)
    printf("%s\n", json_result);
}
```

The library provides two main functions:
- `Parse_Humdrum_String_To_JSON` - Parses a Humdrum string and returns JSON as a C string
- `Parse_Humdrum_String` - Parses a Humdrum string and fills a C struct

See `lib/api.odin` for the full API definition.

### Python Bindings

Python bindings are available in the `python/` directory:

```python
from humdrum_parser import parse_humdrum

result = parse_humdrum(humdrum_data)
# Returns a Python dict with the parsed music IR
```

See `python/README.md` for more details.

### Odin Library

The parser can also be used directly as an Odin library:

```odin
import "humdrum-parser/tokenize"
import "humdrum-parser/parser"
import "humdrum-parser/build_ir"

// Phase 1: Tokenize
tokens, err := tokenize.tokenize(&parse_data)
if err != nil {
    // handle error
}

// Phase 2: Parse syntax
tree, err := parser.parse(&tokens)
if err != nil {
    // handle error
}

// Phase 3: Build IR
ir, err := build_ir.build_ir(&tree)
if err != nil {
    // handle error
}
```

**Note**: When using as an Odin library, you must set up arena allocators for memory management. See the Odin documentation for details.


## Project Structure

```
humdrum-parser/
├── build_ir/          # IR generation from AST
├── parser/            # Syntax parsing (AST building) and shared utilities
├── tokenize/          # Tokenization
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
