#include "grail_handle_table.h"
#include "grail_internal.h"

static void *grail_handle_grow(grail_handle_table *table, uint64_t capacity) {
    const uint64_t old_bytes = table->capacity * sizeof(grail_handle_slot);
    const uint64_t new_bytes = capacity * sizeof(grail_handle_slot);
    if (table->allocator->reallocate != NULL) {
        return table->allocator->reallocate(table->allocator->context, table->slots, old_bytes,
                                            new_bytes, 8);
    }
    void *grown = table->allocator->allocate(table->allocator->context, new_bytes, 8);
    if (grown == NULL) {
        return NULL;
    }
    uint8_t *destination = (uint8_t *)grown;
    const uint8_t *source = (const uint8_t *)table->slots;
    for (uint64_t i = 0; i < old_bytes; i++) {
        destination[i] = source[i];
    }
    if (table->slots != NULL) {
        table->allocator->release(table->allocator->context, table->slots, old_bytes, 8);
    }
    return grown;
}

grail_status grail_handle_table_init(grail_handle_table *table, const grail_allocator *allocator,
                                     uint64_t kind) {
    if (table == NULL || allocator == NULL || allocator->allocate == NULL ||
        allocator->release == NULL || kind == 0 || kind > 255) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    table->allocator = allocator;
    table->slots = NULL;
    table->count = 0;
    table->capacity = 0;
    table->kind = kind;
    return GRAIL_OK;
}

void grail_handle_table_destroy(grail_handle_table *table) {
    if (table == NULL) {
        return;
    }
    if (table->slots != NULL) {
        table->allocator->release(table->allocator->context, table->slots,
                                  table->capacity * sizeof(grail_handle_slot), 8);
    }
    table->slots = NULL;
    table->count = 0;
    table->capacity = 0;
}

grail_status grail_handle_table_allocate(grail_handle_table *table, void *object,
                                         grail_handle *out) {
    if (table == NULL || out == NULL || object == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t index = 0;
    while (index < table->count && table->slots[index].object != NULL) {
        index++;
    }
    if (index == table->count) {
        if (table->count >= GRAIL_HANDLE_MAX_SLOTS) {
            return GRAIL_E_TOO_MANY_HANDLES;
        }
        if (table->count == table->capacity) {
            uint64_t capacity = table->capacity == 0 ? 8 : table->capacity * 2;
            if (capacity > GRAIL_HANDLE_MAX_SLOTS) {
                capacity = GRAIL_HANDLE_MAX_SLOTS;
            }
            void *grown = grail_handle_grow(table, capacity);
            if (grown == NULL) {
                return GRAIL_E_OUT_OF_MEMORY;
            }
            table->slots = (grail_handle_slot *)grown;
            table->capacity = capacity;
        }
        table->count++;
        table->slots[index].object = NULL;
        table->slots[index].generation = 0;
    }
    grail_handle_slot *slot = &table->slots[index];
    slot->object = object;
    slot->generation++;
    if (slot->generation == 0 || slot->generation > 0xFFFFFFFFull) {
        slot->generation = 1;
    }
    *out = (slot->generation << 32) | (table->kind << 24) | (index + 1);
    return GRAIL_OK;
}

grail_status grail_handle_table_lookup(grail_handle_table *table, grail_handle handle,
                                       void **object) {
    if (table == NULL || object == NULL || handle == GRAIL_HANDLE_NONE) {
        return GRAIL_E_INVALID_HANDLE;
    }
    const uint64_t index = (handle & 0xFFFFFFull);
    const uint64_t kind = (handle >> 24) & 0xFFull;
    const uint64_t generation = handle >> 32;
    if (index == 0 || index > table->count || kind != table->kind) {
        return GRAIL_E_INVALID_HANDLE;
    }
    const grail_handle_slot *slot = &table->slots[index - 1];
    if (slot->object == NULL || slot->generation != generation) {
        return GRAIL_E_INVALID_HANDLE;
    }
    *object = slot->object;
    return GRAIL_OK;
}

grail_status grail_handle_table_release(grail_handle_table *table, grail_handle handle,
                                        void **object) {
    void *found = NULL;
    const grail_status status = grail_handle_table_lookup(table, handle, &found);
    if (status != GRAIL_OK) {
        return status;
    }
    grail_handle_slot *slot = &table->slots[(handle & 0xFFFFFFull) - 1];
    slot->object = NULL;
    slot->generation++;
    if (slot->generation == 0 || slot->generation > 0xFFFFFFFFull) {
        slot->generation = 1;
    }
    if (object != NULL) {
        *object = found;
    }
    return GRAIL_OK;
}
