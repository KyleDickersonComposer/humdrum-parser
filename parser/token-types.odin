package parser

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
	duration:        int,
	dots:            int,
	note_name:       string,
	accidental:      string,
	tie_start:       bool,
	tie_end:         bool,
	has_fermata:     bool,
	note_repeat_count: int,
	is_lower_case:   bool,
	line:            int,
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
	kind: Token_Kind,
	token: Token,
	line: int,
}

