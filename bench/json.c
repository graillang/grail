// The C twin of bench/json.grl. C has no standard JSON library: this is a compact DOM parser and
// serialiser of the kind a C program carries (objects keep their keys in order, numbers that are
// integers stay integers), with the same document, walk and output as the others.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct { char *p; size_t len, cap; } Buf;
static void put(Buf *b, const char *s, size_t n) {
    if (b->len + n > b->cap) { b->cap = (b->len + n) * 2 + 64; b->p = realloc(b->p, b->cap); }
    memcpy(b->p + b->len, s, n); b->len += n;
}
static void puts_(Buf *b, const char *s) { put(b, s, strlen(s)); }
enum { J_NULL, J_BOOL, J_INT, J_FLOAT, J_STR, J_ARR, J_OBJ };
typedef struct Value {
    int kind; int64_t i; double f; char *s; size_t slen;
    struct Value *items; size_t n, cap;
    char **keys; size_t *klens;
} Value;
typedef struct { const char *p, *end; } Cur;
static void ws(Cur *c) { while (c->p < c->end && (*c->p == ' ' || *c->p == '\n' || *c->p == '\t' || *c->p == '\r')) c->p++; }
static void parse(Cur *c, Value *v);
static char *str(Cur *c, size_t *len) {
    c->p++; // opening quote
    Buf b = {0};
    while (*c->p != '"') {
        if (*c->p == '\\') {
            c->p++;
            char e = *c->p == 'n' ? '\n' : *c->p == 't' ? '\t' : *c->p == 'r' ? '\r' : *c->p == 'b' ? '\b' : *c->p == 'f' ? '\f' : *c->p;
            put(&b, &e, 1); c->p++;
        } else { put(&b, c->p, 1); c->p++; }
    }
    c->p++;
    *len = b.len;
    put(&b, "", 1);
    return b.p;
}
static void push(Value *v, Value item, char *key, size_t klen) {
    if (v->n == v->cap) {
        v->cap = v->cap ? v->cap * 2 : 4;
        v->items = realloc(v->items, v->cap * sizeof *v->items);
        if (v->kind == J_OBJ) { v->keys = realloc(v->keys, v->cap * sizeof *v->keys); v->klens = realloc(v->klens, v->cap * sizeof *v->klens); }
    }
    if (v->kind == J_OBJ) { v->keys[v->n] = key; v->klens[v->n] = klen; }
    v->items[v->n++] = item;
}
static void parse(Cur *c, Value *v) {
    ws(c);
    memset(v, 0, sizeof *v);
    char ch = *c->p;
    if (ch == '{') {
        v->kind = J_OBJ; c->p++; ws(c);
        if (*c->p == '}') { c->p++; return; }
        for (;;) {
            ws(c); size_t kl; char *k = str(c, &kl); ws(c); c->p++; // ':'
            Value item; parse(c, &item); push(v, item, k, kl); ws(c);
            if (*c->p == ',') { c->p++; continue; }
            c->p++; return; // '}'
        }
    } else if (ch == '[') {
        v->kind = J_ARR; c->p++; ws(c);
        if (*c->p == ']') { c->p++; return; }
        for (;;) {
            Value item; parse(c, &item); push(v, item, NULL, 0); ws(c);
            if (*c->p == ',') { c->p++; continue; }
            c->p++; return; // ']'
        }
    } else if (ch == '"') {
        v->kind = J_STR; v->s = str(c, &v->slen);
    } else if (ch == 't' || ch == 'f') {
        v->kind = J_BOOL; v->i = ch == 't'; c->p += ch == 't' ? 4 : 5;
    } else if (ch == 'n') {
        v->kind = J_NULL; c->p += 4;
    } else {
        const char *start = c->p;
        int real = 0;
        while (c->p < c->end && strchr("+-0123456789.eE", *c->p)) { if (strchr(".eE", *c->p)) real = 1; c->p++; }
        if (real) { v->kind = J_FLOAT; v->f = strtod(start, NULL); } else { v->kind = J_INT; v->i = strtoll(start, NULL, 10); }
    }
}
static void write_str(Buf *b, const char *s, size_t n) {
    put(b, "\"", 1);
    for (size_t i = 0; i < n; i++) {
        unsigned char ch = (unsigned char)s[i];
        if (ch == '"' || ch == '\\') { char e[2] = { '\\', (char)ch }; put(b, e, 2); }
        else if (ch < 0x20) { char e[8]; int k = snprintf(e, sizeof e, "\\u%04x", ch); put(b, e, (size_t)k); }
        else put(b, (const char *)&ch, 1);
    }
    put(b, "\"", 1);
}
static void write_value(Buf *b, const Value *v) {
    char tmp[32];
    switch (v->kind) {
    case J_NULL: puts_(b, "null"); break;
    case J_BOOL: puts_(b, v->i ? "true" : "false"); break;
    case J_INT: put(b, tmp, (size_t)snprintf(tmp, sizeof tmp, "%lld", (long long)v->i)); break;
    case J_FLOAT: put(b, tmp, (size_t)snprintf(tmp, sizeof tmp, "%.17g", v->f)); break;
    case J_STR: write_str(b, v->s, v->slen); break;
    case J_ARR:
        put(b, "[", 1);
        for (size_t i = 0; i < v->n; i++) { if (i) put(b, ",", 1); write_value(b, &v->items[i]); }
        put(b, "]", 1); break;
    case J_OBJ:
        put(b, "{", 1);
        for (size_t i = 0; i < v->n; i++) { if (i) put(b, ",", 1); write_str(b, v->keys[i], v->klens[i]); put(b, ":", 1); write_value(b, &v->items[i]); }
        put(b, "}", 1); break;
    }
}
typedef struct { uint64_t ints, strings, nodes; } Totals;
static void walk(const Value *v, Totals *t) {
    t->nodes++;
    if (v->kind == J_INT) t->ints += (uint64_t)v->i;
    else if (v->kind == J_STR) t->strings += v->slen;
    else if (v->kind == J_ARR) for (size_t i = 0; i < v->n; i++) walk(&v->items[i], t);
    else if (v->kind == J_OBJ) for (size_t i = 0; i < v->n; i++) { t->strings += v->klens[i]; walk(&v->items[i], t); }
}
int main(void) {
    const uint64_t n = 92000;
    Buf text = {0};
    char tmp[256];
    puts_(&text, "{\"items\":[");
    for (uint64_t i = 0; i < n; i++) {
        if (i > 0) puts_(&text, ",");
        puts_(&text, "{\"id\":");
        put(&text, tmp, (size_t)snprintf(tmp, sizeof tmp, "%llu,\"name\":\"item%llu\",\"tags\":[\"t%llu\",\"u%llu\"],\"value\":%llu,\"nested\":",
            (unsigned long long)i, (unsigned long long)i, (unsigned long long)(i % 7), (unsigned long long)(i % 13), (unsigned long long)(i * 37 % 100003)));
        puts_(&text, "{\"a\":");
        put(&text, tmp, (size_t)snprintf(tmp, sizeof tmp, "%llu,\"b\":[1,2,3],\"label\":\"n%llu\"", (unsigned long long)(i % 100), (unsigned long long)(i % 1000)));
        puts_(&text, "}}");
    }
    puts_(&text, "]}");
    Cur c = { text.p, text.p + text.len };
    Value doc; parse(&c, &doc);
    Totals t = {0};
    walk(&doc, &t);
    Buf out = {0};
    write_value(&out, &doc);
    printf("%zu %llu %llu %llu %zu\n", text.len, (unsigned long long)t.nodes, (unsigned long long)t.ints, (unsigned long long)t.strings, out.len);
    return 0;
}
