/* The C half of the book's record-pointer example. Freestanding: no libc, no headers. */
struct app_info {
    unsigned api_version;
    unsigned flags;
};
struct create_info {
    unsigned s_type;
    unsigned pad;
    const struct app_info *p_app;
    unsigned count;
};
long long book_create(const struct create_info *info) {
    return (long long)info->p_app->api_version + (long long)info->count;
}
long long book_fill(struct app_info *app) {
    long long seen = (long long)app->flags;
    app->api_version = 7;
    return seen;
}
