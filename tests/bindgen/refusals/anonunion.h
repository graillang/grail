/* An anonymous union member would have to be flattened into the container. */
struct anon_holder {
    int kind;
    union {
        int as_int;
        float as_float;
    };
};
