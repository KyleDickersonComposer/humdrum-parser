# Humdrum Parser Python Bindings

Python wrapper for the Humdrum parser DLL.

## Installation

### Option 1: As a Git Submodule

Add this repository as a submodule in your Python project:

```bash
git submodule add <humdrum-parser-repo-url> vendor/humdrum-parser
```

Then in your Python code:

```python
import sys
sys.path.insert(0, 'vendor/humdrum-parser/python')

from humdrum_parser import HumdrumParser

parser = HumdrumParser()
result = parser.parse(humdrum_data)
```

### Option 2: Copy the Python Module

Copy the `python/` directory to your project and import it:

```python
from python.humdrum_parser import HumdrumParser
```

### Option 3: Set Environment Variable

Build the DLL and set the path:

```bash
export HUMDRUM_PARSER_DLL=/path/to/libhumdrum-parser.dylib
```

Then use the module normally.

## Usage

```python
from humdrum_parser import HumdrumParser, parse_humdrum

# Simple usage
result = parse_humdrum(humdrum_string)

# Or with a parser instance
parser = HumdrumParser()
result = parser.parse(humdrum_string)
result = parser.parse_file("path/to/file.krn")
```

## DLL Location

The wrapper searches for the DLL in this order:

1. `HUMDRUM_PARSER_DLL` environment variable
2. Same directory as the Python module
3. `../bin/` relative to the module
4. System library paths (`/usr/local/lib`, `/opt/homebrew/lib`, etc.)

## Requirements

- Python 3.7+
- The Humdrum parser DLL (built separately)

