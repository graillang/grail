// C++ twin of bench/json.grl. C++ has no standard JSON library and this twin uses no third-party
// one: a hand-written recursive-descent DOM parser over std::string_view whose nodes are a
// std::variant (null, bool, int64, double, std::string, array, object), with objects keeping their
// keys in order and integer numbers staying integers, like the C and Rust twins. Same document,
// walk and serialisation, same output.
// clang++ -std=c++20 -O2 -ffp-contract=off json.cpp
#include <charconv>
#include <cstdint>
#include <cstdio>
#include <string>
#include <string_view>
#include <variant>
#include <vector>
struct Member;
struct Value;
using Array = std::vector<Value>;
using Object = std::vector<Member>;
struct Value {
    std::variant<std::nullptr_t, bool, int64_t, double, std::string, Array, Object> v;
};
struct Member {
    std::string key;
    Value value;
};

class Parser {
    std::string_view s;
    size_t p = 0;
    void ws() { while (p < s.size() && (s[p] == ' ' || s[p] == '\n' || s[p] == '\t' || s[p] == '\r')) p++; }
    std::string str() {
        p++; // opening quote
        std::string out;
        while (s[p] != '"') {
            if (s[p] == '\\') {
                char e = s[++p];
                out.push_back(e == 'n' ? '\n' : e == 't' ? '\t' : e == 'r' ? '\r' : e == 'b' ? '\b' : e == 'f' ? '\f' : e);
            } else {
                out.push_back(s[p]);
            }
            p++;
        }
        p++;
        return out;
    }
public:
    explicit Parser(std::string_view text) : s(text) {}
    Value parse() {
        ws();
        char ch = s[p];
        if (ch == '{') {
            Object obj;
            p++; ws();
            if (s[p] == '}') { p++; return {std::move(obj)}; }
            for (;;) {
                ws();
                std::string key = str();
                ws(); p++; // ':'
                Value item = parse();
                obj.push_back({std::move(key), std::move(item)});
                ws();
                if (s[p++] != ',') return {std::move(obj)}; // '}'
            }
        }
        if (ch == '[') {
            Array arr;
            p++; ws();
            if (s[p] == ']') { p++; return {std::move(arr)}; }
            for (;;) {
                arr.push_back(parse());
                ws();
                if (s[p++] != ',') return {std::move(arr)}; // ']'
            }
        }
        if (ch == '"') return {str()};
        if (ch == 't') { p += 4; return {true}; }
        if (ch == 'f') { p += 5; return {false}; }
        if (ch == 'n') { p += 4; return {nullptr}; }
        size_t start = p;
        bool real = false;
        while (p < s.size() && std::string_view("+-0123456789.eE").find(s[p]) != std::string_view::npos) {
            if (s[p] == '.' || s[p] == 'e' || s[p] == 'E') real = true;
            p++;
        }
        const char *b = s.data() + start + (s[start] == '+'), *e = s.data() + p;
        if (real) { double f = 0; std::from_chars(b, e, f); return {f}; }
        int64_t i = 0;
        std::from_chars(b, e, i);
        return {i};
    }
};

static void write_str(std::string &out, std::string_view s) {
    static const char hex[] = "0123456789abcdef";
    out += '"';
    for (unsigned char ch : s) {
        if (ch == '"' || ch == '\\') { out += '\\'; out += (char)ch; }
        else if (ch < 0x20) { out += "\\u00"; out += hex[ch >> 4]; out += hex[ch & 15]; }
        else out += (char)ch;
    }
    out += '"';
}
template <class... F> struct overload : F... { using F::operator()...; };
static void write_value(std::string &out, const Value &v) {
    std::visit(overload{
        [&](std::nullptr_t) { out += "null"; },
        [&](bool b) { out += b ? "true" : "false"; },
        [&](int64_t i) { out += std::to_string(i); },
        [&](double f) { char tmp[32]; out.append(tmp, (size_t)std::snprintf(tmp, sizeof tmp, "%.17g", f)); },
        [&](const std::string &s) { write_str(out, s); },
        [&](const Array &a) {
            out += '[';
            for (size_t i = 0; i < a.size(); i++) { if (i) out += ','; write_value(out, a[i]); }
            out += ']';
        },
        [&](const Object &o) {
            out += '{';
            for (size_t i = 0; i < o.size(); i++) {
                if (i) out += ',';
                write_str(out, o[i].key);
                out += ':';
                write_value(out, o[i].value);
            }
            out += '}';
        },
    }, v.v);
}
struct Totals { uint64_t ints = 0, strings = 0, nodes = 0; };
static void walk(const Value &v, Totals &t) {
    t.nodes++;
    if (auto i = std::get_if<int64_t>(&v.v)) t.ints += (uint64_t)*i;
    else if (auto s = std::get_if<std::string>(&v.v)) t.strings += s->size();
    else if (auto a = std::get_if<Array>(&v.v)) for (const Value &item : *a) walk(item, t);
    else if (auto o = std::get_if<Object>(&v.v)) for (const Member &m : *o) { t.strings += m.key.size(); walk(m.value, t); }
}
int main() {
    const uint64_t n = 92000;
    std::string text = "{\"items\":[";
    for (uint64_t i = 0; i < n; i++) {
        if (i > 0) text += ',';
        text += "{\"id\":" + std::to_string(i) + ",\"name\":\"item" + std::to_string(i) + "\",\"tags\":[\"t" +
                std::to_string(i % 7) + "\",\"u" + std::to_string(i % 13) + "\"],\"value\":" +
                std::to_string(i * 37 % 100003) + ",\"nested\":";
        text += "{\"a\":" + std::to_string(i % 100) + ",\"b\":[1,2,3],\"label\":\"n" + std::to_string(i % 1000) + "\"";
        text += "}}";
    }
    text += "]}";
    Value doc = Parser(text).parse();
    Totals t;
    walk(doc, t);
    std::string out;
    write_value(out, doc);
    std::printf("%zu %llu %llu %llu %zu\n", text.size(), (unsigned long long)t.nodes, (unsigned long long)t.ints,
                (unsigned long long)t.strings, out.size());
}
