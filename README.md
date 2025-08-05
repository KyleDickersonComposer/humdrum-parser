# Humdrum parser

### Context
- I'm building a parser for Humdrum so that I can parse Bach Chorales into this JSON format here.
- This will parse everything into the appropriate (global) major key regardless of key center.

### BNF
```txt
// denoted `!!`
GLOBAL_COMMENT_RECORD -> Ignoring this one!;
// denoted `!`
LOCAL_COMMENT_RECORD ->  Ignoring this one!;

REFERENCE_RECORD -> "!!!" + RECORD_CODE + ":" + STRING;
// square brackets mean optional
RECORD_CODE -> CHAR + CHAR + CHAR ["@" | "@@" + LANGUAGE)];
LANGUAGE -> CHAR + CHAR + CHAR;

// only supporting kern for now!
EXCLUSIVE_INTERPRETATION_RECORD -> "**" + EXCLUSIVE_RECORD_KIND;
EXCLUSIVE_RECORD_KIND -> "kern";

// only voices for now!
TANDEM_INTERPRETATION_RECORD -> "*" + 
    INSTRUMENT_CLASS | 
    INSTRUMENT_VOICE |
    SPINE_METER |
    SPINE_CLEF |
    SPINE_KEY;

INSTRUMENT_CLASS -> "ICvox";
INSTRUMENT_VOICE -> "soprn" | "alto" | "tenor" | "bass";
SPINE_METER -> "M" + INTEGER + "/" + INTEGER;
SPINE_CLEF -> "clef" + "F4" | "G2" | "Gv2";
SPINE_KEY -> // upper and lower A-G, lower denotes minor

DATA_TOKEN -> NULL_TOKEN |
    SPINE_TERMINAL |
    NEW_BAR |
    DOUBLE_BAR |
    NEW_BAR |
    NOTE |
    REST;

NULL_TOKEN -> ".";
SPINE_TERMINAL -> "*-";
NEW_BAR -> "=" + INTEGER;
DOUBLE_BAR -> "==";
REST -> "r";

// optionals of beams, ties, dots, fermatas... see notes!
// also, need to skip X because thats editoral stuff.
// square brackets mean optional
// put notes in bar zero in the case of pickups
NOTE -> ["["] + DURATION + DOT + NOTE_NAME + ACCIDENTAL ["L"] ["J"] ["]"] [";"];
DOT -> "." | "..";
DURATION -> "1" | "2" | "4" | "8" | "16";
ACCIDENTAL -> "n" | "-" | "--" | "#" | "##";
// enforce char is the same in the repetitions
NOTE_NAME -> // upper and lower A-G with repetitions denoting octave offsets from octave 4
```



### Notes
- Want to print out a report that says the skipped lines and why.
- `[ and ]` delimit the ties
- `L and J` delimit the beams (for some reason the beams start after the note is declared??? Which conflicts with how the ties are declared and wrap the notes that tie applies to...)
- `X` denotes that the the previous token to X is an editoral interpretation. (need to skip this! It seems like they are being added to natural signs?)
- `c` is `c4` and `cc` is `c5` etc.. 
-`C` is `c3` and `CC` is `c2` etc.. 
- Fermata is `;`
