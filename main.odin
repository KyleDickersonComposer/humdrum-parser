package main

import "core:fmt"
import d "humdrum-data"
import hd "humdrum-parser"

main :: proc() {
	fmt.println(hd.hello_lexer(d.HUMDRUM_CHORALE))
}
