build:
	@mkdir -p bin
	odin build . -out:bin/humdrum-parser

# Platform-specific builds (native compilation only, cross-compilation not supported)
build-macos:
	@mkdir -p bin
	odin build . -target:darwin_amd64 -out:bin/humdrum-parser

build-linux:
	@mkdir -p bin
	@echo "Note: This command must be run on Linux. Cross-compilation is not supported."
	odin build . -target:linux_amd64 -out:bin/humdrum-parser

build-windows:
	@mkdir -p bin
	@echo "Note: This command must be run on Windows. Cross-compilation is not supported."
	odin build . -target:windows_amd64 -out:bin/humdrum-parser.exe

build-dll-macos:
	@mkdir -p bin
	odin build ./lib -target:darwin_amd64 -build-mode:dll -out:bin/libhumdrum-parser.dylib

build-dll-linux:
	@mkdir -p bin
	@echo "Note: This command must be run on Linux. Cross-compilation is not supported."
	odin build ./lib -target:linux_amd64 -build-mode:dll -out:bin/libhumdrum-parser.so

build-dll-windows:
	@mkdir -p bin
	@echo "Note: This command must be run on Windows. Cross-compilation is not supported."
	odin build ./lib -target:windows_amd64 -build-mode:dll -out:bin/humdrum-parser.dll

test:
	odin test ./tests

clean:
	rm -rf bin/
	rm -rf tmp/
