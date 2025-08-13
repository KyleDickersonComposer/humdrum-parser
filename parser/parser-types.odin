package parser

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
	Tokenizer_Error,
	Conversion_Error,
	Lookup_Error,
}

Parser :: struct {
	data:       []rune,
	current:    rune,
	index:      int,
	line_count: int,
}

Valid_Record_Code :: enum {
	Scholarly_Catalog_Number,
	Publisher_Catalog_Number,
}

Valid_Tandem_Interpretation_Code :: enum {
	Meter,
	IC_Vox,
	I_Bass,
	I_Tenor,
	I_Alto,
	I_Soprn,
	Clef_F4,
	Clef_Gv2,
	Clef_G2,
}
