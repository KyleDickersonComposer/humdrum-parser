package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import d "humdrum-data"
import p "parser"
import t "types"


main :: proc() {
	context.logger = log.create_console_logger()

	parse_data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(parse_data)

	err := p.parse(&parse_data)
	if err != nil {
		log.error(err)
		os.exit(1)
	}

	log.info("[SUCCESS]: Parsed Humdrum file successfully!")
}
