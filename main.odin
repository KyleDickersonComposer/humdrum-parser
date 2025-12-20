package main

import "core:crypto"
import "core:log"
import "core:os"
import "core:unicode/utf8"

import d "humdrum-data"
import build_ir "./build_ir"
import parse_syntax "./parse_syntax"
import tokenize "./tokenize"
import t "./types"

main :: proc() {
	context.logger = log.create_console_logger()
	context.random_generator = crypto.random_generator()

	parse_data := utf8.string_to_runes(d.HUMDRUM_CHORALE)
	defer delete(parse_data)

	tokens, token_err := tokenize.tokenize(&parse_data)
	if token_err != nil {
		log.error("Tokenization failed:", token_err)
		os.exit(1)
	}
	defer delete(tokens)

	tree, parse_err := parse_syntax.parse_syntax(&tokens)
	if parse_err != nil {
		log.error("Syntax parsing failed:", parse_err)
		os.exit(1)
	}

	m_IR_json, build_err := build_ir.build_ir(&tree)
	if build_err != nil {
		log.error("IR building failed:", build_err)
		os.exit(1)
	}

	log.info("[SUCCESS]: Parsed Humdrum file successfully!")
}
