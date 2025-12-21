package parsing

import "../types"
import "core:unicode/utf8"

// Basic parser operations (no errors)
eat :: proc(p: ^types.Parser) {
	p.index += 1
	if p.index >= len(p.data) {
		p.current = utf8.RUNE_EOF
		return
	}
	p.current = p.data[p.index]
}

is_note_name_rune :: proc(note_name: rune) -> bool {
	for nn in NOTE_NAMES {
		if nn == note_name {
			return true
		}
	}
	return false
}

