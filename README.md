# Humdrum parser

### Context
- I'm building a parser for Humdrum so that I can parse Bach Chorales into this JSON format here.
- This will parse everything into the appropriate (global) major key regardless of key center.
- Tried to do this without generating tokens, that was a big mistake!

### BNF
```txt
HUMDRUM_DOCUMENT -> RECORD+
RECORD -> INTERPRETATION_RECORD | DATA_RECORD | COMMENT_RECORD | REFERENCE_RECORD
INTERPRETATION_RECORD -> EXCLUSIVE_INTERPRETATION | TANDEM_INTERPRETATION
EXCLUSIVE_INTERPRETATION -> "**" + SPINE_TYPE
TANDEM_INTERPRETATION -> "*" + TANDEM_CODE STRING
DATA_RECORD -> DATA_TOKEN (TAB DATA_TOKEN)*
REFERENCE_RECORD -> REFERENCE_CODE STRING
COMMENT_RECORD -> COMMENT_TEXT
```

### Notes
- Want to print out a report that says the skipped lines and why.
- `[` `_` `]` delimit the ties
- `L and J` delimit the beams (for some reason the beams start after the note is declared??? Which conflicts with how the ties are declared and wrap the notes that tie applies to...)
- `X` denotes that the the previous token to X is an editoral interpretation. (need to skip this! It seems like they are being added to natural signs?)
- `c` is `c4` and `cc` is `c5` etc.. 
-`C` is `c3` and `CC` is `c2` etc.. 
- Fermata is `;`
