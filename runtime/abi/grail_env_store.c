#include "grail_env_store.h"

static uint64_t grail_env_text_length(const char *text) {
    uint64_t length = 0;
    while (text[length] != '\0') {
        length++;
    }
    return length;
}

static void grail_env_copy_bytes(char *destination, const uint8_t *source, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        destination[i] = (char)source[i];
    }
}

static int grail_env_equal(const char *left, const uint8_t *right, uint64_t right_length) {
    const uint64_t left_length = grail_env_text_length(left);
    if (left_length != right_length) {
        return 0;
    }
    for (uint64_t i = 0; i < right_length; i++) {
        if ((uint8_t)left[i] != right[i]) {
            return 0;
        }
    }
    return 1;
}

static int grail_env_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_env_name_valid(const uint8_t *name, uint64_t length) {
    if (name == NULL || length == 0 || grail_env_has_zero(name, length)) {
        return 0;
    }
    for (uint64_t i = 0; i < length; i++) {
        if (name[i] == '=') {
            return 0;
        }
    }
    return 1;
}

static char *grail_env_copy_text(const grail_allocator *allocator, const uint8_t *bytes,
                                 uint64_t length) {
    if (length > (uint64_t)INT64_MAX || (bytes == NULL && length != 0)) {
        return NULL;
    }
    char *text = (char *)allocator->allocate(allocator->context, length + 1, 8);
    if (text == NULL) {
        return NULL;
    }
    grail_env_copy_bytes(text, bytes, length);
    text[length] = '\0';
    return text;
}

static void grail_env_free_text(const grail_allocator *allocator, char *text) {
    if (text != NULL) {
        allocator->release(allocator->context, text, grail_env_text_length(text) + 1, 8);
    }
}

static uint64_t grail_env_find(const grail_env_store *store, const uint8_t *name,
                               uint64_t length) {
    for (uint64_t i = 0; i < store->count; i++) {
        if (grail_env_equal(store->names[i], name, length)) {
            return i;
        }
    }
    return store->count;
}

static grail_status grail_env_reserve(grail_env_store *store, uint64_t capacity) {
    if (capacity <= store->capacity) {
        return GRAIL_OK;
    }
    uint64_t next = store->capacity == 0 ? 8 : store->capacity * 2;
    while (next < capacity) {
        next *= 2;
    }
    char **names = (char **)store->allocator->allocate(store->allocator->context,
                                                       next * sizeof(char *), 8);
    char **values = (char **)store->allocator->allocate(store->allocator->context,
                                                        next * sizeof(char *), 8);
    if (names == NULL || values == NULL) {
        if (names != NULL) {
            store->allocator->release(store->allocator->context, names, next * sizeof(char *), 8);
        }
        if (values != NULL) {
            store->allocator->release(store->allocator->context, values, next * sizeof(char *), 8);
        }
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < store->count; i++) {
        names[i] = store->names[i];
        values[i] = store->values[i];
    }
    if (store->names != NULL) {
        store->allocator->release(store->allocator->context, store->names,
                                  store->capacity * sizeof(char *), 8);
        store->allocator->release(store->allocator->context, store->values,
                                  store->capacity * sizeof(char *), 8);
    }
    store->names = names;
    store->values = values;
    store->capacity = next;
    return GRAIL_OK;
}

grail_status grail_env_store_init(grail_env_store *store, const grail_allocator *allocator) {
    if (store == NULL || allocator == NULL || allocator->allocate == NULL ||
        allocator->release == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    store->allocator = allocator;
    store->names = NULL;
    store->values = NULL;
    store->count = 0;
    store->capacity = 0;
    return GRAIL_OK;
}

void grail_env_store_free(grail_env_store *store) {
    if (store == NULL || store->allocator == NULL) {
        return;
    }
    for (uint64_t i = 0; i < store->count; i++) {
        grail_env_free_text(store->allocator, store->names[i]);
        grail_env_free_text(store->allocator, store->values[i]);
    }
    if (store->names != NULL) {
        store->allocator->release(store->allocator->context, store->names,
                                  store->capacity * sizeof(char *), 8);
        store->allocator->release(store->allocator->context, store->values,
                                  store->capacity * sizeof(char *), 8);
    }
    store->names = NULL;
    store->values = NULL;
    store->count = 0;
    store->capacity = 0;
}

grail_status grail_env_store_set(grail_env_store *store, const uint8_t *name,
                                 uint64_t name_length, const uint8_t *value,
                                 uint64_t value_length) {
    if (store == NULL || store->allocator == NULL ||
        !grail_env_name_valid(name, name_length) ||
        (value == NULL && value_length != 0) || grail_env_has_zero(value, value_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *value_copy = grail_env_copy_text(store->allocator, value, value_length);
    if (value_copy == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    uint64_t index = grail_env_find(store, name, name_length);
    if (index == store->count) {
        const grail_status reserved = grail_env_reserve(store, store->count + 1);
        if (reserved != GRAIL_OK) {
            grail_env_free_text(store->allocator, value_copy);
            return reserved;
        }
        char *name_copy = grail_env_copy_text(store->allocator, name, name_length);
        if (name_copy == NULL) {
            grail_env_free_text(store->allocator, value_copy);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        store->names[store->count] = name_copy;
        store->values[store->count] = value_copy;
        store->count++;
        return GRAIL_OK;
    }
    grail_env_free_text(store->allocator, store->values[index]);
    store->values[index] = value_copy;
    return GRAIL_OK;
}

grail_status grail_env_store_get(const grail_env_store *store, const uint8_t *name,
                                 uint64_t name_length, const char **value,
                                 uint64_t *value_length) {
    if (store == NULL || value == NULL || value_length == NULL ||
        !grail_env_name_valid(name, name_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const uint64_t index = grail_env_find(store, name, name_length);
    if (index == store->count) {
        return GRAIL_E_NOT_FOUND;
    }
    *value = store->values[index];
    *value_length = grail_env_text_length(store->values[index]);
    return GRAIL_OK;
}

grail_status grail_env_store_unset(grail_env_store *store, const uint8_t *name,
                                   uint64_t name_length) {
    if (store == NULL || store->allocator == NULL ||
        !grail_env_name_valid(name, name_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const uint64_t index = grail_env_find(store, name, name_length);
    if (index == store->count) {
        return GRAIL_OK;
    }
    grail_env_free_text(store->allocator, store->names[index]);
    grail_env_free_text(store->allocator, store->values[index]);
    for (uint64_t i = index + 1; i < store->count; i++) {
        store->names[i - 1] = store->names[i];
        store->values[i - 1] = store->values[i];
    }
    store->count--;
    return GRAIL_OK;
}

uint64_t grail_env_store_count(const grail_env_store *store) {
    return store == NULL ? 0 : store->count;
}

grail_status grail_env_store_at(const grail_env_store *store, uint64_t index, const char **name,
                                uint64_t *name_length, const char **value,
                                uint64_t *value_length) {
    if (store == NULL || name == NULL || name_length == NULL || value == NULL ||
        value_length == NULL || index >= store->count) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *name = store->names[index];
    *name_length = grail_env_text_length(store->names[index]);
    *value = store->values[index];
    *value_length = grail_env_text_length(store->values[index]);
    return GRAIL_OK;
}

grail_status grail_env_store_seed(grail_env_store *store, const grail_startup *startup) {
    if (store == NULL || store->allocator == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (startup == NULL) {
        return GRAIL_OK;
    }
    if (startup->struct_size < sizeof(*startup) || startup->abi_version != GRAIL_ABI_VERSION) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((startup->environment == NULL && startup->environment_length != 0) ||
        (startup->environment_offsets == NULL && startup->environment_count != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    for (uint64_t i = 0; i < startup->environment_count; i++) {
        const uint64_t begin = startup->environment_offsets[i];
        const uint64_t end = i + 1 < startup->environment_count
                                 ? startup->environment_offsets[i + 1]
                                 : startup->environment_length;
        if (begin >= end || end > startup->environment_length) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        const uint8_t *entry = startup->environment + begin;
        const uint64_t size = end - begin;
        if (entry[size - 1] != 0 || grail_env_has_zero(entry, size - 1)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        uint64_t separator = 0;
        while (separator < size - 1 && entry[separator] != '=') {
            separator++;
        }
        if (separator == 0 || separator == size - 1) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        const grail_status status =
            grail_env_store_set(store, entry, separator, entry + separator + 1,
                                size - separator - 2);
        if (status != GRAIL_OK) {
            return status;
        }
    }
    return GRAIL_OK;
}

grail_status grail_env_snapshot_take(const grail_env_store *store, grail_env_snapshot *snapshot) {
    if (store == NULL || snapshot == NULL || store->allocator == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    snapshot->allocator = store->allocator;
    snapshot->names = NULL;
    snapshot->values = NULL;
    snapshot->count = 0;
    snapshot->capacity = 0;
    if (store->count == 0) {
        return GRAIL_OK;
    }
    snapshot->names = (char **)store->allocator->allocate(
        store->allocator->context, store->count * sizeof(char *), 8);
    snapshot->values = (char **)store->allocator->allocate(
        store->allocator->context, store->count * sizeof(char *), 8);
    if (snapshot->names == NULL || snapshot->values == NULL) {
        if (snapshot->names != NULL) {
            store->allocator->release(store->allocator->context, snapshot->names,
                                      store->count * sizeof(char *), 8);
        }
        if (snapshot->values != NULL) {
            store->allocator->release(store->allocator->context, snapshot->values,
                                      store->count * sizeof(char *), 8);
        }
        snapshot->names = NULL;
        snapshot->values = NULL;
        return GRAIL_E_OUT_OF_MEMORY;
    }
    snapshot->capacity = store->count;
    for (uint64_t i = 0; i < store->count; i++) {
        snapshot->names[i] = grail_env_copy_text(
            store->allocator, (const uint8_t *)store->names[i],
            grail_env_text_length(store->names[i]));
        snapshot->values[i] = grail_env_copy_text(
            store->allocator, (const uint8_t *)store->values[i],
            grail_env_text_length(store->values[i]));
        snapshot->count = i + 1;
        if (snapshot->names[i] == NULL || snapshot->values[i] == NULL) {
            grail_env_snapshot_free(snapshot);
            return GRAIL_E_OUT_OF_MEMORY;
        }
    }
    return GRAIL_OK;
}

void grail_env_snapshot_free(grail_env_snapshot *snapshot) {
    if (snapshot == NULL || snapshot->allocator == NULL) {
        return;
    }
    for (uint64_t i = 0; i < snapshot->count; i++) {
        grail_env_free_text(snapshot->allocator, snapshot->names[i]);
        grail_env_free_text(snapshot->allocator, snapshot->values[i]);
    }
    if (snapshot->names != NULL) {
        snapshot->allocator->release(snapshot->allocator->context, snapshot->names,
                                     snapshot->capacity * sizeof(char *), 8);
        snapshot->allocator->release(snapshot->allocator->context, snapshot->values,
                                     snapshot->capacity * sizeof(char *), 8);
    }
    snapshot->names = NULL;
    snapshot->values = NULL;
    snapshot->count = 0;
    snapshot->capacity = 0;
}
