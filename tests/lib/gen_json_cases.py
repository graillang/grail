#!/usr/bin/env python3
# Writes tests/lib/json_cases.grl: JSONTestSuite-style must-accept/must-reject inputs (written out
# here, not downloaded; i_ cases are listed with the strict choice lib/json.grl makes) and decimal
# strings with the f64 bit patterns CPython's correctly rounded float() gives them. In the case
# tables, %n %t %r %xHH %UXXXXXXXX stand for raw bytes; everything else is literal JSON text.
# Deterministic: rerun after editing and commit both files.
import decimal, math, os, random, struct

def lit(b):
    try: b.decode('utf-8')
    except UnicodeDecodeError: return None
    out=''
    for ch in b.decode('utf-8'):
        o=ord(ch)
        if ch=='"': out+='\\"'
        elif ch=='\\': out+='\\\\'
        elif ch=='\n': out+='\\n'
        elif ch=='\r': out+='\\r'
        elif ch=='\t': out+='\\t'
        elif o==0: out+='\\x00'
        elif o<32 or o==127: out+='\\x%02x'%o
        else: out+=ch
    return '"'+out+'"'
def arg(b):
    l=lit(b)
    if l is not None: return l
    return 'u8['+','.join(str(x) for x in b)+']'
accept=r'''
y_array_arraysWithSpaces	[[]   ]
y_array_empty-string	[""]
y_array_empty	[]
y_array_ending_with_newline	["a"]
y_array_false	[false]
y_array_heterogeneous	[null, 1, "1", {}]
y_array_null	[null]
y_array_with_1_and_newline	[1%n]
y_array_with_leading_space	 [1]
y_array_with_several_null	[1,null,null,null,2]
y_array_with_trailing_space	[2] 
y_number	[123e65]
y_number_0e+1	[0e+1]
y_number_0e1	[0e1]
y_number_after_space	[ 4]
y_number_double_close_to_zero	[-0.000000000000000000000000000000000000000000000000000000000000000000000000000001]
y_number_int_with_exp	[20e1]
y_number_minus_zero	[-0]
y_number_negative_int	[-123]
y_number_negative_one	[-1]
y_number_negative_zero	[-0]
y_number_real_capital_e	[1E22]
y_number_real_capital_e_neg_exp	[1E-2]
y_number_real_capital_e_pos_exp	[1E+2]
y_number_real_exponent	[123e45]
y_number_real_fraction_exponent	[123.456e78]
y_number_real_neg_exp	[1e-2]
y_number_real_pos_exponent	[1e+2]
y_number_simple_int	[123]
y_number_simple_real	[123.456789]
i_number_huge_exp_neg	[123.456e-789]
i_number_very_big_negative_int	[-237462374673276894279832749832423479823246327846]
i_number_too_big_pos_int	[100000000000000000000]
i_number_double_huge_neg_exp	[1.5e-9999]
y_object	{"asd":"sdf", "dfg":"fgh"}
y_object_basic	{"asd":"sdf"}
y_object_duplicated_key_and_value_distinct_keys	{"a":"b","b":"b"}
y_object_empty	{}
y_object_empty_key	{"":0}
y_object_escaped_null_in_key	{"foo\u0000bar": 42}
y_object_extreme_numbers	{ "min": -1.0e+28, "max": 1.0e+28 }
y_object_long_strings	{"x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}], "id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
y_object_simple	{"a":[]}
y_object_string_unicode	{"title":"\u041f\u043e\u043b\u0442\u043e\u0440\u0430 \u0417\u0435\u043c\u043b\u0435\u043a\u043e\u043f\u0430" }
y_object_with_newlines	{%n"a": "b"%n}
y_string_1_2_3_bytes_UTF-8_sequences	["\u0060\u012a\u12AB"]
y_string_accepted_surrogate_pair	["\uD801\udc37"]
y_string_accepted_surrogate_pairs	["\ud83d\ude39\ud83d\udc8d"]
y_string_allowed_escapes	["\"\\\/\b\f\n\r\t"]
y_string_backslash_and_u_escaped_zero	["\\u0000"]
y_string_backslash_doublequotes	["\""]
y_string_comments	["a/*b*/c/*d//e"]
y_string_double_escape_a	["\\a"]
y_string_double_escape_n	["\\n"]
y_string_escaped_control_character	["\u0012"]
y_string_escaped_noncharacter	["\uFFFF"]
y_string_in_array	["asd"]
y_string_in_array_with_leading_space	[ "asd"]
y_string_last_surrogates_1_and_2	["\uDBFF\uDFFF"]
y_string_nbsp_uescaped	["new\u00A0line"]
y_string_nonCharacterInUTF-8_U+10FFFF	["%U0010ffff"]
y_string_nonCharacterInUTF-8_U+FFFF	["%U0000ffff"]
y_string_null_escape	["\u0000"]
y_string_one-byte-utf-8	["\u002c"]
y_string_pi	["%U000003c0"]
y_string_reservedCharacterInUTF-8_U+1BFFF	["%U0001bfff"]
y_string_simple_ascii	["asd "]
y_string_space	" "
y_string_surrogates_U+1D11E_MUSICAL_SYMBOL_G_CLEF	["\uD834\uDd1e"]
y_string_three-byte-utf-8	["\u0821"]
y_string_two-byte-utf-8	["\u0123"]
y_string_u+2028_line_sep	["%U00002028"]
y_string_u+2029_par_sep	["%U00002029"]
y_string_uEscape	["\u0061\u30af\u30EA\u30b9"]
y_string_uescaped_newline	["new\u000Aline"]
y_string_unescaped_char_delete	["%x7f"]
y_string_unicode	["\uA66D"]
y_string_unicodeEscapedBackslash	["\u005C"]
y_string_unicode_2	["%U00002342%U00003234%U00002342"]
y_string_unicode_U+10FFFE_nonchar	["\uDBFF\uDFFE"]
y_string_unicode_U+1FFFE_nonchar	["\uD83F\uDFFE"]
y_string_unicode_U+200B_ZERO_WIDTH_SPACE	["\u200B"]
y_string_unicode_U+2064_invisible_plus	["\u2064"]
y_string_unicode_U+FDD0_nonchar	["\uFDD0"]
y_string_unicode_U+FFFE_nonchar	["\uFFFE"]
y_string_unicode_escaped_double_quote	["\u0022"]
y_string_utf8	["%U000020ac%U0001d11e"]
y_string_with_del_character	["a%x7fa"]
y_structure_lonely_false	false
y_structure_lonely_int	42
y_structure_lonely_negative_real	-0.1
y_structure_lonely_null	null
y_structure_lonely_string	"asd"
y_structure_lonely_true	true
y_structure_string_empty	""
y_structure_trailing_newline	["a"]%n
y_structure_true_in_array	[true]
y_structure_whitespace_array	 [] 
y_structure_whitespace_all_four	%t%r%n [%t%r%n 1%t%r%n ,%t%r%n {%t%r%n "a"%t%r%n :%t%r%n 2%t%r%n }%t%r%n ]%t%r%n 
'''
reject=r'''
n_array_1_true_without_comma	[1 true]
n_array_a_invalid_utf8	[a%xe5]
n_array_colon_instead_of_comma	["": 1]
n_array_comma_after_close	[""],
n_array_comma_and_number	[,1]
n_array_double_comma	[1,,2]
n_array_double_extra_comma	["x",,]
n_array_extra_close	["x"]]
n_array_extra_comma	["",]
n_array_incomplete	["x"
n_array_incomplete_invalid_value	[x
n_array_inner_array_no_comma	[3[4]]
n_array_invalid_utf8	[%xff]
n_array_items_separated_by_semicolon	[1:2]
n_array_just_comma	[,]
n_array_just_minus	[-]
n_array_missing_value	[   , ""]
n_array_newlines_unclosed	["a",%n4%n,1,
n_array_number_and_comma	[1,]
n_array_number_and_several_commas	[1,,]
n_array_spaces_vertical_tab_formfeed	["%x0ba"%x0c]
n_array_star_inside	[*]
n_array_unclosed	[""
n_array_unclosed_trailing_comma	[1,
n_array_unclosed_with_new_lines	[1,%n1%n,1
n_array_unclosed_with_object_inside	[{}
n_incomplete_false	[fals]
n_incomplete_null	[nul]
n_incomplete_true	[tru]
n_multidigit_number_then_00	123%x00
n_number_++	[++1234]
n_number_+1	[+1]
n_number_+Inf	[+Inf]
n_number_-01	[-01]
n_number_-1.0.	[-1.0.]
n_number_-2.	[-2.]
n_number_-NaN	[-NaN]
n_number_.-1	[.-1]
n_number_.2e-3	[.2e-3]
n_number_0.1.2	[0.1.2]
n_number_0.3e+	[0.3e+]
n_number_0.3e	[0.3e]
n_number_0.e1	[0.e1]
n_number_0_capital_E+	[0E+]
n_number_0_capital_E	[0E]
n_number_0e+	[0e+]
n_number_0e	[0e]
n_number_1.0e+	[1.0e+]
n_number_1.0e-	[1.0e-]
n_number_1.0e	[1.0e]
n_number_1_000	[1 000.0]
n_number_1eE2	[1eE2]
n_number_2.e+3	[2.e+3]
n_number_2.e-3	[2.e-3]
n_number_2.e3	[2.e3]
n_number_9.e+	[9.e+]
n_number_Inf	[Inf]
n_number_NaN	[NaN]
n_number_U+FF11_fullwidth_digit_one	[%U0000ff11]
n_number_expression	[1+2]
n_number_hex_1_digit	[0x1]
n_number_hex_2_digits	[0x42]
n_number_infinity	[Infinity]
n_number_invalid+-	[0e+-1]
n_number_invalid-negative-real	[-123.123foo]
n_number_invalid-utf-8-in-bigger-int	[123%xe5]
n_number_invalid-utf-8-in-exponent	[1e1%xe5]
n_number_invalid-utf-8-in-int	[0%xe5]
n_number_minus_infinity	[-Infinity]
n_number_minus_sign_with_trailing_garbage	[-foo]
n_number_minus_space_1	[- 1]
n_number_neg_int_starting_with_zero	[-012]
n_number_neg_real_without_int_part	[-.123]
n_number_neg_with_garbage_at_end	[-1x]
n_number_real_garbage_after_e	[1ea]
n_number_real_with_invalid_utf8_after_e	[1e%xe5]
n_number_real_without_fractional_part	[1.]
n_number_starting_with_dot	[.123]
n_number_with_alpha	[1.2a-3]
n_number_with_alpha_char	[1.8011670033376514H-308]
n_number_with_leading_zero	[012]
n_number_too_big_for_f64	[1e400]
n_number_too_big_negative	[-1.8e308]
n_object_bad_value	["x", truth]
n_object_bracket_key	{[: "x"}
n_object_comma_instead_of_colon	{"x", null}
n_object_double_colon	{"x"::"b"}
n_object_emoji	{%U0001f1e8%U0001f1ed}
n_object_garbage_at_end	{"a":"a" 123}
n_object_key_with_single_quotes	{key: 'value'}
n_object_lone_continuation_byte_in_key_and_trailing_comma	{"%xb9":"0",}
n_object_missing_colon	{"a" b}
n_object_missing_key	{:"b"}
n_object_missing_semicolon	{"a" "b"}
n_object_missing_value	{"a":
n_object_no-colon	{"a"
n_object_non_string_key	{1:1}
n_object_non_string_key_but_huge_number_instead	{9999E9999:1}
n_object_repeated_null_null	{null:null,null:null}
n_object_several_trailing_commas	{"id":0,,,,,}
n_object_single_quote	{'a':0}
n_object_trailing_comma	{"id":0,}
n_object_trailing_comment	{"a":"b"}/**/
n_object_trailing_comment_open	{"a":"b"}/**//
n_object_trailing_comment_slash_open	{"a":"b"}//
n_object_trailing_comment_slash_open_incomplete	{"a":"b"}/
n_object_two_commas_in_a_row	{"a":"b",,"c":"d"}
n_object_unquoted_key	{a: "b"}
n_object_unterminated-value	{"a":"a
n_object_with_single_string	{ "foo" : "bar", "a" }
n_object_with_trailing_garbage	{"a":"b"}#
n_object_equals_instead_of_colon	{"a"=1}
n_single_space	 
n_string_1_surrogate_then_escape	["\uD800\"]
n_string_1_surrogate_then_escape_u	["\uD800\u"]
n_string_1_surrogate_then_escape_u1	["\uD800\u1"]
n_string_1_surrogate_then_escape_u1x	["\uD800\u1x"]
n_string_accentuated_char_no_quotes	[%U000000e9]
n_string_backslash_00	["\%x00"]
n_string_escape_x	["\x00"]
n_string_escaped_backslash_bad	["\\\"]
n_string_escaped_ctrl_char_tab	["\%t"]
n_string_escaped_emoji	["\%U0001f300"]
n_string_incomplete_escape	["\"]
n_string_incomplete_escaped_character	["\u00A"]
n_string_incomplete_surrogate	["\uD834\uDd"]
n_string_incomplete_surrogate_escape_invalid	["\uD800\uD800\x"]
n_string_invalid-utf-8-in-escape	["\u%xe5"]
n_string_invalid_backslash_esc	["\a"]
n_string_invalid_unicode_escape	["\uqqqq"]
n_string_invalid_utf8_after_escape	["\%xe5"]
n_string_leading_uescaped_thinspace	[\u0020"asd"]
n_string_no_quotes_with_bad_escape	[\n]
n_string_single_doublequote	"
n_string_single_quote	['single quote']
n_string_single_string_no_double_quotes	abc
n_string_start_escape_unclosed	["\
n_string_unescaped_ctrl_char	["a%x00a"]
n_string_unescaped_newline	["new%nline"]
n_string_unescaped_tab	["%t"]
n_string_unicode_CapitalU	"\UA66D"
n_string_with_trailing_garbage	""x
i_string_1st_surrogate_but_2nd_missing	["\uDADA"]
i_string_1st_valid_surrogate_2nd_invalid	["\uD888\u1234"]
i_string_incomplete_surrogate_and_escape_valid	["\uD800\n"]
i_string_incomplete_surrogate_pair	["\uDd1ea"]
i_string_incomplete_surrogates_escape_valid	["\uD800\uD800\n"]
i_string_invalid_lonely_surrogate	["\ud800"]
i_string_invalid_surrogate	["\ud800abc"]
i_string_inverted_surrogates_U+1D11E	["\uDd1e\uD834"]
i_string_lone_second_surrogate	["\uDFAA"]
i_string_UTF-16LE_with_BOM	%xff%xfe[%x00"%x00%xe9%x00"%x00]%x00
i_string_UTF-8_invalid_sequence	["%xe6%x97%xa5%xd1%x88%xfa"]
i_string_UTF8_surrogate_U+D800	["%xed%xa0%x80"]
i_string_invalid_utf-8	["%xff"]
i_string_iso_latin_1	["%xe9"]
i_string_lone_utf8_continuation_byte	["%x81"]
i_string_not_in_unicode_range	["%xf4%xbf%xbf%xbf"]
i_string_overlong_sequence_2_bytes	["%xc0%xaf"]
i_string_overlong_sequence_6_bytes	["%xfc%x83%xbf%xbf%xbf%xbf"]
i_string_overlong_sequence_6_bytes_null	["%xfc%x80%x80%x80%x80%x80"]
i_string_overlong_3_bytes	["%xe0%x80%xaf"]
i_string_truncated-utf-8	["%xe0%xff"]
i_string_truncated_at_end	["%xe6%x97
i_structure_UTF-8_BOM_empty_object	%xef%xbb%xbf{}
n_structure_angle_bracket_.	<.>
n_structure_angle_bracket_null	[<null>]
n_structure_array_trailing_garbage	[1]x
n_structure_array_with_extra_array_close	[1]]
n_structure_array_with_unclosed_string	["asd]
n_structure_ascii-unicode-identifier	a%U000000e5
n_structure_capitalized_True	[True]
n_structure_close_unopened_array	1]
n_structure_comma_instead_of_closing_brace	{"x": true,
n_structure_double_array	[][]
n_structure_end_array	]
n_structure_incomplete_UTF8_BOM	%xef%xbb{}
n_structure_lone-invalid-utf-8	%xe5
n_structure_lone-open-bracket	[
n_structure_no_data	
n_structure_null-byte-outside-string	[%x00]
n_structure_number_with_trailing_garbage	2@
n_structure_object_followed_by_closing_object	{}}
n_structure_object_unclosed_no_value	{"":
n_structure_object_with_comment	{"a":/*comment*/"b"}
n_structure_object_with_trailing_garbage	{"a": true} "x"
n_structure_open_array_apostrophe	['
n_structure_open_array_comma	[,
n_structure_open_array_open_object	[{
n_structure_open_array_open_string	["a
n_structure_open_array_string	["a"
n_structure_open_object	{
n_structure_open_object_close_array	{]
n_structure_open_object_comma	{,
n_structure_open_object_open_array	{[
n_structure_open_object_open_string	{"a
n_structure_open_object_string_with_apostrophes	{'a'
n_structure_single_star	*
n_structure_trailing_#	{"a":"b"}#{}
n_structure_U+2060_word_joined	[%U00002060]
n_structure_uescaped_LF_before_string	[\u000A""]
n_structure_unclosed_array	[1
n_structure_unclosed_array_partial_null	[ false, nul
n_structure_unclosed_array_unfinished_false	[ true, fals
n_structure_unclosed_array_unfinished_true	[ false, tru
n_structure_unclosed_object	{"asd":"asd"
n_structure_unicode-identifier	%U000000e5
n_structure_whitespace_U+2060_word_joiner	[%U00002060]
n_structure_whitespace_formfeed	[%x0c]
n_structure_whitespace_nbsp	[%U000000a0]
n_structure_two_values	1 2
n_structure_comment_line	// x%n1
'''
def unesc(s):
    out=bytearray();i=0
    while i<len(s):
        if s[i]=='%':
            c=s[i+1]
            if c=='n': out+=b'\n';i+=2;continue
            if c=='t': out+=b'\t';i+=2;continue
            if c=='r': out+=b'\r';i+=2;continue
            if c=='x': out.append(int(s[i+2:i+4],16));i+=4;continue
            if c=='U': out+=chr(int(s[i+2:i+10],16)).encode();i+=10;continue
        out+=s[i].encode();i+=1
    return bytes(out)
def cases(block):
    out=[]
    for line in block.split('\n'):
        if not line: continue
        name,_,body=line.partition('\t')
        out.append((name,unesc(body)))
    return out
A=cases(accept);R=cases(reject)

random.seed(8259)
def fbits(x): return struct.unpack('<Q',struct.pack('<d',x))[0]
floats=[]
def addf(s):
    v=float(s)
    floats.append((s, 'out' if math.isinf(v) else fbits(v)))
for s in ['0.0','-0.0','1.0','0.1','0.2','0.3','1e23','8.98846567431158e307','1.7976931348623157e308','1.7976931348623158e308',
    '1.7976931348623159e308','-1.7976931348623159e308','2.2250738585072011e-308','2.2250738585072012e-308','2.2250738585072014e-308',
    '4.9406564584124654e-324','2.4703282292062327e-324','2.4703282292062328e-324','1e-400','9007199254740993','9007199254740992.5',
    '9007199254740993.0000000000000001','1.00000000000000011102230246251565404236316680908203125',
    '1.00000000000000011102230246251565404236316680908203124','1.00000000000000011102230246251565404236316680908203126',
    '1.00000000000000011102230246251565404236316680908203125'+'0'*1000+'1','123456789012345678901234567890e-30',
    '0.000000000000000000000000000000000000000000000000000000000000000000000000000001','7.2057594037927933e16',
    '3.4028234663852886e38','1e22','1e-22','123e-24','5e-324','2.225073858507201136057409796709131975934819546351645648e-308',
    '6.631236846766476e-316','3.2378839133029012e-319','1'+'0'*400+'e-400','0.'+'0'*500+'1e500','2e308','1e309','-1e-400']:
    addf(s)
# exact midpoints between neighbouring doubles, and a hair either side
for k in range(60):
    x=random.choice([random.uniform(0,1),random.uniform(1,1e10),10**random.uniform(-307,308),5e-324*random.randint(1,1<<52)])
    y=math.nextafter(x,math.inf)
    mid=(decimal.Decimal(x)+decimal.Decimal(y))/2
    with decimal.localcontext() as c:
        c.prec=2000
        mid=(decimal.Decimal(x)+decimal.Decimal(y))/2
        s=format(mid,'e')
        addf(s)
        eps=decimal.Decimal(10)**(mid.adjusted()-900)
        addf(format(mid+eps,'e'));addf(format(mid-eps,'e'))
for k in range(150):
    nd=random.randint(1,25);digits=''.join(random.choice('0123456789') for _ in range(nd)).lstrip('0') or '0'
    e=random.randint(-340,320);s=digits+'e'+str(e)
    if random.random()<0.3: s='-'+s
    addf(s)
for k in range(80):
    x=struct.unpack('<d',struct.pack('<Q',random.getrandbits(63)))[0]
    if math.isfinite(x): addf(repr(x)); addf('%.17e'%x); addf('%.25e'%x)

L=[]
w=L.append
w('module json_cases;');w('use json;')
w('// Generated by a script from JSONTestSuite-style cases (inline, not downloaded) plus decimal')
w('// strings whose correctly rounded f64 bit patterns were computed by CPython.')
w('''fn accept(name:&[u8],text:&[u8])->u64{
    match json::parse(&text){
        v: json::Value=>{
            once:=json::to_text(&v);
            match json::parse(&once){
                again: json::Value=>{
                    if !json::equal(&v,&again){println("FAIL {}: round trip changed value {}",name.text(),once);return 1;}
                    twice:=json::to_text(&again);if twice!=once{println("FAIL {}: unstable text {}",name.text(),twice);return 1;}
                    pretty:=json::to_pretty(&v);
                    match json::parse(&pretty){
                        p: json::Value=>{if !json::equal(&v,&p){println("FAIL {}: pretty round trip",name.text());return 1;}return 0;},
                        e: json::Error=>{println("FAIL {}: pretty reparse {}",name.text(),e.show());return 1;}
                    }
                },
                e: json::Error=>{println("FAIL {}: reparse {} of {}",name.text(),e.show(),once);return 1;}
            }
        },
        e: json::Error=>{println("FAIL {}: rejected: {}",name.text(),e.show());return 1;}
    }
}
fn reject(name:&[u8],text:&[u8])->u64{
    match json::parse(&text){
        v: json::Value=>{println("FAIL {}: accepted as {}",name.text(),json::to_text(&v));return 1;},
        e: json::Error=>{if e.offset>text.len(){println("FAIL {}: offset past end",name.text());return 1;}return 0;}
    }
}
fn float_case(text:&[u8],want:u64)->u64{
    match json::parse(&text){
        v: json::Value=>{
            got:=bits(v.as_f64()!);
            if got!=want{println("FAIL float {}: bits {} want {}",text.text(),got,want);return 1;}
            return 0;
        },
        e: json::Error=>{println("FAIL float {}: {}",text.text(),e.show());return 1;}
    }
}
fn float_out_of_range(text:&[u8])->u64{
    match json::parse(&text){
        v: json::Value=>{println("FAIL float {}: accepted",text.text());return 1;},
        e: json::Error=>{if e.show()!="json: number out of range at byte 0"{println("FAIL float {}: {}",text.text(),e.show());return 1;}return 0;}
    }
}''')
def chunked(public,calls):
    names=[]
    for k in range(0,len(calls),40):
        nm=f'{public}_{k//40}';names.append(nm)
        w(f'fn {nm}()->u64{{\n    mut f:u64=0;')
        for c in calls[k:k+40]: w('    f+='+c+';')
        w('    return f;\n}')
    w(f'pub fn {public}()->u64{{return '+'+'.join(n+'()' for n in names)+';}')
chunked('suite_accept',[f'accept("{n}",{arg(b)})' for n,b in A])
chunked('suite_reject',[f'reject("{n}",{arg(b)})' for n,b in R])
chunked('floats',[(f'float_out_of_range("{s}")' if b=='out' else f'float_case("{s}",{b})') for s,b in floats])
w(f'pub const ACCEPTED: u64 = {len(A)};\npub const REJECTED: u64 = {len(R)};\npub const FLOATS: u64 = {len(floats)};')
open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'json_cases.grl'),'w').write('\n'.join(L)+'\n')
print(len(A),len(R),len(floats))
