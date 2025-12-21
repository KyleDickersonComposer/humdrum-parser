"""
Robust Python wrapper for the Humdrum parser DLL
"""

import ctypes
import json
import os
import platform
from pathlib import Path
from typing import Optional, Dict, Any
from enum import IntEnum


class ParseError(IntEnum):
    """Error codes returned by the parser"""
    SUCCESS = 0
    ARENA_INIT_FAILED = -1
    
    # Tokenizer errors (1-11)
    TOKENIZER_NONE = 1
    TOKENIZER_INVALID_TOKEN = 2
    TOKENIZER_UNSUPPORTED_EXCLUSIVE = 3
    TOKENIZER_BROKE_ARRAY_BOUNDS = 4
    TOKENIZER_REACHED_END_OF_ARRAY = 5
    TOKENIZER_FAILED_TO_MATCH_RUNE = 6
    TOKENIZER_FAILED_TO_MATCH_ACCIDENTAL = 7
    TOKENIZER_FAILED_TO_PARSE_REPEATING_RUNE = 8
    TOKENIZER_FAILED_TO_DETERMINE_SCALE_DEGREE = 9
    TOKENIZER_INVALID_VOICE_INDEX = 10
    TOKENIZER_INVALID_STAFF_COUNT = 11
    
    # Syntax errors (100-103)
    SYNTAX_NONE = 100
    SYNTAX_MALFORMED_NOTE = 101
    SYNTAX_MALFORMED_ACCIDENTAL = 102
    SYNTAX_MALFORMED_BAR_NUMBER = 103
    
    # Conversion errors (200-204)
    CONVERSION_NONE = 200
    CONVERSION_FAILED_TO_CONVERT_TO_INTEGER = 201
    CONVERSION_FAILED_TO_CONVERT_DURATION = 202
    CONVERSION_JSON_SERIALIZATION_FAILED = 203
    CONVERSION_FAILED_TO_WRITE_FILE = 204
    
    # Lookup errors (300-301)
    LOOKUP_NONE = 300
    LOOKUP_KEY_LOOKUP_FAILED = 301


class HumdrumParserError(Exception):
    """Exception raised when parsing fails"""
    def __init__(self, error_code: int, message: str):
        self.error_code = error_code
        self.message = message
        super().__init__(f"Parse error {error_code}: {message}")


class HumdrumParser:
    """Python wrapper for the Humdrum parser DLL"""
    
    @staticmethod
    def _find_dll() -> Optional[Path]:
        """Find the DLL in common locations"""
        system = platform.system()
        
        # Determine DLL name based on platform
        if system == "Darwin":  # macOS
            dll_name = "libhumdrum-parser.dylib"
        elif system == "Linux":
            dll_name = "libhumdrum-parser.so"
        elif system == "Windows":
            dll_name = "humdrum-parser.dll"
        else:
            raise RuntimeError(f"Unsupported platform: {system}")
        
        # Search paths (in order of preference):
        # 1. Environment variable HUMDRUM_PARSER_DLL
        # 2. Same directory as this module
        # 3. ../bin/ relative to this module
        # 4. System library paths
        
        search_paths = []
        
        # Check environment variable first
        env_path = os.environ.get("HUMDRUM_PARSER_DLL")
        if env_path:
            search_paths.append(Path(env_path))
        
        # Module-relative paths
        module_dir = Path(__file__).parent
        search_paths.extend([
            module_dir / dll_name,  # Same dir as module
            module_dir.parent / "bin" / dll_name,  # ../bin/
        ])
        
        for path in search_paths:
            if path.exists():
                return path
        
        # Try system library paths
        if system == "Darwin":
            system_paths = [
                Path("/usr/local/lib") / dll_name,
                Path("/opt/homebrew/lib") / dll_name,
            ]
        elif system == "Linux":
            system_paths = [
                Path("/usr/local/lib") / dll_name,
                Path("/usr/lib") / dll_name,
            ]
        else:  # Windows
            system_paths = [
                Path("C:/Windows/System32") / dll_name,
            ]
        
        for path in system_paths:
            if path.exists():
                return path
        
        return None
    
    def __init__(self, dll_path: Optional[Path | str] = None):
        """
        Initialize the parser.
        
        Args:
            dll_path: Path to the DLL. If None, searches common locations.
        
        Raises:
            FileNotFoundError: If DLL cannot be found
            RuntimeError: If DLL cannot be loaded
        """
        if dll_path is None:
            dll_path = self._find_dll()
            if dll_path is None:
                raise FileNotFoundError(
                    "Could not find Humdrum parser DLL. "
                    "Set HUMDRUM_PARSER_DLL environment variable or provide dll_path."
                )
        
        self.dll_path = Path(dll_path)
        if not self.dll_path.exists():
            raise FileNotFoundError(f"DLL not found at {self.dll_path}")
        
        # Load the DLL
        try:
            self.lib = ctypes.CDLL(str(self.dll_path))
        except OSError as e:
            raise RuntimeError(f"Failed to load DLL from {self.dll_path}: {e}")
        
        # Define function signature
        self.lib.Parse_Humdrum_String_To_JSON.argtypes = [
            ctypes.c_char_p,      # cstring (humdrum_data)
            ctypes.POINTER(ctypes.c_char_p),  # [^]cstring (output JSON string pointer)
        ]
        self.lib.Parse_Humdrum_String_To_JSON.restype = ctypes.c_int32
    
    def _error_code_to_message(self, error_code: int) -> str:
        """Convert error code to human-readable message"""
        try:
            error = ParseError(error_code)
            return error.name.replace("_", " ").title()
        except ValueError:
            return f"Unknown error code: {error_code}"
    
    def parse(self, humdrum_data: str) -> Dict[str, Any]:
        """
        Parse a Humdrum string and return the result as a Python dict.
        
        Args:
            humdrum_data: The Humdrum format string to parse
        
        Returns:
            Dictionary containing the parsed music IR structure
        
        Raises:
            HumdrumParserError: If parsing fails
        """
        # Convert string to bytes (C string)
        data_bytes = humdrum_data.encode('utf-8')
        
        # Prepare output pointer for JSON string
        out_json_ptr = ctypes.c_char_p()
        
        # Call the function
        err_code = self.lib.Parse_Humdrum_String_To_JSON(
            ctypes.c_char_p(data_bytes),
            ctypes.byref(out_json_ptr)
        )
        
        if err_code != 0:
            error_msg = self._error_code_to_message(err_code)
            raise HumdrumParserError(err_code, error_msg)
        
        if not out_json_ptr.value:
            raise HumdrumParserError(-1, "Parser returned success but no JSON output")
        
        # Convert C string to Python string
        json_str = out_json_ptr.value.decode('utf-8')
        
        # Parse JSON to dict
        try:
            return json.loads(json_str)
        except json.JSONDecodeError as e:
            raise HumdrumParserError(-1, f"Failed to parse JSON output: {e}")
    
    def parse_file(self, file_path: Path | str) -> Dict[str, Any]:
        """
        Parse a Humdrum file and return the result as a Python dict.
        
        Args:
            file_path: Path to the Humdrum file (.krn)
        
        Returns:
            Dictionary containing the parsed music IR structure
        
        Raises:
            HumdrumParserError: If parsing fails
            FileNotFoundError: If file doesn't exist
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            humdrum_data = f.read()
        
        return self.parse(humdrum_data)


# Convenience function for simple usage
def parse_humdrum(humdrum_data: str) -> Dict[str, Any]:
    """
    Convenience function to parse Humdrum data.
    
    Args:
        humdrum_data: The Humdrum format string to parse
    
    Returns:
        Dictionary containing the parsed music IR structure
    """
    parser = HumdrumParser()
    return parser.parse(humdrum_data)
