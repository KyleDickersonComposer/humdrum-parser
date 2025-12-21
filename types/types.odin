package types

// Music IR Types (Output)
Meter :: struct {
	numerator:   int `json:"numerator"`,
	denominator: int `json:"denominator"`,
	type:        string `json:"type"`,
}

Layout :: struct {
	bar_number:         int `json:"barNumber"`,
	has_layout_changed: bool `json:"hasLayoutChanged"`,
	staff_grp_IDs:      []string `json:"staffGrpIDs"`,
	key:                string `json:"key"`,
	meter:              Meter `json:"meter"`,
	right_barline_type: string `json:"rightBarlineType"`,
}

Staff_Grp :: struct {
	ID:                  string `json:"ID"`,
	staff_def_IDs:       []string `json:"staffDefIDs"`,
	parent_staff_grp_ID: string `json:"parentStaffGrpID", omitempty`,
	bracket_style:       string `json:"bracketStyle"`,
}

Staff :: struct {
	ID:          string `json:"ID"`,
	voice_IDs:   []string `json:"voiceIDs"`,
	clef:        string `json:clef"`,
	staff_index: int `json:"staffIndex"`,
}

Voice :: struct {
	ID:                   string `json:"ID"`,
	type:                 string `json:"type"`,
	voice_index_of_staff: int `json:"voiceIndexOfStaff"`,
	is_CF:                bool `json:"isCF"`,
	is_bass:              bool `json"isBass"`,
	is_editable:          bool `json:"isEditable"`,
}

Note :: struct {
	ID:           string `json:"ID"`,
	duration:     string `json:"duration"`,
	dots:         int `json:"dots"`,
	scale_degree: int `json:"scaleDegree"`,
	input_scale:  string `json:"inputScale"`,
	input_octave: int `json:"inputOctave"`,
	staff_ID:     string `json:"staffID"`,
	voice_ID:     string `json:"voiceID"`,
	tie:          string `json:"tie"`,
	accidental:   string `json:"accidental"`,
	bar_number:   int `json:"barNumber"`,
	is_rest:      bool `json:"isRest"`,
	timestamp:    f32 `json:"timestamp"`,
	stem_dir:     string `json:"stemDir"`,
}

Fermata :: struct {
	type:       string `json:"type"`,
	ID:         string `json:"ID"`,
	place:      string `json:"place"`,
	bar_number: int `json:"barNumber"`,
	staff:      string `json:"staff"`,
	start_ID:   string `json:"startID"`,
}

Notation_Artifact :: union {
	Fermata,
}

Metadata :: struct {
	date:                     string `json:"date"`,
	publisher:                string `json:"publisher"`,
	publisher_statement:      string `json:"publisherStatement"`,
	title:                    string `json:"title"`,
	compopser:                string `json:"composer"`,
	catalog_number:           string `json:"catalogNumber"`,
	publisher_catalog_number: string `json:"publisherCatalogNumber"`,
}

Music_IR_Json :: struct {
	metadata:   Metadata,
	layouts:    []Layout `json:"layouts"`,
	staff_grps: []Staff_Grp `json:"staffGrps"`,
	artifacts:  []Notation_Artifact `json:"notationArtifacts"`,
	staffs:     []Staff `json:"staffs"`,
	voices:     []Voice `json:"voices"`,
	notes:      []Note `json:"notes"`,
}

// Token Types
Token_Kind :: enum {
	Exclusive_Interpretation,
	Tandem_Interpretation,
	Reference_Record,
	Comment,
	Bar_Line,
	Double_Bar,
	Note,
	Rest,
	Tie_Start,
	Tie_End,
	Voice_Separator,
	Line_Break,
	EOF,
}

Token_Exclusive_Interpretation :: struct {
	spine_type: string,
	line:       int,
}

Token_Tandem_Interpretation :: struct {
	code:  string,
	value: string,
	line:  int,
}

Token_Reference_Record :: struct {
	code: Valid_Record_Code,
	data: string,
	line: int,
}

Token_Comment :: struct {
	text: string,
	line: int,
}

Token_Bar_Line :: struct {
	bar_number: int,
	line:       int,
}

Token_Note :: struct {
	duration:          int,
	dots:              int,
	note_name:         string,
	accidental:        string,
	tie_start:         bool,
	tie_end:           bool,
	has_fermata:       bool,
	note_repeat_count: int,
	is_lower_case:     bool,
	line:              int,
}

Token_Rest :: struct {
	duration: int,
	dots:     int,
	line:     int,
}

Token_Tie_Start :: struct {
	line: int,
}

Token_Tie_End :: struct {
	line: int,
}

Token_Double_Bar :: struct {
	line: int,
}

Token :: union {
	Token_Exclusive_Interpretation,
	Token_Tandem_Interpretation,
	Token_Reference_Record,
	Token_Comment,
	Token_Bar_Line,
	Token_Double_Bar,
	Token_Note,
	Token_Rest,
	Token_Tie_Start,
	Token_Tie_End,
}

Token_With_Kind :: struct {
	kind:  Token_Kind,
	token: Token,
	line:  int,
}

// Syntax Tree Types
Record_Exclusive_Interpretation :: struct {
	spine_type: string,
}

Record_Tandem_Interpretation :: struct {
	code:  string,
	value: string,
}

Record_Reference :: struct {
	code: Valid_Record_Code,
	data: string,
}

Record_Comment :: struct {
	text: string,
}

Record_Bar_Line :: struct {
	bar_number: int,
}

Record_Double_Bar :: struct {}

Record_Data_Line :: struct {
	voice_tokens: [4][dynamic]Token_Note,
}

Record_Kind :: enum {
	Exclusive_Interpretation,
	Tandem_Interpretation,
	Reference,
	Comment,
	Bar_Line,
	Double_Bar,
	Data_Line,
}

Record :: union {
	Record_Exclusive_Interpretation,
	Record_Tandem_Interpretation,
	Record_Reference,
	Record_Comment,
	Record_Bar_Line,
	Record_Double_Bar,
	Record_Data_Line,
}

Record_With_Kind :: struct {
	kind:   Record_Kind,
	record: Record,
	line:   int,
}

Syntax_Tree :: struct {
	records: [dynamic]Record_With_Kind,
}

// Parser Types
Reference_Record :: struct {
	code: Valid_Record_Code,
	data: string,
}

Tandem_Interpretation :: struct {
	code:        Valid_Tandem_Interpretation_Code,
	value:       string,
	voice_index: int,
}

VALID_DATA_KIND :: enum {
	Double_Bar = 1,
	Bar,
	Note,
	Rest,
}

Parser :: struct {
	data:       []rune,
	current:    rune,
	index:      int,
	line_count: int,
}

Valid_Record_Code :: enum {
	Composer,
	Scholarly_Catalog_Number,
	Publisher_Catalog_Number,
}

Valid_Tandem_Interpretation_Code :: enum {
	Meter,
	Key_Signature,
	IC_Vox,
	I_Bass,
	I_Tenor,
	I_Alto,
	I_Soprn,
	Clef_F4,
	Clef_Gv2,
	Clef_G2,
}

// Tokenizer Helper Types
Exclamation_Line_Kind :: enum {
	Comment,
	Reference_Record,
}

Asterisk_Line_Kind :: enum {
	Null_Interpretation,
	Exclusive_Interpretation,
	Tandem_Interpretation,
}

Tandem_Interpretation_Type :: enum {
	Valid_Code,
	Key,
	Meter,
	Unknown,
}

// Error types (shared across packages)
// All error enums are defined here to avoid circular dependencies
// Packages import types to use these error types

Parser_Error :: enum {
	None = 0,
	// Syntax errors
	Malformed_Note,
	Malformed_Accidental,
	Malformed_Bar_Number,
	// Conversion errors
	Failed_To_Convert_To_Integer,
	Failed_To_Convert_Duration,
	Json_Serialization_Failed,
	Failed_To_Write_File,
	// Lookup errors
	Key_Lookup_Failed,
}

Parsing_Error :: enum {
	None = 0,
	// Syntax errors
	Malformed_Note,
	Malformed_Accidental,
	Malformed_Bar_Number,
	// Conversion errors
	Failed_To_Convert_To_Integer,
	Failed_To_Convert_Duration,
	Json_Serialization_Failed,
	Failed_To_Write_File,
	// Lookup errors
	Key_Lookup_Failed,
}

Tokenizer_Error :: enum {
	None = 0,
	Invalid_Token,
	Unsupported_Exclusive_Interpretation_Code,
	Broke_Array_Bounds,
	Reached_End_Of_Array,
	Failed_To_Match_Rune,
	Failed_To_Match_Accidental,
	Failed_To_Parse_Repeating_Rune,
	Failed_To_Determine_Scale_Degree,
	Invalid_Voice_Index,
	Invalid_Staff_Count,
}

Build_IR_Error :: enum {
	None = 0,
	Unsupported_Staff_Count,
}

Syntax_Error :: enum {
	None = 0,
	Malformed_Note,
	Malformed_Accidental,
	Malformed_Bar_Number,
}

Conversion_Error :: enum {
	None = 0,
	Failed_To_Convert_To_Integer,
	Failed_To_Convert_Duration,
	Json_Serialization_Failed,
	Failed_To_Write_File,
}

Lookup_Error :: enum {
	None = 0,
	Key_Lookup_Failed,
}

Parse_Error :: union #shared_nil {
	Syntax_Error,
	Conversion_Error,
	Lookup_Error,
}

// Shared_Error is a union of all package error enums
// This allows helper functions to return errors from any package without cross-package dependencies
Shared_Error :: union #shared_nil {
	Parser_Error,
	Parsing_Error,
	Tokenizer_Error,
	Build_IR_Error,
}
