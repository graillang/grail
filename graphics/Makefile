# grail graphics foundation: build the C ABI implementation and its tests, and compile the
# shaders offline. Deliberately no dependency beyond a C compiler for the tests, so the ABI
# stays checkable on a machine with no GPU.
#
#   make test      build and run every test
#   make shaders   compile graphics/shaders to SPIR-V + DXIL + reflection (needs dxc)
#   make clean
#
# DXC is looked up in $DXC, then in Abundance's pinned tools cache, then on PATH.

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Wpedantic -Werror -O1 -g
INCLUDES = -Iinclude
BUILD   := ../.work/graphics

SRC := src/grail_core.c src/grail_reflect.c src/grail_wire.c src/grail_null.c src/grail_null_window.c
OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(SRC))
TESTS := abi device wire
TEST_BINS := $(patsubst %,$(BUILD)/test_%,$(TESTS))

.PHONY: all test shaders clean

all: test

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Each test links the whole implementation: the ABI is small enough that partial linking
# would only hide a missing entry point until it was called.
$(BUILD)/test_%: tests/test_%.c $(OBJ) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ)

test: $(TEST_BINS)
	@for t in $(TEST_BINS); do ./$$t || exit 1; done

# The offline shader flow. The tool owns the flags; this target only asserts it ran.
shaders:
	node tools/shader.mjs --all

clean:
	rm -rf $(BUILD)
