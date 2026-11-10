/* words_shim.c - C functions with seven, eight and nine word arguments.
 *
 * Each result weights every argument by its position, so a dropped, duplicated or misplaced word
 * changes the sum: the arguments past the integer register file are the interesting ones.
 * x86-64 SysV has six integer argument registers (the seventh word is the first stack slot),
 * AAPCS64 and RISC-V 64 have eight (the ninth word is the first stack slot).
 */
long long c_words7(long long a0, long long a1, long long a2, long long a3, long long a4,
                   long long a5, long long a6)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6;
}
long long c_words8(long long a0, long long a1, long long a2, long long a3, long long a4,
                   long long a5, long long a6, long long a7)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6 + 8 * a7;
}
long long c_words9(long long a0, long long a1, long long a2, long long a3, long long a4,
                   long long a5, long long a6, long long a7, long long a8)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6 + 8 * a7 + 9 * a8;
}
/* Position matters, not just the multiset of arguments: the low digit of each argument says where
 * it arrived. Reading the wrong register or stack slot moves a digit. */
long long c_words9_order(long long a0, long long a1, long long a2, long long a3, long long a4,
                         long long a5, long long a6, long long a7, long long a8)
{
    return ((((((((a0 * 10 + a1) * 10 + a2) * 10 + a3) * 10 + a4) * 10 + a5) * 10 + a6) * 10 + a7)
            * 10 + a8);
}
/* Eight narrow words: a 32-bit argument in every integer register of AAPCS64/RISC-V 64 and the
 * seventh/eighth on the stack for SysV. */
int c_words8n(int a0, int a1, int a2, int a3, int a4, int a5, int a6, int a7)
{
    return a0 + 2 * a1 + 3 * a2 + 4 * a3 + 5 * a4 + 6 * a5 + 7 * a6 + 8 * a7;
}

/* C calls a Grail callback with eight word arguments. AArch64 and RISC-V 64 pass all eight in
 * x0-x7 / a0-a7; x86-64 SysV would pass the seventh and eighth on the stack, which the callback
 * prologue does not read, so the compiler refuses that shape there (tests/ffi/callback_words.grl).
 */
typedef long long (*words_callback)(long long, long long, long long, long long, long long,
                                    long long, long long, long long);
long long c_call_words8(words_callback cb) { return cb(1, 2, 3, 4, 5, 6, 7, 8); }
