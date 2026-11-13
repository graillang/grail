/* __attribute__((packed)) moves members off their natural alignment. */
struct packed_pair {
    char tag;
    int value;
} __attribute__((packed));
