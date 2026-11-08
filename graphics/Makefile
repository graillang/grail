# grail graphics foundation: build the C ABI implementation and its tests, compile the shaders
# offline, and verify the reflection the tool produced. The tests need only a C compiler, which
# is what keeps the ABI checkable on a machine with no GPU and no display.
#
#   make test          build and run every test
#   make shaders       compile graphics/shaders to SPIR-V + DXIL + reflection (needs dxc)
#   make shader-check  compile, then verify every blob (base and per-permutation) in C
#   make perm-test     prove each permutation really compiles to its own bytecode (needs bun)
#   make vk-probe      ask the driver what it is, under the exclusive GPU lock (talks to a GPU)
#   make vk-smoke      create a real device and pipeline headless, under the same lock
#   make clean
#
# DXC is looked up by the tool: $DXC, then Abundance's pinned tools cache, then PATH.

CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -Wpedantic -Werror -O1 -g
INCLUDES = -Iinclude
BUILD   := ../.work/graphics

SRC := src/grail_core.c src/grail_reflect.c src/grail_wire.c src/grail_shader_library.c \
       src/grail_vk_common.c src/grail_vk_probe.c src/grail_vulkan.c \
       src/grail_graph.c src/grail_sdl.c src/grail_null.c src/grail_null_window.c
# dlopen is how the Vulkan backend resolves its loader, so every binary that links the
# implementation needs it.
LDLIBS ?= -ldl
OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(SRC))
# Every header is a dependency of every object. Without this an ABI change to a header leaves
# stale objects linked against the new declarations — which is exactly how a version bump goes
# unnoticed until something reads the wrong field.
HEADERS := $(wildcard include/grail/*.h) src/grail_internal.h src/grail_vk_common.h src/grail_sdl.h
TESTS := abi device wire library graph
GPU_TESTS := vk_probe vk_backend
TEST_BINS := $(patsubst %,$(BUILD)/test_%,$(TESTS))
BLOBS := $(shell find ../.work/shaders -name '*.refl.bin' 2>/dev/null)

.PHONY: all test shaders shader-check perm-test vk-probe vk-smoke vk-surface tool clean

all: test

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: src/%.c $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# Each test links the whole implementation: the ABI is small enough that partial linking would
# only hide a missing entry point until it was called.
$(BUILD)/test_%: tests/test_%.c $(OBJ) $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ) $(LDLIBS)

test: $(TEST_BINS)
	@for t in $(TEST_BINS); do ./$$t || exit 1; done

# The C reflection inspector. It is what makes the tool's output trustworthy: it opens every
# blob, validates it, recomputes the layout digest with an independent implementation and
# compares every frame-constant member offset against offsetof().
$(BUILD)/grail-reflect: src/grail_reflect_tool.c $(OBJ) $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ) $(LDLIBS)

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
	@# And resolve the artifacts the tool just wrote, through the C library, so the naming the
	@# tool produces and the naming the library parses are proven to be one convention.
	$(BUILD)/test_library ../.work/shaders

# The per-permutation build is only meaningful if the variants differ, so this runs the test
# that proves it rather than asserting it in prose.
perm-test: shaders
	bun test tests/shader_permutations.test.mjs

# The Vulkan probe. It creates an instance and queries only — no device, no memory, no work — but
# it still talks to a driver, so it takes this host's exclusive GPU lock and refuses while the
# game is running, exactly as every other program that touches the GPU here does.
GPU_LOCK = /run/user/$(shell id -u)/ab-engine-gpu.lock
$(BUILD)/grail-vk-probe: src/grail_vk_probe_main.c $(OBJ) $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ) -ldl

$(BUILD)/test_vk_surface: tests/test_vk_surface.c $(OBJ) $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ) $(LDLIBS)

$(BUILD)/test_vk_backend: tests/test_vk_backend.c $(OBJ) $(HEADERS) | $(BUILD)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $< $(OBJ) $(LDLIBS)

# The window and surface path. The validation layer is not installed system-wide on this host, so
# it is pointed at the pinned Vulkan SDK instead of requiring a system install.
VK_SDK ?= $(HOME)/.cache/abundance/engine-tools/vulkan_sdk-1.4.363.0/1.4.363.0/x86_64
vk-surface: $(BUILD)/test_vk_surface
	@if pgrep -x Abundance >/dev/null; then echo "refusing: the game is running"; exit 1; fi
	@if [ -d "$(VK_SDK)" ]; then \
		echo "validation layer: $(VK_SDK)"; \
		VK_LAYER_PATH=$(VK_SDK)/share/vulkan/explicit_layer.d \
		LD_LIBRARY_PATH=$(VK_SDK)/lib:$$LD_LIBRARY_PATH \
		flock -w 600 $(GPU_LOCK) $(BUILD)/test_vk_surface; \
	else \
		echo "pinned Vulkan SDK not found; running without the validation layer"; \
		flock -w 600 $(GPU_LOCK) $(BUILD)/test_vk_surface; \
	fi

# The backend smoke test: a real device, real shader modules, a real pipeline, destroyed cleanly.
vk-smoke: shaders $(BUILD)/test_vk_backend
	@if pgrep -x Abundance >/dev/null; then echo "refusing: the game is running"; exit 1; fi
	flock -w 600 $(GPU_LOCK) $(BUILD)/test_vk_backend ../.work/shaders

vk-probe: $(BUILD)/grail-vk-probe $(BUILD)/test_vk_probe
	@if pgrep -x Abundance >/dev/null; then \
		echo "refusing: the game is running"; exit 1; fi
	flock -w 600 $(GPU_LOCK) $(BUILD)/grail-vk-probe; rc=$$?; \
	flock -w 600 $(GPU_LOCK) $(BUILD)/test_vk_probe || exit $$?; \
	exit $$rc

clean:
	rm -rf $(BUILD)
