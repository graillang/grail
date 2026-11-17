// The C twin of bench/bintrees.grl: binary trees, malloc and free per node.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
typedef struct Node { struct Node *left, *right; } Node;
static Node *make(uint64_t depth) {
    Node *n = malloc(sizeof *n);
    if (depth == 0) { n->left = n->right = NULL; }
    else { n->left = make(depth - 1); n->right = make(depth - 1); }
    return n;
}
static uint64_t check(const Node *t) { return t ? 1 + check(t->left) + check(t->right) : 0; }
static void drop(Node *t) { if (t) { drop(t->left); drop(t->right); free(t); } }
int main(void) {
    const uint64_t max = 16;
    Node *stretch = make(max + 1);
    printf("%llu\n", (unsigned long long)check(stretch));
    drop(stretch);
    Node *long_lived = make(max);
    for (uint64_t d = 4; d <= max; d += 2) {
        uint64_t iterations = 1ull << (max - d + 4), total = 0;
        for (uint64_t i = 0; i < iterations; i++) { Node *t = make(d); total += check(t); drop(t); }
        printf("%llu %llu\n", (unsigned long long)iterations, (unsigned long long)total);
    }
    printf("%llu\n", (unsigned long long)check(long_lived));
    drop(long_lived);
    return 0;
}
