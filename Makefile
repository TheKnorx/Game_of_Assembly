#all: main.asm io_handler.asm memory_handler.asm field_handler.asm
#	../compile_wlib_gcc.sh $^

# Makefile created by ChatGPT - it seems to work but dont bet your hand on it!
# Makefile for building the whole project and creating the executable ./main
# uses nasm for compiling and gcc (ld) for linking

# Makefile — NASM + GCC build (single-file replacement for compile_wlib_gcc.sh)

SHELL := bash
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

# ---- toolchain ----
NASM ?= nasm
CC   ?= gcc

NASMFLAGS ?= -f elf64 -g -F dwarf
LDFLAGS   ?= -no-pie

# ---- project ----
TARGET := main

# List your asm sources explicitly (keeps ordering stable & obvious)
SRCS := main.asm io_handler.asm memory_handler.asm field_handler.asm DEBUG_helper.asm

BUILD_DIR := build
OBJS := $(patsubst %.asm,$(BUILD_DIR)/%.o,$(SRCS))

.PHONY: all clean
all: $(TARGET)

# Ensure build dir exists
$(BUILD_DIR):
	@mkdir -p "$(BUILD_DIR)"

# Compile rule (prints header, indents assembler output)
$(BUILD_DIR)/%.o: %.asm | $(BUILD_DIR)
	@printf '\n== Compiling: %s ==\n' "$$(realpath "$<")"
	@$(NASM) $(NASMFLAGS) "$<" -o "$@" 2>&1 | sed 's/^/  /'
	@printf '  -> %s\n' "$@"

# Link rule (prints header, indents linker output)
$(TARGET): $(OBJS)
	@printf '\n== Linking -> %s/%s ==\n' "$$(pwd)" "$(TARGET)"
	@$(CC) $(LDFLAGS) $(OBJS) -o "$(TARGET)" 2>&1 | sed 's/^/  /'
	@printf '\nBuild successful: %s/%s\n' "$$(pwd)" "$(TARGET)"

clean:
	@printf 'Cleaning up ... removing build directory along with main executable ...\n'
	@rm -rf "$(BUILD_DIR)" "$(TARGET)"
