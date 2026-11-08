# grail graphics foundation: build the C ABI implementation and its tests, compile the shaders
# offline, and verify the reflection the tool produced. The tests need only a C compiler, which
# is what keeps the ABI checkable on a machine with no GPU and no display.
#
#   make test          build and run every test
#   make shaders       compile graphics/shaders to SPIR-V + DXIL + reflection (needs dxc)
#   make shader-check  compile, then verify every blob with the independent C reader
#   make clean
#
# DXC is looked up by the tool: $DXC, then Abundance's pinned tools cache, then PATH.

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Wpedantic -Werror -O1 -g
INCLUDES = -Iinclude
BUILD   := ../.work/graphics

SRC := src/grail_core.c src/grail_reflect.c src/grail_wire.c src/grail_null.c src/grail_null_window.c
OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(SRC))
TESTS := abi device wire
TEST_BINS := $(patsubst %,$(BUILD)/test_%,$(TESTS))
BLOBS := $(shell find ../.work/shaders -name '*.refl.bin' 2>/dev/null)

.PHONY: all test shaders shader-check tool clean

all: test

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Each test links the whole implementation: the ABI is small enough that partial linking would
# only hide a missing entry point until it was called.
$(BUILD)/test_%: tests/test_%.c $(OBJ) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ)

test: $(TEST_BINS)
	@for t in $(TEST_BINS); do ./$$t || exit 1; done

# The C reflection inspector. It is what makes the tool's output trustworthy: it opens every
# blob, validates it, recomputes the layout digest with an independent implementation and
# compares every frame-constant member offset against offsetof().
$(BUILD)/grail-reflect: src/grail_reflect_tool.c $(OBJ) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ)

tool: $(BUILD)/grail-reflect

shaders:
	node tools/shader.mjs --all

shader-check: shaders tool
	@set -e; for blob in $$(find ../.work/shaders -name '*.refl.bin'); do \
		$(BUILD)/grail-reflect $$blob >/dev/null || { \
			echo "FAILED: $$blob"; $(BUILD)/grail-reflect $$blob; exit 1; }; \
	done; echo "all reflection blobs verified"
	@set -e; node tools/shader.mjs --all --permutations 2>/dev/null \
		| grep -oE 'domain [A-Za-z0-9_]+ +id=0x[0-9a-f]+' | sed 's/^domain //' | tr -s ' ' \
		| sort -u > $(BUILD)/ids.tool; \
	for blob in $$(find ../.work/shaders -name '*.refl.bin'); do \
		$(BUILD)/grail-reflect $$blob; done \
		| grep -oE 'define [A-Za-z0-9_]+ +id=0x[0-9a-f]+' | sed 's/^define //' | tr -s ' ' \
		| sort -u > $(BUILD)/ids.c; \
	if ! diff -u $(BUILD)/ids.tool $(BUILD)/ids.c; then \
		echo "permutation name ids differ between tools/shader.mjs and src/grail_core.c"; \
		exit 1; fi; \
	echo "permutation ids agree ($$(wc -l < $(BUILD)/ids.c) define(s))"

clean:
	rm -rf $(BUILD)
