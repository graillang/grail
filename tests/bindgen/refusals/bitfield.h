/* A bit-field has no spelling in a Grail extern record. */
struct bf_state {
    unsigned int flag_a : 1;
    unsigned int flag_b : 3;
    int plain;
};
