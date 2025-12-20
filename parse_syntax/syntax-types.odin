package parse_syntax

import "../tokenize"
import "../parser"

Record_Exclusive_Interpretation :: struct {
	spine_type: string,
}

Record_Tandem_Interpretation :: struct {
	code:  string,
	value: string,
}

Record_Reference :: struct {
	code: parser.Valid_Record_Code,
	data: string,
}

Record_Comment :: struct {
	text: string,
}

Record_Bar_Line :: struct {
	bar_number: int,
}

Record_Double_Bar :: struct {
}

Record_Data_Line :: struct {
	voice_tokens: [4][dynamic]tokenize.Token_Note,
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
	kind: Record_Kind,
	record: Record,
	line: int,
}

Syntax_Tree :: struct {
	records: [dynamic]Record_With_Kind,
}

