// C++ twin of bench/strings.grl: std::string built with += and std::to_string, split with
// std::string_view::find, numbers parsed with std::from_chars (integer and double; the double
// overload rounds correctly, like strtod). Same text, same sums in the same order, same output.
// clang++ -std=c++20 -O2 -ffp-contract=off strings.cpp
#include <charconv>
#include <cstdint>
#include <cstdio>
#include <string>
#include <string_view>
static uint64_t xs(uint64_t x) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; return x; }
int main() {
    const uint64_t n = 1000000;
    std::string text, out;
    uint64_t x = 88172645463325252ull;
    for (uint64_t i = 0; i < n; i++) {
        x = xs(x);
        uint64_t a = x % 100000, b = (x >> 20) % 100000;
        text += 'k';
        text += std::to_string(i);
        text += ',';
        text += std::to_string(a);
        text += ',';
        text += std::to_string(b / 100);
        text += '.';
        text += std::to_string((b % 100) / 10);
        text += std::to_string(b % 10);
        text += '\n';
    }
    uint64_t int_sum = 0;
    double float_sum = 0;
    std::string_view rest = text;
    while (!rest.empty()) {
        size_t nl = rest.find('\n');
        std::string_view line = rest.substr(0, nl);
        rest.remove_prefix(nl == std::string_view::npos ? rest.size() : nl + 1);
        size_t c1 = line.find(','), c2 = line.find(',', c1 + 1);
        uint64_t a = 0;
        double f = 0;
        std::from_chars(line.data() + c1 + 1, line.data() + c2, a);
        std::from_chars(line.data() + c2 + 1, line.data() + line.size(), f);
        int_sum += a;
        float_sum = float_sum + f;
        out += std::to_string(a * 2);
        out += ':';
        out += std::to_string(c1);
        out += ';';
    }
    uint64_t h = 14695981039346656037ull;
    for (unsigned char ch : out) h = (h ^ ch) * 1099511628211ull;
    std::printf("%llu %.17g %zu %llu\n", (unsigned long long)int_sum, float_sum, out.size(), (unsigned long long)h);
}
