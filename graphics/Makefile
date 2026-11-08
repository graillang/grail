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

.PHONY: all test shaders shader-check tool clean

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

# The C reflection inspector/verifier. It is what makes the tool's output trustworthy: it
# opens every blob the tool wrote, validates it, recomputes the layout digest with an
# independent implementation and compares every frame-constant member offset to offsetof().
$(BUILD)/grail-reflect: src/grail_reflect_tool.c $(OBJ) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ)

tool: $(BUILD)/grail-reflect

# The offline shader flow. The tool owns the flags; this target only asserts it ran.
shaders:
	node tools/shader.mjs --all

# Compile the shaders and then verify every artifact with the C implementation. This is the
# target to run before trusting a shader change. Needs DXC (see docs/dependencies.md).
shader-check: shaders tool
	@set -e; for blob in $$(find ../.work/shaders -name '*.refl.bin'); do \
		$(BUILD)/grail-reflect $$blob >/dev/null || { echo "FAILED: $$blob"; \
		$(BUILD)/grail-reflect $$blob; exit 1; }; done; \
	echo "all reflection blobs verified"

clean:
	rm -rf $(BUILD)
