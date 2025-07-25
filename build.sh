#!/bin/bash

# Configuration
BUILD_DIR="test/build"
BIN_DIR="bin"
TARGET="bin/sbuild"
DEBUG_FLAGS="-g -DDEBUG"  # Extra flags for debug builds
COLOR_ENABLED=false	   # Colors disabled by default
LIBRARY=false		  # Default to building executable
LIB_TYPE="shared"	  # or "static"

# --- Color Definitions ---
COLOR_RED="31"			# For errors/headers
COLOR_GREEN="32"		  # Success messages
COLOR_YELLOW="33"		 # Commands
COLOR_BLUE="36"		   # File paths (formerly purple)
COLOR_RESET="0"

# --- Helper Functions ---

# Condensed header with path in blue (if colors enabled)
header() {
	if [ "$COLOR_ENABLED" = true ]; then
		echo -e "\033[${2}m===\033[0m ${1%% →*} → \033[${COLOR_BLUE}m${1##*→}\033[0m"
	else
		echo -e "=== ${1}"
	fi
}

# Single-line command output (no extra newlines)
run() {
	if [ "$VERBOSE" = true ] || [ "$DEBUG" = true ]; then
		if [ "$COLOR_ENABLED" = true ]; then
			echo -ne "\033[${COLOR_YELLOW}m$\033[0m "
		else
			echo -n "$ "
		fi
		echo "$*"
	fi
	"$@" || exit 1
}

# --- Core Functions ---
build() {
    header "BUILDING" "$COLOR_RED"
    mkdir -p "$BUILD_DIR" "$BIN_DIR"

    local COMPILER_FLAGS="-Wall -O2"
    [ "$DEBUG" = true ] && COMPILER_FLAGS="$COMPILER_FLAGS $DEBUG_FLAGS"

    # --- Add -fPIC for shared libraries ---
    [ "$LIB_TYPE" = "shared" ] && COMPILER_FLAGS="$COMPILER_FLAGS -fPIC"
    
    # --- Compile all objects (same for libs/executable) ---
    compile "src/core/cli_parser.c" "$BUILD_DIR/cli_parser.o"
    compile "src/core/var_table.c" "$BUILD_DIR/var_table.o" "-Ilib/cjson"
    compile "src/core/loader.c" "$BUILD_DIR/loader.o" "-Ilib/cjson"
    compile "src/core/builder.c" "$BUILD_DIR/builder.o"
    compile "src/sigbuild.c" "$BUILD_DIR/sigbuild.o"
    compile "lib/cjson/cJSON.c" "$BUILD_DIR/cJSON.o"
    
    # --- Conditional: Skip main.c if building a library ---
    if [ "$LIBRARY" != true ]; then
        compile "src/main.c" "$BUILD_DIR/main.o"
    fi

    # --- Final Output: Library or Executable? ---
    if [ "$LIBRARY" = true ]; then
        case "$LIB_TYPE" in
            shared)
                header "LINKING SHARED LIBRARY" "$COLOR_RED"
                run gcc -shared -o "bin/libsbuild.so" "$BUILD_DIR"/*.o
                ;;
            static)
                header "ARCHIVING STATIC LIBRARY" "$COLOR_RED"
                run ar rcs "bin/libsbuild.a" "$BUILD_DIR"/*.o
                ;;
        esac
    else
        header "LINKING EXECUTABLE" "$COLOR_RED"
        run gcc $COMPILER_FLAGS -o "$TARGET" "$BUILD_DIR"/*.o
    fi

    # Success message (color-aware)
    local msg_type=$( [ "$LIBRARY" = true ] && echo "LIBRARY" || echo "BUILD" )
    [ "$COLOR_ENABLED" = true ] \
        && echo -e "\033[${COLOR_GREEN}m✓ ${msg_type} SUCCESS\033[0m: bin/${TARGET##*/}" \
        || echo "${msg_type} SUCCESS: bin/${TARGET##*/}"
}

# Smart flag merging (always includes -Iinclude)
compile() {
	local src=$1 obj=$2 extra_flags=${3:-}
	header "COMPILING $src → $obj" "$COLOR_RED"
	run gcc $COMPILER_FLAGS -c "$src" -o "$obj" -Iinclude $extra_flags
}

clean() {
	header "CLEANING" "$COLOR_RED"
	run rm -f "$BUILD_DIR"/*.o "$TARGET"
	echo "CLEAN COMPLETE"
}

show_help() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -c			Enable colored output"
	echo "  -clean		Remove build artifacts"
	echo "  -debug		Build with debug symbols"
	echo "  -verbose	Show commands"
	echo "  -help		Show this help"
}

# --- Main ---
while [[ $# -gt 0 ]]; do
	case "$1" in
		-c)			COLOR_ENABLED=true; shift ;;
		-clean)		clean; exit 0 ;;
		-debug)		DEBUG=true; shift ;;
		-verbose)  	VERBOSE=true; shift ;;
		-help)	 	show_help; exit 0 ;;
		-shared) 	LIBRARY=true; LIB_TYPE="shared"; shift ;;
		-static) 	LIBRARY=true; LIB_TYPE="static"; shift ;;
		*)		 		echo "Unknown option: $1"; show_help; exit 1 ;;
	esac
done

build
