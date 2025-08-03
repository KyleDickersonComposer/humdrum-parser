package humdrum

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
	date:                string `json:"date"`,
	publisher:           string `json:"publisher"`,
	publisher_statement: string `json:"publisherStatement"`,
	title:               string `json:"title"`,
}

Music_IR_Json :: struct {
	metadata:  Metadata,
	layouts:   []Layout `json:"layouts"`,
	staffs:    []Staff `json:"staffs"`,
	voices:    []Voice `json:"voices"`,
	notes:     []Note `json:"notes"`,
	artifacts: []Notation_Artifact `json:"notationArtifacts"`,
}
