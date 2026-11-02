#include "grail_rt.c"
static G f_grailc_same(G v0,G v1);
static G f_grailc_div(G v0,G v1);
static G f_grailc_o(G v0,G v1);
static G f_grailc_on(G v0,G v1);
static G f_grailc_ov(G v0,G v1);
static G f_grailc_fresh(G v0);
static G f_grailc_def(G v0);
static G f_grailc_val(G v0,G v1);
static G f_grailc_kind(G v0);
static G f_grailc_next_kind(G v0);
static G f_grailc_kind_at(G v0,G v1);
static G f_grailc_advance(G v0);
static G f_grailc_tok_text(G v0,G v1);
static G f_grailc_is(G v0,G v1);
static G f_grailc_fail(G v0,G v1);
static G f_grailc_eat(G v0,G v1);
static G f_grailc_expect(G v0,G v1);
static G f_grailc_ident(G v0);
static G f_grailc_skip_angle(G v0);
static G f_grailc_skip_braces(G v0);
static G f_grailc_load_file(G v0,G v1);
static G f_grailc_intern(G v0,G v1,G v2);
static G f_grailc_ty_kind(G v0,G v1);
static G f_grailc_ty_arg(G v0,G v1);
static G f_grailc_find_decl(G v0,G v1,G v2);
static G f_grailc_find_func(G v0,G v1,G v2);
static G f_grailc_find_field(G v0,G v1,G v2);
static G f_grailc_field_ty(G v0,G v1,G v2);
static G f_grailc_module_copy(G v0);
static G f_grailc_parse_type(G v0);
static G f_grailc_mangle(G v0,G v1,G v2);
static G f_grailc_decl(G v0,G v1);
static G f_grailc_bind(G v0,G v1,G v2,G v3);
static G f_grailc_func(G v0,G v1,G v2);
static G f_grailc_toplevel(G v0,G v1);
static G f_grailc_deref(G v0,G v1);
static G f_grailc_find_local(G v0,G v1);
static G f_grailc_local_id(G v0,G v1);
static G f_grailc_local_ty(G v0,G v1);
static G f_grailc_pop_locals(G v0,G v1);
static G f_grailc_slot(G v0,G v1,G v2);
static G f_grailc_field_path(G v0,G v1,G v2,G v3);
static G f_grailc_place(G v0);
static G f_grailc_hex(G v0);
static G f_grailc_string_lit(G v0);
static G f_grailc_record(G v0,G v1);
static G f_grailc_variant(G v0,G v1,G v2);
static G f_grailc_call(G v0,G v1,G v2);
static G f_grailc_builtin_id(G v0);
static G f_grailc_apply(G v0,G v1,G v2);
static G f_grailc_one(G v0);
static G f_grailc_two(G v0,G v1);
static G f_grailc_builtin(G v0,G v1);
static G f_grailc_primary(G v0);
static G f_grailc_prec(G v0);
static G f_grailc_propagate(G v0,G v1,G v2);
static G f_grailc_binary(G v0,G v1,G v2,G v3);
static G f_grailc_expr(G v0,G v1);
static G f_grailc_block(G v0);
static G f_grailc_compound_operator(G v0);
static G f_grailc_assignment_ahead(G v0);
static G f_grailc_operand(G v0);
static G f_grailc_statement_call(G v0,G v1,G v2);
static G f_grailc_stmt(G v0);
static G f_grailc_host_fn(G v0,G v1,G v2);
static G f_grailc_main(void);
static G f_lexer_letter(G v0);
static G f_lexer_digit(G v0);
static G f_lexer_whitespace(G v0);
static G f_lexer_punctuation(G v0);
static G f_lexer_pair_kind(G v0,G v1);
static G f_lexer_tokenize(G v0);
static G f_grailc_same(G v0,G v1){{
G v2=rt_len(v0);
G v3=rt_len(v1);
G v4=(v2!=v3);
if(v4){
G v5=0ull;
return v5;
}
G v6=rt_len(v0);
G v7=v6;
for(G v8=0;v8<v7;v8++){
G v9=rt_at(v0,v8);
G v10=rt_at(v1,v8);
G v11=(v9!=v10);
if(v11){
G v12=0ull;
return v12;
}
}
G v13=1ull;
return v13;
}
return 0;}
static G f_grailc_div(G v0,G v1){{
G v2=0ull;
G v3=v2;
G v4=v0;
for(;;){
G v5=(v4<v1);
G v6=0ull;
G v7=(v5==v6);
if(!v7)break;
{
G v8=v1;
G v9=1ull;
G v10=v9;
for(;;){
G v11=(v8+v8);
G v12=(v4<v11);
G v13=0ull;
G v14=(v12==v13);
G v15=(v8+v8);
G v16=(v15<v8);
G v17=0ull;
G v18=(v16==v17);
G v19=(v14&v18);
if(!v19)break;
{
G v20=(v8+v8);
v8=v20;
G v21=(v10+v10);
v10=v21;
}
}
G v22=(v4-v8);
v4=v22;
G v23=(v3+v10);
v3=v23;
}
}
return v3;
}
return 0;}
static G f_grailc_o(G v0,G v1){{
G v2=rt_len(v1);
G v3=v2;
for(G v4=0;v4<v3;v4++){
G v5=*(G*)v0;
G v6=((G*)v5)[3];
G v7=rt_at(v1,v4);
rt_push(v6,v7);
G v8=0;
}
G v9=0;
return v9;
}
return 0;}
static G f_grailc_on(G v0,G v1){{
G v2=9ull;
G v3=(v2<v1);
if(v3){
G v4=10ull;
G v5=f_grailc_div(v1,v4);
G v6=f_grailc_on(v0,v5);
}
G v7=*(G*)v0;
G v8=((G*)v7)[3];
G v9=48ull;
G v10=10ull;
G v11=rt_rem(v1,v10);
G v12=(v9+v11);
rt_push(v8,v12);
G v13=0;
G v14=0;
return v14;
}
return 0;}
static G f_grailc_ov(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[3];
G v4=118ull;
rt_push(v3,v4);
G v5=0;
G v6=f_grailc_on(v0,v1);
G v7=0;
return v7;
}
return 0;}
static G f_grailc_fresh(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[11];
G v3=v2;
G v4=*(G*)v0;
G v5=(G)&((G*)v4)[11];
G v6=1ull;
G v7=(v3+v6);
G v8=rt_xchg(v5,v7);
return v3;
}
return 0;}
static G f_grailc_def(G v0){{
G v1=f_grailc_fresh(v0);
G v2=v1;
G v3=rt_lit("\107\040",2);
G v4=rt_view(v3);
G v5=f_grailc_o(v0,v4);
G v6=f_grailc_ov(v0,v2);
G v7=*(G*)v0;
G v8=((G*)v7)[3];
G v9=61ull;
rt_push(v8,v9);
G v10=0;
return v2;
}
return 0;}
static G f_grailc_val(G v0,G v1){{
G v2=rt_rec(2);
((G*)v2)[0]=v0;
((G*)v2)[1]=v1;
return v2;
}
return 0;}
static G f_grailc_kind(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[2];
G v3=v2;
G v4=*(G*)v0;
G v5=((G*)v4)[1];
G v6=rt_slot(v5,v3);
G v7=v6;
G v8=*(G*)v7;
G v9=((G*)v8)[0];
return v9;
}
return 0;}
static G f_grailc_next_kind(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[2];
G v3=1ull;
G v4=(v2+v3);
G v5=v4;
G v6=f_grailc_kind_at(v0,v5);
return v6;
}
return 0;}
static G f_grailc_kind_at(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[1];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[0];
return v7;
}
return 0;}
static G f_grailc_advance(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[2];
G v3=1ull;
G v4=(v2+v3);
G v5=v4;
G v6=*(G*)v0;
G v7=(G)&((G*)v6)[2];
G v8=rt_xchg(v7,v5);
G v9=0;
return v9;
}
return 0;}
static G f_grailc_tok_text(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[1];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[1];
G v8=v7;
G v9=*(G*)v5;
G v10=((G*)v9)[2];
G v11=v10;
G v12=*(G*)v0;
G v13=((G*)v12)[0];
G v14=rt_view(v13);
G v15=rt_slice(v14,v8,v11);
G v16=rt_copy(v15);
return v16;
}
return 0;}
static G f_grailc_is(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[2];
G v4=v3;
G v5=f_grailc_tok_text(v0,v4);
G v6=v5;
G v7=rt_view(v6);
G v8=f_grailc_same(v7,v1);
return v8;
}
return 0;}
static G f_grailc_fail(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[2];
G v4=v3;
G v5=f_grailc_tok_text(v0,v4);
G v6=v5;
G v7=*(G*)v0;
G v8=((G*)v7)[1];
G v9=rt_slot(v8,v4);
G v10=v9;
G v11=*(G*)v10;
G v12=((G*)v11)[1];
G v13=v12;
G v14=*(G*)v0;
G v15=(G)&((G*)v14)[3];
G v16=rt_new();
G v17=rt_xchg(v15,v16);
G v18=rt_lit("\147\162\141\151\154\143\072\040",8);
G v19=rt_view(v18);
G v20=f_grailc_o(v0,v19);
G v21=f_grailc_o(v0,v1);
G v22=rt_lit("\040\141\164\040\142\171\164\145\040",9);
G v23=rt_view(v22);
G v24=f_grailc_o(v0,v23);
G v25=f_grailc_on(v0,v13);
G v26=rt_lit("\040\156\145\141\162\040\047",7);
G v27=rt_view(v26);
G v28=f_grailc_o(v0,v27);
G v29=rt_view(v6);
G v30=f_grailc_o(v0,v29);
G v31=rt_lit("\047\012",2);
G v32=rt_view(v31);
G v33=f_grailc_o(v0,v32);
G v34=rt_new();
G v35=v34;
G v36=*(G*)v0;
G v37=((G*)v36)[3];
G v38=rt_len(v37);
G v39=v38;
for(G v40=0;v40<v39;v40++){
G v41=*(G*)v0;
G v42=((G*)v41)[3];
G v43=rt_slot(v42,v40);
G v44=*(G*)v43;
rt_pushb(v35,v44);
}
G v45=rt_view(v35);
G v46=f_host_print(v45);
G v47=0ull;
if(!v47)abort();
G v48=0;
return v48;
}
return 0;}
static G f_grailc_eat(G v0,G v1){{
G v2=f_grailc_is(v0,v1);
if(v2){
G v3=f_grailc_advance(v0);
G v4=1ull;
return v4;
}
G v5=0ull;
return v5;
}
return 0;}
static G f_grailc_expect(G v0,G v1){{
G v2=rt_copy(v1);
G v3=v2;
G v4=f_grailc_eat(v0,v1);
G v5=0ull;
G v6=(v4==v5);
if(v6){
G v7=rt_lit("\145\170\160\145\143\164\145\144\040",9);
G v8=v7;
G v9=rt_view(v3);
rt_append(v8,v9);
G v10=rt_view(v8);
G v11=f_grailc_fail(v0,v10);
}
G v12=0;
return v12;
}
return 0;}
static G f_grailc_ident(G v0){{
G v1=f_grailc_kind(v0);
G v2=1ull;
G v3=(v1!=v2);
if(v3){
G v4=rt_lit("\145\170\160\145\143\164\145\144\040\151\144\145\156\164\151\146\151\145\162",19);
G v5=rt_view(v4);
G v6=f_grailc_fail(v0,v5);
}
G v7=*(G*)v0;
G v8=((G*)v7)[2];
G v9=v8;
G v10=f_grailc_tok_text(v0,v9);
G v11=v10;
G v12=f_grailc_advance(v0);
return v11;
}
return 0;}
static G f_grailc_skip_angle(G v0){{
G v1=f_grailc_kind(v0);
G v2=60ull;
G v3=(v1!=v2);
if(v3){
G v4=0;
return v4;
}
G v5=0ull;
G v6=v5;
for(;;){
G v7=1ull;
if(!v7)break;
{
G v8=f_grailc_kind(v0);
G v9=v8;
G v10=60ull;
G v11=(v9==v10);
if(v11){
G v12=1ull;
G v13=(v6+v12);
v6=v13;
}
G v14=62ull;
G v15=(v9==v14);
if(v15){
G v16=1ull;
G v17=(v6-v16);
v6=v17;
}
G v18=0ull;
G v19=(v9==v18);
if(v19){
G v20=rt_lit("\165\156\143\154\157\163\145\144\040\074",10);
G v21=rt_view(v20);
G v22=f_grailc_fail(v0,v21);
}
G v23=f_grailc_advance(v0);
G v24=0ull;
G v25=(v6==v24);
if(v25){
G v26=0;
return v26;
}
}
}
G v27=0;
return v27;
}
return 0;}
static G f_grailc_skip_braces(G v0){{
G v1=0ull;
G v2=v1;
for(;;){
G v3=1ull;
if(!v3)break;
{
G v4=f_grailc_kind(v0);
G v5=v4;
G v6=123ull;
G v7=(v5==v6);
if(v7){
G v8=1ull;
G v9=(v2+v8);
v2=v9;
}
G v10=125ull;
G v11=(v5==v10);
if(v11){
G v12=1ull;
G v13=(v2-v12);
v2=v13;
}
G v14=0ull;
G v15=(v5==v14);
if(v15){
G v16=rt_lit("\165\156\143\154\157\163\145\144\040\173",10);
G v17=rt_view(v16);
G v18=f_grailc_fail(v0,v17);
}
G v19=f_grailc_advance(v0);
G v20=0ull;
G v21=(v2==v20);
if(v21){
G v22=0;
return v22;
}
}
}
G v23=0;
return v23;
}
return 0;}
static G f_grailc_load_file(G v0,G v1){{
G v2=f_host_arg(v1);
G v3=v2;
G v4=rt_view(v3);
G v5=f_host_read_file(v4);
G v6=v5;
G v7=rt_new();
G v8=v7;
G v9=rt_view(v6);
G v10=f_lexer_tokenize(v9);
G v11=v10;
G v12=rt_len(v11);
G v13=v12;
for(G v14=0;v14<v13;v14++){
G v15=rt_slot(v11,v14);
G v16=v15;
G v17=rt_rec(3);
G v18=*(G*)v16;
G v19=((G*)v18)[0];
((G*)v17)[0]=v19;
G v20=*(G*)v16;
G v21=((G*)v20)[2];
((G*)v17)[1]=v21;
G v22=*(G*)v16;
G v23=((G*)v22)[3];
((G*)v17)[2]=v23;
rt_push(v8,v17);
G v24=0;
}
G v25=*(G*)v0;
G v26=(G)&((G*)v25)[1];
G v27=rt_xchg(v26,v8);
G v28=*(G*)v0;
G v29=(G)&((G*)v28)[0];
G v30=rt_xchg(v29,v6);
G v31=*(G*)v0;
G v32=(G)&((G*)v31)[2];
G v33=0ull;
G v34=rt_xchg(v32,v33);
G v35=0;
return v35;
}
return 0;}
static G f_grailc_intern(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[5];
G v5=rt_len(v4);
G v6=v5;
for(G v7=0;v7<v6;v7++){
G v8=*(G*)v0;
G v9=((G*)v8)[5];
G v10=rt_slot(v9,v7);
G v11=v10;
G v12=*(G*)v11;
G v13=((G*)v12)[0];
G v14=(v13==v1);
G v15=*(G*)v11;
G v16=((G*)v15)[1];
G v17=(v16==v2);
G v18=(v14&v17);
if(v18){
return v7;
}
}
G v19=*(G*)v0;
G v20=((G*)v19)[5];
G v21=rt_rec(2);
((G*)v21)[0]=v1;
((G*)v21)[1]=v2;
rt_push(v20,v21);
G v22=0;
G v23=*(G*)v0;
G v24=((G*)v23)[5];
G v25=rt_len(v24);
G v26=1ull;
G v27=(v25-v26);
return v27;
}
return 0;}
static G f_grailc_ty_kind(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[5];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[0];
return v7;
}
return 0;}
static G f_grailc_ty_arg(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[5];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[1];
return v7;
}
return 0;}
static G f_grailc_find_decl(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[6];
G v5=rt_len(v4);
G v6=v5;
for(G v7=0;v7<v6;v7++){
G v8=*(G*)v0;
G v9=((G*)v8)[6];
G v10=rt_slot(v9,v7);
G v11=v10;
G v12=*(G*)v11;
G v13=((G*)v12)[0];
G v14=rt_view(v13);
G v15=f_grailc_same(v14,v1);
G v16=*(G*)v11;
G v17=((G*)v16)[1];
G v18=rt_view(v17);
G v19=f_grailc_same(v18,v2);
G v20=(v15&v19);
if(v20){
G v21=1ull;
G v22=(v7+v21);
return v22;
}
}
G v23=0ull;
return v23;
}
return 0;}
static G f_grailc_find_func(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[8];
G v5=rt_len(v4);
G v6=v5;
for(G v7=0;v7<v6;v7++){
G v8=*(G*)v0;
G v9=((G*)v8)[8];
G v10=rt_slot(v9,v7);
G v11=v10;
G v12=*(G*)v11;
G v13=((G*)v12)[0];
G v14=rt_view(v13);
G v15=f_grailc_same(v14,v1);
G v16=*(G*)v11;
G v17=((G*)v16)[1];
G v18=rt_view(v17);
G v19=f_grailc_same(v18,v2);
G v20=(v15&v19);
if(v20){
G v21=1ull;
G v22=(v7+v21);
return v22;
}
}
G v23=0ull;
return v23;
}
return 0;}
static G f_grailc_find_field(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[6];
G v5=rt_slot(v4,v1);
G v6=v5;
G v7=*(G*)v6;
G v8=((G*)v7)[3];
G v9=v8;
G v10=*(G*)v6;
G v11=((G*)v10)[4];
G v12=v11;
G v13=v12;
for(G v14=0;v14<v13;v14++){
G v15=*(G*)v0;
G v16=((G*)v15)[7];
G v17=(v9+v14);
G v18=rt_slot(v16,v17);
G v19=v18;
G v20=*(G*)v19;
G v21=((G*)v20)[0];
G v22=rt_view(v21);
G v23=f_grailc_same(v22,v2);
if(v23){
return v14;
}
}
G v24=rt_lit("\165\156\153\156\157\167\156\040\146\151\145\154\144\040\157\162\040\166\141\162\151\141\156\164",24);
G v25=rt_view(v24);
G v26=f_grailc_fail(v0,v25);
G v27=0ull;
return v27;
}
return 0;}
static G f_grailc_field_ty(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[6];
G v5=rt_slot(v4,v1);
G v6=v5;
G v7=*(G*)v6;
G v8=((G*)v7)[3];
G v9=(v8+v2);
G v10=v9;
G v11=*(G*)v0;
G v12=((G*)v11)[7];
G v13=rt_slot(v12,v10);
G v14=v13;
G v15=*(G*)v14;
G v16=((G*)v15)[1];
return v16;
}
return 0;}
static G f_grailc_module_copy(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[4];
G v3=rt_view(v2);
G v4=rt_copy(v3);
return v4;
}
return 0;}
static G f_grailc_parse_type(G v0){{
G v1=f_grailc_ident(v0);
G v2=v1;
G v3=rt_lit("\072\072",2);
G v4=rt_view(v3);
G v5=f_grailc_eat(v0,v4);
if(v5){
G v6=f_grailc_ident(v0);
G v7=v6;
G v8=rt_view(v2);
G v9=rt_view(v7);
G v10=f_grailc_find_decl(v0,v8,v9);
G v11=v10;
G v12=0ull;
G v13=(v11==v12);
if(v13){
G v14=rt_lit("\165\156\153\156\157\167\156\040\164\171\160\145",12);
G v15=rt_view(v14);
G v16=f_grailc_fail(v0,v15);
}
G v17=f_grailc_skip_angle(v0);
G v18=8ull;
G v19=1ull;
G v20=(v11-v19);
G v21=f_grailc_intern(v0,v18,v20);
return v21;
}
G v22=rt_view(v2);
G v23=rt_lit("\156\165\155",3);
G v24=rt_view(v23);
G v25=f_grailc_same(v22,v24);
if(v25){
G v26=0ull;
return v26;
}
G v27=rt_view(v2);
G v28=rt_lit("\165\156\151\164",4);
G v29=rt_view(v28);
G v30=f_grailc_same(v27,v29);
if(v30){
G v31=1ull;
return v31;
}
G v32=rt_view(v2);
G v33=rt_lit("\142\171\164\145\163",5);
G v34=rt_view(v33);
G v35=f_grailc_same(v32,v34);
if(v35){
G v36=2ull;
return v36;
}
G v37=rt_view(v2);
G v38=rt_lit("\163\164\162\151\156\147",6);
G v39=rt_view(v38);
G v40=f_grailc_same(v37,v39);
if(v40){
G v41=3ull;
return v41;
}
G v42=rt_view(v2);
G v43=rt_lit("\162\145\141\144",4);
G v44=rt_view(v43);
G v45=f_grailc_same(v42,v44);
G v46=rt_view(v2);
G v47=rt_lit("\155\165\164",3);
G v48=rt_view(v47);
G v49=f_grailc_same(v46,v48);
G v50=(v45+v49);
if(v50){
G v51=f_grailc_skip_angle(v0);
G v52=4ull;
return v52;
}
G v53=rt_view(v2);
G v54=rt_lit("\166\145\143",3);
G v55=rt_view(v54);
G v56=f_grailc_same(v53,v55);
if(v56){
G v57=rt_lit("\074",1);
G v58=rt_view(v57);
G v59=f_grailc_expect(v0,v58);
G v60=f_grailc_parse_type(v0);
G v61=v60;
G v62=rt_lit("\076",1);
G v63=rt_view(v62);
G v64=f_grailc_expect(v0,v63);
G v65=6ull;
G v66=f_grailc_intern(v0,v65,v61);
return v66;
}
G v67=rt_view(v2);
G v68=rt_lit("\162\145\146",3);
G v69=rt_view(v68);
G v70=f_grailc_same(v67,v69);
G v71=rt_view(v2);
G v72=rt_lit("\162\145\146\137\155\165\164",7);
G v73=rt_view(v72);
G v74=f_grailc_same(v71,v73);
G v75=(v70+v74);
if(v75){
G v76=rt_lit("\074",1);
G v77=rt_view(v76);
G v78=f_grailc_expect(v0,v77);
G v79=f_grailc_ident(v0);
G v80=rt_lit("\054",1);
G v81=rt_view(v80);
G v82=f_grailc_expect(v0,v81);
G v83=f_grailc_parse_type(v0);
G v84=v83;
G v85=rt_lit("\076",1);
G v86=rt_view(v85);
G v87=f_grailc_expect(v0,v86);
G v88=7ull;
G v89=f_grailc_intern(v0,v88,v84);
return v89;
}
G v90=f_grailc_module_copy(v0);
G v91=v90;
G v92=rt_view(v91);
G v93=rt_view(v2);
G v94=f_grailc_find_decl(v0,v92,v93);
G v95=v94;
G v96=0ull;
G v97=(v95==v96);
if(v97){
G v98=rt_lit("\165\156\153\156\157\167\156\040\164\171\160\145",12);
G v99=rt_view(v98);
G v100=f_grailc_fail(v0,v99);
}
G v101=f_grailc_skip_angle(v0);
G v102=8ull;
G v103=1ull;
G v104=(v95-v103);
G v105=f_grailc_intern(v0,v102,v104);
return v105;
}
return 0;}
static G f_grailc_mangle(G v0,G v1,G v2){{
G v3=rt_lit("\146\137",2);
G v4=rt_view(v3);
G v5=f_grailc_o(v0,v4);
G v6=f_grailc_o(v0,v1);
G v7=*(G*)v0;
G v8=((G*)v7)[3];
G v9=95ull;
rt_push(v8,v9);
G v10=0;
G v11=f_grailc_o(v0,v2);
G v12=0;
return v12;
}
return 0;}
static G f_grailc_decl(G v0,G v1){{
G v2=rt_lit("\145\156\165\155",4);
G v3=rt_view(v2);
G v4=f_grailc_is(v0,v3);
G v5=v4;
G v6=f_grailc_advance(v0);
G v7=f_grailc_ident(v0);
G v8=v7;
G v9=f_grailc_skip_angle(v0);
G v10=2ull;
G v11=(v1!=v10);
if(v11){
G v12=1ull;
G v13=(v1==v12);
if(v13){
G v14=f_grailc_module_copy(v0);
G v15=v14;
G v16=*(G*)v0;
G v17=((G*)v16)[6];
G v18=rt_rec(5);
((G*)v18)[0]=v15;
((G*)v18)[1]=v8;
((G*)v18)[2]=v5;
G v19=0ull;
((G*)v18)[3]=v19;
G v20=0ull;
((G*)v18)[4]=v20;
rt_push(v17,v18);
G v21=0;
}
G v22=f_grailc_skip_braces(v0);
G v23=rt_lit("\073",1);
G v24=rt_view(v23);
G v25=f_grailc_eat(v0,v24);
G v26=0;
return v26;
}
G v27=f_grailc_module_copy(v0);
G v28=v27;
G v29=rt_view(v28);
G v30=rt_view(v8);
G v31=f_grailc_find_decl(v0,v29,v30);
G v32=v31;
G v33=*(G*)v0;
G v34=((G*)v33)[7];
G v35=rt_len(v34);
G v36=v35;
G v37=0ull;
G v38=v37;
G v39=rt_lit("\173",1);
G v40=rt_view(v39);
G v41=f_grailc_expect(v0,v40);
G v42=rt_lit("\175",1);
G v43=rt_view(v42);
G v44=f_grailc_eat(v0,v43);
G v45=0ull;
G v46=(v44==v45);
if(v46){
for(;;){
G v47=1ull;
if(!v47)break;
{
G v48=f_grailc_ident(v0);
G v49=v48;
G v50=1ull;
G v51=v50;
if(v5){
G v52=rt_lit("\050",1);
G v53=rt_view(v52);
G v54=f_grailc_eat(v0,v53);
if(v54){
G v55=f_grailc_parse_type(v0);
v51=v55;
G v56=rt_lit("\051",1);
G v57=rt_view(v56);
G v58=f_grailc_expect(v0,v57);
}
}
else{
G v59=rt_lit("\072",1);
G v60=rt_view(v59);
G v61=f_grailc_expect(v0,v60);
G v62=f_grailc_parse_type(v0);
v51=v62;
}
G v63=*(G*)v0;
G v64=((G*)v63)[7];
G v65=rt_rec(2);
((G*)v65)[0]=v49;
((G*)v65)[1]=v51;
rt_push(v64,v65);
G v66=0;
G v67=1ull;
G v68=(v38+v67);
v38=v68;
G v69=rt_lit("\175",1);
G v70=rt_view(v69);
G v71=f_grailc_eat(v0,v70);
if(v71){
break;
}
G v72=rt_lit("\054",1);
G v73=rt_view(v72);
G v74=f_grailc_expect(v0,v73);
G v75=rt_lit("\175",1);
G v76=rt_view(v75);
G v77=f_grailc_eat(v0,v76);
if(v77){
break;
}
}
}
}
G v78=rt_lit("\073",1);
G v79=rt_view(v78);
G v80=f_grailc_eat(v0,v79);
G v81=*(G*)v0;
G v82=((G*)v81)[6];
G v83=1ull;
G v84=(v32-v83);
G v85=rt_slot(v82,v84);
G v86=rt_rec(5);
((G*)v86)[0]=v28;
((G*)v86)[1]=v8;
((G*)v86)[2]=v5;
((G*)v86)[3]=v36;
((G*)v86)[4]=v38;
G v87=rt_xchg(v85,v86);
G v88=0;
return v88;
}
return 0;}
static G f_grailc_bind(G v0,G v1,G v2,G v3){{
G v4=*(G*)v0;
G v5=((G*)v4)[10];
G v6=rt_rec(3);
((G*)v6)[0]=v1;
((G*)v6)[1]=v2;
((G*)v6)[2]=v3;
rt_push(v5,v6);
G v7=0;
G v8=0;
return v8;
}
return 0;}
static G f_grailc_func(G v0,G v1,G v2){{
G v3=rt_lit("\146\156",2);
G v4=rt_view(v3);
G v5=f_grailc_expect(v0,v4);
G v6=f_grailc_ident(v0);
G v7=v6;
G v8=f_grailc_skip_angle(v0);
G v9=1ull;
G v10=(v1==v9);
if(v10){
for(;;){
G v11=f_grailc_kind(v0);
G v12=123ull;
G v13=(v11!=v12);
if(!v13)break;
{
G v14=f_grailc_advance(v0);
}
}
G v15=f_grailc_skip_braces(v0);
G v16=0;
return v16;
}
G v17=f_grailc_module_copy(v0);
G v18=v17;
G v19=*(G*)v0;
G v20=(G)&((G*)v19)[10];
G v21=rt_new();
G v22=rt_xchg(v20,v21);
G v23=*(G*)v0;
G v24=(G)&((G*)v23)[11];
G v25=0ull;
G v26=rt_xchg(v24,v25);
G v27=*(G*)v0;
G v28=((G*)v27)[9];
G v29=rt_len(v28);
G v30=v29;
G v31=0ull;
G v32=v31;
G v33=rt_lit("\050",1);
G v34=rt_view(v33);
G v35=f_grailc_expect(v0,v34);
G v36=rt_lit("\051",1);
G v37=rt_view(v36);
G v38=f_grailc_eat(v0,v37);
G v39=0ull;
G v40=(v38==v39);
if(v40){
for(;;){
G v41=1ull;
if(!v41)break;
{
G v42=f_grailc_ident(v0);
G v43=v42;
G v44=rt_lit("\072",1);
G v45=rt_view(v44);
G v46=f_grailc_expect(v0,v45);
G v47=f_grailc_parse_type(v0);
G v48=v47;
G v49=2ull;
G v50=(v1==v49);
if(v50){
G v51=*(G*)v0;
G v52=((G*)v51)[9];
rt_push(v52,v48);
G v53=0;
}
G v54=f_grailc_fresh(v0);
G v55=v54;
G v56=f_grailc_bind(v0,v43,v48,v55);
G v57=1ull;
G v58=(v32+v57);
v32=v58;
G v59=rt_lit("\051",1);
G v60=rt_view(v59);
G v61=f_grailc_eat(v0,v60);
if(v61){
break;
}
G v62=rt_lit("\054",1);
G v63=rt_view(v62);
G v64=f_grailc_expect(v0,v63);
}
}
}
G v65=rt_lit("\055\076",2);
G v66=rt_view(v65);
G v67=f_grailc_expect(v0,v66);
G v68=f_grailc_parse_type(v0);
G v69=v68;
G v70=rt_lit("\163\164\141\164\151\143\040\107\040",9);
G v71=rt_view(v70);
G v72=f_grailc_o(v0,v71);
G v73=rt_view(v18);
G v74=rt_view(v7);
G v75=f_grailc_mangle(v0,v73,v74);
G v76=*(G*)v0;
G v77=((G*)v76)[3];
G v78=40ull;
rt_push(v77,v78);
G v79=0;
G v80=0ull;
G v81=(v32==v80);
if(v81){
G v82=rt_lit("\166\157\151\144",4);
G v83=rt_view(v82);
G v84=f_grailc_o(v0,v83);
}
G v85=v32;
for(G v86=0;v86<v85;v86++){
G v87=0ull;
G v88=(v86!=v87);
if(v88){
G v89=*(G*)v0;
G v90=((G*)v89)[3];
G v91=44ull;
rt_push(v90,v91);
G v92=0;
}
G v93=rt_lit("\107\040",2);
G v94=rt_view(v93);
G v95=f_grailc_o(v0,v94);
G v96=f_grailc_ov(v0,v86);
}
G v97=*(G*)v0;
G v98=((G*)v97)[3];
G v99=41ull;
rt_push(v98,v99);
G v100=0;
G v101=2ull;
G v102=(v1==v101);
if(v102){
G v103=rt_lit("\073\012",2);
G v104=rt_view(v103);
G v105=f_grailc_o(v0,v104);
G v106=*(G*)v0;
G v107=((G*)v106)[12];
G v108=0ull;
G v109=(v107==v108);
G v110=*(G*)v0;
G v111=((G*)v110)[13];
G v112=2ull;
G v113=(v111==v112);
G v114=(v109&v113);
G v115=(v114&v2);
G v116=2ull;
G v117=(v32<v116);
G v118=(v115&v117);
G v119=v118;
G v120=*(G*)v0;
G v121=((G*)v120)[8];
G v122=rt_rec(5);
((G*)v122)[0]=v18;
((G*)v122)[1]=v7;
((G*)v122)[2]=v30;
((G*)v122)[3]=v32;
((G*)v122)[4]=v69;
rt_push(v121,v122);
G v123=0;
G v124=*(G*)v0;
G v125=((G*)v124)[8];
G v126=rt_len(v125);
G v127=v126;
if(v119){
G v128=*(G*)v0;
G v129=(G)&((G*)v128)[12];
G v130=rt_xchg(v129,v127);
}
G v131=f_grailc_skip_braces(v0);
G v132=0;
return v132;
}
G v133=*(G*)v0;
G v134=((G*)v133)[3];
G v135=123ull;
rt_push(v134,v135);
G v136=0;
G v137=f_grailc_block(v0);
G v138=rt_lit("\162\145\164\165\162\156\040\060\073\175\012",11);
G v139=rt_view(v138);
G v140=f_grailc_o(v0,v139);
G v141=0;
return v141;
}
return 0;}
static G f_grailc_toplevel(G v0,G v1){{
G v2=rt_lit("\155\157\144\165\154\145",6);
G v3=rt_view(v2);
G v4=f_grailc_expect(v0,v3);
G v5=f_grailc_ident(v0);
G v6=v5;
G v7=*(G*)v0;
G v8=(G)&((G*)v7)[4];
G v9=rt_xchg(v8,v6);
G v10=rt_lit("\073",1);
G v11=rt_view(v10);
G v12=f_grailc_expect(v0,v11);
for(;;){
G v13=rt_lit("\165\163\145",3);
G v14=rt_view(v13);
G v15=f_grailc_eat(v0,v14);
if(!v15)break;
{
G v16=f_grailc_ident(v0);
G v17=rt_lit("\073",1);
G v18=rt_view(v17);
G v19=f_grailc_expect(v0,v18);
}
}
for(;;){
G v20=f_grailc_kind(v0);
G v21=0ull;
G v22=(v20!=v21);
if(!v22)break;
{
G v23=rt_lit("\160\165\142",3);
G v24=rt_view(v23);
G v25=f_grailc_eat(v0,v24);
G v26=v25;
G v27=rt_lit("\163\164\162\165\143\164",6);
G v28=rt_view(v27);
G v29=f_grailc_is(v0,v28);
G v30=rt_lit("\145\156\165\155",4);
G v31=rt_view(v30);
G v32=f_grailc_is(v0,v31);
G v33=(v29+v32);
if(v33){
G v34=f_grailc_decl(v0,v1);
}
else{
G v35=f_grailc_func(v0,v1,v26);
}
}
}
G v36=0;
return v36;
}
return 0;}
static G f_grailc_deref(G v0,G v1){{
G v2=((G*)v1)[0];
G v3=v2;
G v4=((G*)v1)[1];
G v5=v4;
for(;;){
G v6=f_grailc_ty_kind(v0,v5);
G v7=7ull;
G v8=(v6==v7);
if(!v8)break;
{
G v9=f_grailc_def(v0);
G v10=v9;
G v11=rt_lit("\052\050\107\052\051",5);
G v12=rt_view(v11);
G v13=f_grailc_o(v0,v12);
G v14=f_grailc_ov(v0,v3);
G v15=rt_lit("\073\012",2);
G v16=rt_view(v15);
G v17=f_grailc_o(v0,v16);
v3=v10;
G v18=f_grailc_ty_arg(v0,v5);
v5=v18;
}
}
G v19=f_grailc_val(v3,v5);
return v19;
}
return 0;}
static G f_grailc_find_local(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[10];
G v4=rt_len(v3);
G v5=v4;
for(;;){
G v6=0ull;
G v7=(v6<v5);
if(!v7)break;
{
G v8=1ull;
G v9=(v5-v8);
v5=v9;
G v10=*(G*)v0;
G v11=((G*)v10)[10];
G v12=rt_slot(v11,v5);
G v13=v12;
G v14=*(G*)v13;
G v15=((G*)v14)[0];
G v16=rt_view(v15);
G v17=f_grailc_same(v16,v1);
if(v17){
G v18=1ull;
G v19=(v5+v18);
return v19;
}
}
}
G v20=0ull;
return v20;
}
return 0;}
static G f_grailc_local_id(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[10];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[2];
return v7;
}
return 0;}
static G f_grailc_local_ty(G v0,G v1){{
G v2=*(G*)v0;
G v3=((G*)v2)[10];
G v4=rt_slot(v3,v1);
G v5=v4;
G v6=*(G*)v5;
G v7=((G*)v6)[1];
return v7;
}
return 0;}
static G f_grailc_pop_locals(G v0,G v1){{
for(;;){
G v2=*(G*)v0;
G v3=((G*)v2)[10];
G v4=rt_len(v3);
G v5=(v1<v4);
if(!v5)break;
{
G v6=*(G*)v0;
G v7=((G*)v6)[10];
G v8=rt_pop(v7);
}
}
G v9=0;
return v9;
}
return 0;}
static G f_grailc_slot(G v0,G v1,G v2){{
G v3=rt_lit("\050\050\107\052\051",5);
G v4=rt_view(v3);
G v5=f_grailc_o(v0,v4);
G v6=f_grailc_ov(v0,v1);
G v7=rt_lit("\051\133",2);
G v8=rt_view(v7);
G v9=f_grailc_o(v0,v8);
G v10=f_grailc_on(v0,v2);
G v11=*(G*)v0;
G v12=((G*)v11)[3];
G v13=93ull;
rt_push(v12,v13);
G v14=0;
G v15=0;
return v15;
}
return 0;}
static G f_grailc_field_path(G v0,G v1,G v2,G v3){{
G v4=v1;
G v5=v2;
for(;;){
G v6=rt_lit("\056",1);
G v7=rt_view(v6);
G v8=f_grailc_eat(v0,v7);
if(!v8)break;
{
G v9=f_grailc_ident(v0);
G v10=v9;
G v11=f_grailc_val(v4,v5);
G v12=f_grailc_deref(v0,v11);
G v13=v12;
G v14=((G*)v13)[0];
G v15=v14;
G v16=((G*)v13)[1];
G v17=f_grailc_ty_arg(v0,v16);
G v18=v17;
G v19=rt_view(v10);
G v20=f_grailc_find_field(v0,v18,v19);
G v21=v20;
G v22=f_grailc_field_ty(v0,v18,v21);
G v23=v22;
G v24=f_grailc_def(v0);
G v25=v24;
G v26=f_grailc_kind(v0);
G v27=46ull;
G v28=(v26!=v27);
G v29=(v28&v3);
G v30=v29;
if(v30){
G v31=rt_lit("\050\107\051\046",4);
G v32=rt_view(v31);
G v33=f_grailc_o(v0,v32);
}
G v34=f_grailc_slot(v0,v15,v21);
G v35=rt_lit("\073\012",2);
G v36=rt_view(v35);
G v37=f_grailc_o(v0,v36);
if(v30){
G v38=7ull;
G v39=f_grailc_intern(v0,v38,v23);
G v40=f_grailc_val(v25,v39);
return v40;
}
v4=v25;
v5=v23;
}
}
G v41=f_grailc_val(v4,v5);
return v41;
}
return 0;}
static G f_grailc_place(G v0){{
G v1=f_grailc_ident(v0);
G v2=v1;
G v3=rt_view(v2);
G v4=f_grailc_find_local(v0,v3);
G v5=v4;
G v6=0ull;
G v7=(v5==v6);
if(v7){
G v8=rt_lit("\165\156\153\156\157\167\156\040\142\157\162\162\157\167\145\144\040\160\154\141\143\145",22);
G v9=rt_view(v8);
G v10=f_grailc_fail(v0,v9);
}
G v11=1ull;
G v12=(v5-v11);
G v13=f_grailc_local_id(v0,v12);
G v14=v13;
G v15=1ull;
G v16=(v5-v15);
G v17=f_grailc_local_ty(v0,v16);
G v18=v17;
G v19=f_grailc_kind(v0);
G v20=46ull;
G v21=(v19==v20);
if(v21){
G v22=1ull;
G v23=f_grailc_field_path(v0,v14,v18,v22);
return v23;
}
G v24=f_grailc_ty_kind(v0,v18);
G v25=7ull;
G v26=(v24==v25);
if(v26){
G v27=f_grailc_val(v14,v18);
return v27;
}
G v28=f_grailc_def(v0);
G v29=v28;
G v30=rt_lit("\050\107\051\046",4);
G v31=rt_view(v30);
G v32=f_grailc_o(v0,v31);
G v33=f_grailc_ov(v0,v14);
G v34=rt_lit("\073\012",2);
G v35=rt_view(v34);
G v36=f_grailc_o(v0,v35);
G v37=7ull;
G v38=f_grailc_intern(v0,v37,v18);
G v39=f_grailc_val(v29,v38);
return v39;
}
return 0;}
static G f_grailc_hex(G v0){{
G v1=58ull;
G v2=(v0<v1);
if(v2){
G v3=48ull;
G v4=(v0-v3);
return v4;
}
G v5=71ull;
G v6=(v0<v5);
if(v6){
G v7=55ull;
G v8=(v0-v7);
return v8;
}
G v9=87ull;
G v10=(v0-v9);
return v10;
}
return 0;}
static G f_grailc_string_lit(G v0){{
G v1=*(G*)v0;
G v2=((G*)v1)[2];
G v3=v2;
G v4=*(G*)v0;
G v5=((G*)v4)[1];
G v6=rt_slot(v5,v3);
G v7=v6;
G v8=*(G*)v7;
G v9=((G*)v8)[1];
G v10=v9;
G v11=*(G*)v7;
G v12=((G*)v11)[2];
G v13=v12;
G v14=f_grailc_advance(v0);
G v15=f_grailc_def(v0);
G v16=v15;
G v17=rt_lit("\162\164\137\154\151\164\050\042",8);
G v18=rt_view(v17);
G v19=f_grailc_o(v0,v18);
G v20=1ull;
G v21=(v10+v20);
G v22=v21;
G v23=0ull;
G v24=v23;
for(;;){
G v25=1ull;
G v26=(v13-v25);
G v27=(v22<v26);
if(!v27)break;
{
G v28=*(G*)v0;
G v29=((G*)v28)[0];
G v30=rt_view(v29);
G v31=rt_at(v30,v22);
G v32=v31;
G v33=92ull;
G v34=(v32==v33);
if(v34){
G v35=1ull;
G v36=(v22+v35);
v22=v36;
G v37=*(G*)v0;
G v38=((G*)v37)[0];
G v39=rt_view(v38);
G v40=rt_at(v39,v22);
G v41=v40;
v32=v41;
G v42=110ull;
G v43=(v41==v42);
if(v43){
G v44=10ull;
v32=v44;
}
G v45=114ull;
G v46=(v41==v45);
if(v46){
G v47=13ull;
v32=v47;
}
G v48=116ull;
G v49=(v41==v48);
if(v49){
G v50=9ull;
v32=v50;
}
G v51=48ull;
G v52=(v41==v51);
if(v52){
G v53=0ull;
v32=v53;
}
G v54=120ull;
G v55=(v41==v54);
if(v55){
G v56=*(G*)v0;
G v57=((G*)v56)[0];
G v58=rt_view(v57);
G v59=1ull;
G v60=(v22+v59);
G v61=rt_at(v58,v60);
G v62=f_grailc_hex(v61);
G v63=v62;
G v64=*(G*)v0;
G v65=((G*)v64)[0];
G v66=rt_view(v65);
G v67=2ull;
G v68=(v22+v67);
G v69=rt_at(v66,v68);
G v70=f_grailc_hex(v69);
G v71=v70;
G v72=16ull;
G v73=(v63*v72);
G v74=(v73+v71);
v32=v74;
G v75=2ull;
G v76=(v22+v75);
v22=v76;
}
}
G v77=*(G*)v0;
G v78=((G*)v77)[3];
G v79=92ull;
rt_push(v78,v79);
G v80=0;
G v81=*(G*)v0;
G v82=((G*)v81)[3];
G v83=48ull;
G v84=64ull;
G v85=f_grailc_div(v32,v84);
G v86=(v83+v85);
rt_push(v82,v86);
G v87=0;
G v88=*(G*)v0;
G v89=((G*)v88)[3];
G v90=48ull;
G v91=8ull;
G v92=f_grailc_div(v32,v91);
G v93=8ull;
G v94=rt_rem(v92,v93);
G v95=(v90+v94);
rt_push(v89,v95);
G v96=0;
G v97=*(G*)v0;
G v98=((G*)v97)[3];
G v99=48ull;
G v100=8ull;
G v101=rt_rem(v32,v100);
G v102=(v99+v101);
rt_push(v98,v102);
G v103=0;
G v104=1ull;
G v105=(v24+v104);
v24=v105;
G v106=1ull;
G v107=(v22+v106);
v22=v107;
}
}
G v108=rt_lit("\042\054",2);
G v109=rt_view(v108);
G v110=f_grailc_o(v0,v109);
G v111=f_grailc_on(v0,v24);
G v112=rt_lit("\051\073\012",3);
G v113=rt_view(v112);
G v114=f_grailc_o(v0,v113);
G v115=3ull;
G v116=f_grailc_val(v16,v115);
return v116;
}
return 0;}
static G f_grailc_record(G v0,G v1){{
G v2=rt_lit("\173",1);
G v3=rt_view(v2);
G v4=f_grailc_expect(v0,v3);
G v5=*(G*)v0;
G v6=((G*)v5)[6];
G v7=rt_slot(v6,v1);
G v8=v7;
G v9=*(G*)v8;
G v10=((G*)v9)[4];
G v11=v10;
G v12=f_grailc_def(v0);
G v13=v12;
G v14=rt_lit("\162\164\137\162\145\143\050",7);
G v15=rt_view(v14);
G v16=f_grailc_o(v0,v15);
G v17=f_grailc_on(v0,v11);
G v18=rt_lit("\051\073\012",3);
G v19=rt_view(v18);
G v20=f_grailc_o(v0,v19);
G v21=rt_lit("\175",1);
G v22=rt_view(v21);
G v23=f_grailc_eat(v0,v22);
G v24=0ull;
G v25=(v23==v24);
if(v25){
for(;;){
G v26=1ull;
if(!v26)break;
{
G v27=f_grailc_ident(v0);
G v28=v27;
G v29=rt_lit("\072",1);
G v30=rt_view(v29);
G v31=f_grailc_expect(v0,v30);
G v32=0ull;
G v33=f_grailc_expr(v0,v32);
G v34=v33;
G v35=rt_view(v28);
G v36=f_grailc_find_field(v0,v1,v35);
G v37=v36;
G v38=f_grailc_slot(v0,v13,v37);
G v39=*(G*)v0;
G v40=((G*)v39)[3];
G v41=61ull;
rt_push(v40,v41);
G v42=0;
G v43=((G*)v34)[0];
G v44=f_grailc_ov(v0,v43);
G v45=rt_lit("\073\012",2);
G v46=rt_view(v45);
G v47=f_grailc_o(v0,v46);
G v48=rt_lit("\175",1);
G v49=rt_view(v48);
G v50=f_grailc_eat(v0,v49);
if(v50){
break;
}
G v51=rt_lit("\054",1);
G v52=rt_view(v51);
G v53=f_grailc_expect(v0,v52);
G v54=rt_lit("\175",1);
G v55=rt_view(v54);
G v56=f_grailc_eat(v0,v55);
if(v56){
break;
}
}
}
}
G v57=8ull;
G v58=f_grailc_intern(v0,v57,v1);
G v59=f_grailc_val(v13,v58);
return v59;
}
return 0;}
static G f_grailc_variant(G v0,G v1,G v2){{
G v3=f_grailc_find_field(v0,v1,v2);
G v4=v3;
G v5=0ull;
G v6=v5;
G v7=0ull;
G v8=v7;
G v9=rt_lit("\050",1);
G v10=rt_view(v9);
G v11=f_grailc_eat(v0,v10);
if(v11){
G v12=0ull;
G v13=f_grailc_expr(v0,v12);
G v14=v13;
G v15=((G*)v14)[0];
v6=v15;
G v16=1ull;
v8=v16;
G v17=rt_lit("\051",1);
G v18=rt_view(v17);
G v19=f_grailc_expect(v0,v18);
}
G v20=f_grailc_def(v0);
G v21=v20;
G v22=rt_lit("\162\164\137\145\156\165\155\050",8);
G v23=rt_view(v22);
G v24=f_grailc_o(v0,v23);
G v25=f_grailc_on(v0,v4);
G v26=*(G*)v0;
G v27=((G*)v26)[3];
G v28=44ull;
rt_push(v27,v28);
G v29=0;
if(v8){
G v30=f_grailc_ov(v0,v6);
}
else{
G v31=*(G*)v0;
G v32=((G*)v31)[3];
G v33=48ull;
rt_push(v32,v33);
G v34=0;
}
G v35=rt_lit("\051\073\012",3);
G v36=rt_view(v35);
G v37=f_grailc_o(v0,v36);
G v38=8ull;
G v39=f_grailc_intern(v0,v38,v1);
G v40=f_grailc_val(v21,v39);
return v40;
}
return 0;}
static G f_grailc_call(G v0,G v1,G v2){{
G v3=f_grailc_find_func(v0,v1,v2);
G v4=v3;
G v5=0ull;
G v6=(v4==v5);
if(v6){
G v7=rt_lit("\165\156\153\156\157\167\156\040\146\165\156\143\164\151\157\156",16);
G v8=rt_view(v7);
G v9=f_grailc_fail(v0,v8);
}
G v10=rt_lit("\050",1);
G v11=rt_view(v10);
G v12=f_grailc_expect(v0,v11);
G v13=rt_new();
G v14=v13;
G v15=rt_lit("\051",1);
G v16=rt_view(v15);
G v17=f_grailc_eat(v0,v16);
G v18=0ull;
G v19=(v17==v18);
if(v19){
for(;;){
G v20=1ull;
if(!v20)break;
{
G v21=0ull;
G v22=f_grailc_expr(v0,v21);
G v23=v22;
G v24=((G*)v23)[0];
rt_push(v14,v24);
G v25=0;
G v26=rt_lit("\051",1);
G v27=rt_view(v26);
G v28=f_grailc_eat(v0,v27);
if(v28){
break;
}
G v29=rt_lit("\054",1);
G v30=rt_view(v29);
G v31=f_grailc_expect(v0,v30);
}
}
}
G v32=*(G*)v0;
G v33=((G*)v32)[8];
G v34=1ull;
G v35=(v4-v34);
G v36=rt_slot(v33,v35);
G v37=v36;
G v38=*(G*)v37;
G v39=((G*)v38)[4];
G v40=v39;
G v41=f_grailc_def(v0);
G v42=v41;
G v43=f_grailc_mangle(v0,v1,v2);
G v44=*(G*)v0;
G v45=((G*)v44)[3];
G v46=40ull;
rt_push(v45,v46);
G v47=0;
G v48=rt_len(v14);
G v49=v48;
for(G v50=0;v50<v49;v50++){
G v51=0ull;
G v52=(v50!=v51);
if(v52){
G v53=*(G*)v0;
G v54=((G*)v53)[3];
G v55=44ull;
rt_push(v54,v55);
G v56=0;
}
G v57=rt_slot(v14,v50);
G v58=*(G*)v57;
G v59=f_grailc_ov(v0,v58);
}
G v60=rt_lit("\051\073\012",3);
G v61=rt_view(v60);
G v62=f_grailc_o(v0,v61);
G v63=f_grailc_val(v42,v40);
return v63;
}
return 0;}
static G f_grailc_builtin_id(G v0){{
G v1=rt_lit("\142\171\164\145\163",5);
G v2=rt_view(v1);
G v3=f_grailc_same(v0,v2);
if(v3){
G v4=1ull;
return v4;
}
G v5=rt_lit("\162\145\141\144",4);
G v6=rt_view(v5);
G v7=f_grailc_same(v0,v6);
if(v7){
G v8=2ull;
return v8;
}
G v9=rt_lit("\155\165\164",3);
G v10=rt_view(v9);
G v11=f_grailc_same(v0,v10);
if(v11){
G v12=3ull;
return v12;
}
G v13=rt_lit("\154\145\156",3);
G v14=rt_view(v13);
G v15=f_grailc_same(v0,v14);
if(v15){
G v16=4ull;
return v16;
}
G v17=rt_lit("\143\157\160\171\137\142\171\164\145\163",10);
G v18=rt_view(v17);
G v19=f_grailc_same(v0,v18);
if(v19){
G v20=5ull;
return v20;
}
G v21=rt_lit("\164\145\170\164",4);
G v22=rt_view(v21);
G v23=f_grailc_same(v0,v22);
if(v23){
G v24=6ull;
return v24;
}
G v25=rt_lit("\141\164",2);
G v26=rt_view(v25);
G v27=f_grailc_same(v0,v26);
if(v27){
G v28=7ull;
return v28;
}
G v29=rt_lit("\163\154\151\143\145",5);
G v30=rt_view(v29);
G v31=f_grailc_same(v0,v30);
if(v31){
G v32=8ull;
return v32;
}
G v33=rt_lit("\166\145\143\137\160\165\163\150",8);
G v34=rt_view(v33);
G v35=f_grailc_same(v0,v34);
if(v35){
G v36=9ull;
return v36;
}
G v37=rt_lit("\166\145\143\137\160\157\160",7);
G v38=rt_view(v37);
G v39=f_grailc_same(v0,v38);
if(v39){
G v40=10ull;
return v40;
}
G v41=rt_lit("\166\145\143\137\147\145\164",7);
G v42=rt_view(v41);
G v43=f_grailc_same(v0,v42);
if(v43){
G v44=11ull;
return v44;
}
G v45=rt_lit("\166\145\143\137\147\145\164\137\155\165\164",11);
G v46=rt_view(v45);
G v47=f_grailc_same(v0,v46);
if(v47){
G v48=12ull;
return v48;
}
G v49=rt_lit("\142\157\162\162\157\167",6);
G v50=rt_view(v49);
G v51=f_grailc_same(v0,v50);
if(v51){
G v52=13ull;
return v52;
}
G v53=rt_lit("\142\157\162\162\157\167\137\155\165\164",10);
G v54=rt_view(v53);
G v55=f_grailc_same(v0,v54);
if(v55){
G v56=14ull;
return v56;
}
G v57=rt_lit("\154\157\141\144",4);
G v58=rt_view(v57);
G v59=f_grailc_same(v0,v58);
if(v59){
G v60=15ull;
return v60;
}
G v61=rt_lit("\145\170\143\150\141\156\147\145",8);
G v62=rt_view(v61);
G v63=f_grailc_same(v0,v62);
if(v63){
G v64=16ull;
return v64;
}
G v65=0ull;
return v65;
}
return 0;}
static G f_grailc_apply(G v0,G v1,G v2){{
G v3=f_grailc_def(v0);
G v4=v3;
G v5=f_grailc_o(v0,v1);
G v6=*(G*)v0;
G v7=((G*)v6)[3];
G v8=40ull;
rt_push(v7,v8);
G v9=0;
G v10=rt_len(v2);
G v11=v10;
for(G v12=0;v12<v11;v12++){
G v13=0ull;
G v14=(v12!=v13);
if(v14){
G v15=*(G*)v0;
G v16=((G*)v15)[3];
G v17=44ull;
rt_push(v16,v17);
G v18=0;
}
G v19=rt_slot(v2,v12);
G v20=*(G*)v19;
G v21=f_grailc_ov(v0,v20);
}
G v22=rt_lit("\051\073\012",3);
G v23=rt_view(v22);
G v24=f_grailc_o(v0,v23);
return v4;
}
return 0;}
static G f_grailc_one(G v0){{
G v1=rt_new();
G v2=v1;
rt_push(v2,v0);
G v3=0;
return v2;
}
return 0;}
static G f_grailc_two(G v0,G v1){{
G v2=rt_new();
G v3=v2;
rt_push(v3,v0);
G v4=0;
rt_push(v3,v1);
G v5=0;
return v3;
}
return 0;}
static G f_grailc_builtin(G v0,G v1){{
G v2=rt_lit("\050",1);
G v3=rt_view(v2);
G v4=f_grailc_expect(v0,v3);
G v5=1ull;
G v6=(v1==v5);
if(v6){
G v7=rt_lit("\051",1);
G v8=rt_view(v7);
G v9=f_grailc_expect(v0,v8);
G v10=rt_lit("\162\164\137\156\145\167",6);
G v11=rt_view(v10);
G v12=rt_new();
G v13=f_grailc_apply(v0,v11,v12);
G v14=2ull;
G v15=f_grailc_val(v13,v14);
return v15;
}
G v16=13ull;
G v17=(v1==v16);
G v18=14ull;
G v19=(v1==v18);
G v20=(v17+v19);
if(v20){
G v21=f_grailc_place(v0);
G v22=v21;
G v23=rt_lit("\051",1);
G v24=rt_view(v23);
G v25=f_grailc_expect(v0,v24);
return v22;
}
G v26=0ull;
G v27=f_grailc_expr(v0,v26);
G v28=v27;
G v29=16ull;
G v30=(v1==v29);
if(v30){
G v31=rt_lit("\054",1);
G v32=rt_view(v31);
G v33=f_grailc_expect(v0,v32);
G v34=0ull;
G v35=f_grailc_expr(v0,v34);
G v36=v35;
G v37=rt_lit("\051",1);
G v38=rt_view(v37);
G v39=f_grailc_expect(v0,v38);
G v40=((G*)v28)[1];
G v41=f_grailc_ty_arg(v0,v40);
G v42=v41;
G v43=rt_lit("\162\164\137\170\143\150\147",7);
G v44=rt_view(v43);
G v45=((G*)v28)[0];
G v46=((G*)v36)[0];
G v47=f_grailc_two(v45,v46);
G v48=f_grailc_apply(v0,v44,v47);
G v49=f_grailc_val(v48,v42);
return v49;
}
G v50=15ull;
G v51=(v1==v50);
if(v51){
G v52=rt_lit("\051",1);
G v53=rt_view(v52);
G v54=f_grailc_expect(v0,v53);
G v55=((G*)v28)[1];
G v56=f_grailc_ty_arg(v0,v55);
G v57=v56;
G v58=f_grailc_def(v0);
G v59=v58;
G v60=rt_lit("\052\050\107\052\051",5);
G v61=rt_view(v60);
G v62=f_grailc_o(v0,v61);
G v63=((G*)v28)[0];
G v64=f_grailc_ov(v0,v63);
G v65=rt_lit("\073\012",2);
G v66=rt_view(v65);
G v67=f_grailc_o(v0,v66);
G v68=f_grailc_val(v59,v57);
return v68;
}
G v69=f_grailc_deref(v0,v28);
G v70=v69;
G v71=((G*)v70)[0];
G v72=v71;
G v73=((G*)v70)[1];
G v74=v73;
G v75=7ull;
G v76=(v1<v75);
if(v76){
G v77=rt_lit("\051",1);
G v78=rt_view(v77);
G v79=f_grailc_expect(v0,v78);
G v80=4ull;
G v81=(v1<v80);
if(v81){
G v82=f_grailc_ty_kind(v0,v74);
G v83=5ull;
G v84=(v82==v83);
if(v84){
G v85=4ull;
G v86=f_grailc_val(v72,v85);
return v86;
}
G v87=rt_lit("\162\164\137\166\151\145\167",7);
G v88=rt_view(v87);
G v89=f_grailc_one(v72);
G v90=f_grailc_apply(v0,v88,v89);
G v91=4ull;
G v92=f_grailc_val(v90,v91);
return v92;
}
G v93=4ull;
G v94=(v1==v93);
if(v94){
G v95=rt_lit("\162\164\137\154\145\156",6);
G v96=rt_view(v95);
G v97=f_grailc_one(v72);
G v98=f_grailc_apply(v0,v96,v97);
G v99=0ull;
G v100=f_grailc_val(v98,v99);
return v100;
}
G v101=rt_lit("\162\164\137\143\157\160\171",7);
G v102=rt_view(v101);
G v103=f_grailc_one(v72);
G v104=f_grailc_apply(v0,v102,v103);
G v105=3ull;
G v106=(v1-v105);
G v107=f_grailc_val(v104,v106);
return v107;
}
G v108=10ull;
G v109=(v1==v108);
if(v109){
G v110=rt_lit("\051",1);
G v111=rt_view(v110);
G v112=f_grailc_expect(v0,v111);
G v113=f_grailc_ty_arg(v0,v74);
G v114=v113;
G v115=rt_lit("\162\164\137\160\157\160",6);
G v116=rt_view(v115);
G v117=f_grailc_one(v72);
G v118=f_grailc_apply(v0,v116,v117);
G v119=f_grailc_val(v118,v114);
return v119;
}
G v120=rt_lit("\054",1);
G v121=rt_view(v120);
G v122=f_grailc_expect(v0,v121);
G v123=0ull;
G v124=f_grailc_expr(v0,v123);
G v125=v124;
G v126=((G*)v125)[0];
G v127=v126;
G v128=7ull;
G v129=(v1==v128);
if(v129){
G v130=rt_lit("\051",1);
G v131=rt_view(v130);
G v132=f_grailc_expect(v0,v131);
G v133=rt_lit("\162\164\137\141\164",5);
G v134=rt_view(v133);
G v135=f_grailc_two(v72,v127);
G v136=f_grailc_apply(v0,v134,v135);
G v137=0ull;
G v138=f_grailc_val(v136,v137);
return v138;
}
G v139=9ull;
G v140=(v1==v139);
if(v140){
G v141=rt_lit("\051",1);
G v142=rt_view(v141);
G v143=f_grailc_expect(v0,v142);
G v144=rt_lit("\162\164\137\160\165\163\150\050",8);
G v145=rt_view(v144);
G v146=f_grailc_o(v0,v145);
G v147=f_grailc_ov(v0,v72);
G v148=*(G*)v0;
G v149=((G*)v148)[3];
G v150=44ull;
rt_push(v149,v150);
G v151=0;
G v152=f_grailc_ov(v0,v127);
G v153=rt_lit("\051\073\012",3);
G v154=rt_view(v153);
G v155=f_grailc_o(v0,v154);
G v156=f_grailc_def(v0);
G v157=v156;
G v158=rt_lit("\060\073\012",3);
G v159=rt_view(v158);
G v160=f_grailc_o(v0,v159);
G v161=1ull;
G v162=f_grailc_val(v157,v161);
return v162;
}
G v163=8ull;
G v164=(v1!=v163);
if(v164){
G v165=rt_lit("\051",1);
G v166=rt_view(v165);
G v167=f_grailc_expect(v0,v166);
G v168=f_grailc_ty_arg(v0,v74);
G v169=v168;
G v170=7ull;
G v171=f_grailc_intern(v0,v170,v169);
G v172=v171;
G v173=rt_lit("\162\164\137\163\154\157\164",7);
G v174=rt_view(v173);
G v175=f_grailc_two(v72,v127);
G v176=f_grailc_apply(v0,v174,v175);
G v177=f_grailc_val(v176,v172);
return v177;
}
G v178=rt_lit("\054",1);
G v179=rt_view(v178);
G v180=f_grailc_expect(v0,v179);
G v181=0ull;
G v182=f_grailc_expr(v0,v181);
G v183=v182;
G v184=rt_lit("\051",1);
G v185=rt_view(v184);
G v186=f_grailc_expect(v0,v185);
G v187=f_grailc_two(v72,v127);
G v188=v187;
G v189=((G*)v183)[0];
rt_push(v188,v189);
G v190=0;
G v191=rt_lit("\162\164\137\163\154\151\143\145",8);
G v192=rt_view(v191);
G v193=f_grailc_apply(v0,v192,v188);
G v194=4ull;
G v195=f_grailc_val(v193,v194);
return v195;
}
return 0;}
static G f_grailc_primary(G v0){{
G v1=f_grailc_kind(v0);
G v2=v1;
G v3=40ull;
G v4=(v2==v3);
if(v4){
G v5=f_grailc_advance(v0);
G v6=rt_lit("\051",1);
G v7=rt_view(v6);
G v8=f_grailc_eat(v0,v7);
if(v8){
G v9=f_grailc_def(v0);
G v10=v9;
G v11=rt_lit("\060\073\012",3);
G v12=rt_view(v11);
G v13=f_grailc_o(v0,v12);
G v14=1ull;
G v15=f_grailc_val(v10,v14);
return v15;
}
G v16=0ull;
G v17=f_grailc_expr(v0,v16);
G v18=v17;
G v19=rt_lit("\051",1);
G v20=rt_view(v19);
G v21=f_grailc_expect(v0,v20);
return v18;
}
G v22=3ull;
G v23=(v2==v22);
if(v23){
G v24=f_grailc_string_lit(v0);
return v24;
}
G v25=2ull;
G v26=(v2==v25);
if(v26){
G v27=*(G*)v0;
G v28=((G*)v27)[2];
G v29=v28;
G v30=f_grailc_tok_text(v0,v29);
G v31=v30;
G v32=f_grailc_advance(v0);
G v33=f_grailc_def(v0);
G v34=v33;
G v35=rt_view(v31);
G v36=f_grailc_o(v0,v35);
G v37=rt_lit("\165\154\154\073\012",5);
G v38=rt_view(v37);
G v39=f_grailc_o(v0,v38);
G v40=0ull;
G v41=f_grailc_val(v34,v40);
return v41;
}
G v42=f_grailc_ident(v0);
G v43=v42;
G v44=rt_view(v43);
G v45=rt_lit("\166\145\143",3);
G v46=rt_view(v45);
G v47=f_grailc_same(v44,v46);
G v48=rt_lit("\074",1);
G v49=rt_view(v48);
G v50=f_grailc_is(v0,v49);
G v51=(v47&v50);
if(v51){
G v52=f_grailc_advance(v0);
G v53=f_grailc_parse_type(v0);
G v54=v53;
G v55=rt_lit("\076",1);
G v56=rt_view(v55);
G v57=f_grailc_expect(v0,v56);
G v58=rt_lit("\050",1);
G v59=rt_view(v58);
G v60=f_grailc_expect(v0,v59);
G v61=rt_lit("\051",1);
G v62=rt_view(v61);
G v63=f_grailc_expect(v0,v62);
G v64=6ull;
G v65=f_grailc_intern(v0,v64,v54);
G v66=v65;
G v67=rt_lit("\162\164\137\156\145\167",6);
G v68=rt_view(v67);
G v69=rt_new();
G v70=f_grailc_apply(v0,v68,v69);
G v71=f_grailc_val(v70,v66);
return v71;
}
G v72=f_grailc_module_copy(v0);
G v73=v72;
G v74=rt_lit("\072\072",2);
G v75=rt_view(v74);
G v76=f_grailc_eat(v0,v75);
if(v76){
G v77=f_grailc_ident(v0);
G v78=v77;
G v79=rt_lit("\072\072",2);
G v80=rt_view(v79);
G v81=f_grailc_eat(v0,v80);
if(v81){
G v82=f_grailc_ident(v0);
G v83=v82;
G v84=rt_view(v43);
G v85=rt_view(v78);
G v86=f_grailc_find_decl(v0,v84,v85);
G v87=v86;
G v88=0ull;
G v89=(v87==v88);
if(v89){
G v90=rt_lit("\165\156\153\156\157\167\156\040\145\156\165\155",12);
G v91=rt_view(v90);
G v92=f_grailc_fail(v0,v91);
}
G v93=1ull;
G v94=(v87-v93);
G v95=rt_view(v83);
G v96=f_grailc_variant(v0,v94,v95);
return v96;
}
G v97=rt_view(v73);
G v98=rt_view(v43);
G v99=f_grailc_find_decl(v0,v97,v98);
G v100=v99;
G v101=0ull;
G v102=(v100!=v101);
if(v102){
G v103=1ull;
G v104=(v100-v103);
G v105=rt_view(v78);
G v106=f_grailc_variant(v0,v104,v105);
return v106;
}
G v107=rt_view(v43);
G v108=rt_view(v78);
G v109=f_grailc_find_decl(v0,v107,v108);
G v110=v109;
G v111=0ull;
G v112=(v110!=v111);
G v113=rt_lit("\173",1);
G v114=rt_view(v113);
G v115=f_grailc_is(v0,v114);
G v116=(v112&v115);
if(v116){
G v117=1ull;
G v118=(v110-v117);
G v119=f_grailc_record(v0,v118);
return v119;
}
G v120=rt_view(v43);
G v121=rt_view(v78);
G v122=f_grailc_call(v0,v120,v121);
return v122;
}
G v123=rt_lit("\050",1);
G v124=rt_view(v123);
G v125=f_grailc_is(v0,v124);
if(v125){
G v126=rt_view(v43);
G v127=f_grailc_builtin_id(v126);
G v128=v127;
G v129=0ull;
G v130=(v128!=v129);
if(v130){
G v131=f_grailc_builtin(v0,v128);
return v131;
}
G v132=rt_view(v73);
G v133=rt_view(v43);
G v134=f_grailc_call(v0,v132,v133);
return v134;
}
G v135=rt_view(v43);
G v136=f_grailc_find_local(v0,v135);
G v137=v136;
G v138=0ull;
G v139=(v137!=v138);
if(v139){
G v140=1ull;
G v141=(v137-v140);
G v142=f_grailc_local_id(v0,v141);
G v143=v142;
G v144=1ull;
G v145=(v137-v144);
G v146=f_grailc_local_ty(v0,v145);
G v147=v146;
G v148=0ull;
G v149=f_grailc_field_path(v0,v143,v147,v148);
return v149;
}
G v150=rt_view(v73);
G v151=rt_view(v43);
G v152=f_grailc_find_decl(v0,v150,v151);
G v153=v152;
G v154=0ull;
G v155=(v153!=v154);
if(v155){
G v156=1ull;
G v157=(v153-v156);
G v158=f_grailc_record(v0,v157);
return v158;
}
G v159=rt_lit("\165\156\144\145\146\151\156\145\144\040\156\141\155\145",14);
G v160=rt_view(v159);
G v161=f_grailc_fail(v0,v160);
G v162=0ull;
G v163=0ull;
G v164=f_grailc_val(v162,v163);
return v164;
}
return 0;}
static G f_grailc_prec(G v0){{
G v1=38ull;
G v2=(v0==v1);
if(v2){
G v3=1ull;
return v3;
}
G v4=94ull;
G v5=(v0==v4);
if(v5){
G v6=2ull;
return v6;
}
G v7=258ull;
G v8=(v0==v7);
G v9=259ull;
G v10=(v0==v9);
G v11=(v8+v10);
G v12=60ull;
G v13=(v0==v12);
G v14=(v11+v13);
if(v14){
G v15=3ull;
return v15;
}
G v16=43ull;
G v17=(v0==v16);
G v18=45ull;
G v19=(v0==v18);
G v20=(v17+v19);
if(v20){
G v21=4ull;
return v21;
}
G v22=42ull;
G v23=(v0==v22);
G v24=37ull;
G v25=(v0==v24);
G v26=(v23+v25);
G v27=47ull;
G v28=(v0==v27);
G v29=(v26+v28);
if(v29){
G v30=5ull;
return v30;
}
G v31=267ull;
G v32=(v0==v31);
if(v32){
G v33=6ull;
return v33;
}
G v34=0ull;
return v34;
}
return 0;}
static G f_grailc_propagate(G v0,G v1,G v2){{
G v3=f_grailc_deref(v0,v1);
G v4=v3;
G v5=((G*)v4)[0];
G v6=v5;
G v7=((G*)v4)[1];
G v8=f_grailc_ty_arg(v0,v7);
G v9=v8;
G v10=0ull;
G v11=v10;
G v12=*(G*)v0;
G v13=((G*)v12)[6];
G v14=rt_slot(v13,v9);
G v15=v14;
G v16=*(G*)v15;
G v17=((G*)v16)[3];
G v18=v17;
G v19=*(G*)v0;
G v20=((G*)v19)[7];
G v21=rt_slot(v20,v18);
G v22=v21;
G v23=*(G*)v22;
G v24=((G*)v23)[0];
G v25=rt_view(v24);
G v26=rt_lit("\117\153",2);
G v27=rt_view(v26);
G v28=f_grailc_same(v25,v27);
G v29=*(G*)v22;
G v30=((G*)v29)[0];
G v31=rt_view(v30);
G v32=rt_lit("\123\157\155\145",4);
G v33=rt_view(v32);
G v34=f_grailc_same(v31,v33);
G v35=(v28+v34);
G v36=0ull;
G v37=(v35==v36);
if(v37){
G v38=1ull;
v11=v38;
}
G v39=rt_lit("\151\146\050\050\050\107\052\051",8);
G v40=rt_view(v39);
G v41=f_grailc_o(v0,v40);
G v42=f_grailc_ov(v0,v6);
G v43=rt_lit("\051\133\060\135\041\075",6);
G v44=rt_view(v43);
G v45=f_grailc_o(v0,v44);
G v46=f_grailc_on(v0,v11);
G v47=rt_lit("\051",1);
G v48=rt_view(v47);
G v49=f_grailc_o(v0,v48);
if(v2){
G v50=rt_lit("\141\142\157\162\164\050\051\073\012",9);
G v51=rt_view(v50);
G v52=f_grailc_o(v0,v51);
}
else{
G v53=rt_lit("\162\145\164\165\162\156\040",7);
G v54=rt_view(v53);
G v55=f_grailc_o(v0,v54);
G v56=f_grailc_ov(v0,v6);
G v57=rt_lit("\073\012",2);
G v58=rt_view(v57);
G v59=f_grailc_o(v0,v58);
}
G v60=f_grailc_def(v0);
G v61=v60;
G v62=1ull;
G v63=f_grailc_slot(v0,v6,v62);
G v64=rt_lit("\073\012",2);
G v65=rt_view(v64);
G v66=f_grailc_o(v0,v65);
G v67=f_grailc_field_ty(v0,v9,v11);
G v68=f_grailc_val(v61,v67);
return v68;
}
return 0;}
static G f_grailc_binary(G v0,G v1,G v2,G v3){{
G v4=f_grailc_def(v0);
G v5=v4;
G v6=37ull;
G v7=(v1==v6);
G v8=47ull;
G v9=(v1==v8);
G v10=(v7+v9);
G v11=267ull;
G v12=(v1==v11);
G v13=(v10+v12);
if(v13){
G v14=37ull;
G v15=(v1==v14);
if(v15){
G v16=rt_lit("\162\164\137\162\145\155\050",7);
G v17=rt_view(v16);
G v18=f_grailc_o(v0,v17);
}
G v19=47ull;
G v20=(v1==v19);
if(v20){
G v21=rt_lit("\162\164\137\144\151\166\050",7);
G v22=rt_view(v21);
G v23=f_grailc_o(v0,v22);
}
G v24=267ull;
G v25=(v1==v24);
if(v25){
G v26=rt_lit("\162\164\137\160\157\167\050",7);
G v27=rt_view(v26);
G v28=f_grailc_o(v0,v27);
}
G v29=f_grailc_ov(v0,v2);
G v30=*(G*)v0;
G v31=((G*)v30)[3];
G v32=44ull;
rt_push(v31,v32);
G v33=0;
}
else{
G v34=*(G*)v0;
G v35=((G*)v34)[3];
G v36=40ull;
rt_push(v35,v36);
G v37=0;
G v38=f_grailc_ov(v0,v2);
G v39=258ull;
G v40=(v1==v39);
if(v40){
G v41=rt_lit("\075\075",2);
G v42=rt_view(v41);
G v43=f_grailc_o(v0,v42);
}
G v44=259ull;
G v45=(v1==v44);
if(v45){
G v46=rt_lit("\041\075",2);
G v47=rt_view(v46);
G v48=f_grailc_o(v0,v47);
}
G v49=f_grailc_prec(v1);
G v50=3ull;
G v51=(v49!=v50);
if(v51){
G v52=*(G*)v0;
G v53=((G*)v52)[3];
rt_push(v53,v1);
G v54=0;
}
G v55=60ull;
G v56=(v1==v55);
if(v56){
G v57=*(G*)v0;
G v58=((G*)v57)[3];
G v59=60ull;
rt_push(v58,v59);
G v60=0;
}
}
G v61=f_grailc_ov(v0,v3);
G v62=rt_lit("\051\073\012",3);
G v63=rt_view(v62);
G v64=f_grailc_o(v0,v63);
return v5;
}
return 0;}
static G f_grailc_expr(G v0,G v1){{
G v2=f_grailc_primary(v0);
G v3=v2;
G v4=((G*)v3)[0];
G v5=v4;
G v6=((G*)v3)[1];
G v7=v6;
for(;;){
G v8=1ull;
if(!v8)break;
{
G v9=f_grailc_kind(v0);
G v10=v9;
G v11=f_grailc_prec(v10);
G v12=v11;
G v13=63ull;
G v14=(v10==v13);
G v15=33ull;
G v16=(v10==v15);
G v17=(v14+v16);
if(v17){
G v18=f_grailc_advance(v0);
G v19=f_grailc_val(v5,v7);
G v20=33ull;
G v21=(v10==v20);
G v22=f_grailc_propagate(v0,v19,v21);
G v23=v22;
G v24=((G*)v23)[0];
v5=v24;
G v25=((G*)v23)[1];
v7=v25;
}
else{
G v26=0ull;
G v27=(v12==v26);
if(v27){
break;
}
G v28=(v12<v1);
if(v28){
break;
}
G v29=f_grailc_advance(v0);
G v30=267ull;
G v31=(v10!=v30);
G v32=(v12+v31);
G v33=f_grailc_expr(v0,v32);
G v34=v33;
G v35=((G*)v34)[0];
G v36=f_grailc_binary(v0,v10,v5,v35);
v5=v36;
G v37=0ull;
v7=v37;
}
}
}
G v38=f_grailc_val(v5,v7);
return v38;
}
return 0;}
static G f_grailc_block(G v0){{
G v1=rt_lit("\173",1);
G v2=rt_view(v1);
G v3=f_grailc_expect(v0,v2);
G v4=rt_lit("\173\012",2);
G v5=rt_view(v4);
G v6=f_grailc_o(v0,v5);
G v7=*(G*)v0;
G v8=((G*)v7)[10];
G v9=rt_len(v8);
G v10=v9;
for(;;){
G v11=rt_lit("\175",1);
G v12=rt_view(v11);
G v13=f_grailc_is(v0,v12);
G v14=0ull;
G v15=(v13==v14);
if(!v15)break;
{
G v16=f_grailc_stmt(v0);
}
}
G v17=f_grailc_advance(v0);
G v18=rt_lit("\175\012",2);
G v19=rt_view(v18);
G v20=f_grailc_o(v0,v19);
G v21=f_grailc_pop_locals(v0,v10);
G v22=0;
return v22;
}
return 0;}
static G f_grailc_compound_operator(G v0){{
G v1=262ull;
G v2=(v0==v1);
if(v2){
G v3=43ull;
return v3;
}
G v4=263ull;
G v5=(v0==v4);
if(v5){
G v6=45ull;
return v6;
}
G v7=264ull;
G v8=(v0==v7);
if(v8){
G v9=42ull;
return v9;
}
G v10=265ull;
G v11=(v0==v10);
if(v11){
G v12=47ull;
return v12;
}
G v13=266ull;
G v14=(v0==v13);
if(v14){
G v15=37ull;
return v15;
}
G v16=267ull;
return v16;
}
return 0;}
static G f_grailc_assignment_ahead(G v0){{
G v1=f_grailc_kind(v0);
G v2=1ull;
G v3=(v1!=v2);
if(v3){
G v4=0ull;
return v4;
}
G v5=*(G*)v0;
G v6=((G*)v5)[2];
G v7=1ull;
G v8=(v6+v7);
G v9=v8;
for(;;){
G v10=f_grailc_kind_at(v0,v9);
G v11=46ull;
G v12=(v10==v11);
if(!v12)break;
{
G v13=2ull;
G v14=(v9+v13);
v9=v14;
}
}
G v15=f_grailc_kind_at(v0,v9);
G v16=v15;
G v17=61ull;
G v18=(v16==v17);
G v19=261ull;
G v20=(v19<v16);
G v21=267ull;
G v22=(v16<v21);
G v23=(v20&v22);
G v24=(v18+v23);
G v25=268ull;
G v26=(v16==v25);
G v27=(v24+v26);
return v27;
}
return 0;}
static G f_grailc_operand(G v0){{
G v1=0ull;
G v2=f_grailc_expr(v0,v1);
G v3=v2;
G v4=f_grailc_deref(v0,v3);
G v5=v4;
G v6=((G*)v5)[0];
return v6;
}
return 0;}
static G f_grailc_statement_call(G v0,G v1,G v2){{
G v3=rt_lit("\050",1);
G v4=rt_view(v3);
G v5=f_grailc_expect(v0,v4);
G v6=rt_new();
G v7=v6;
G v8=v2;
for(G v9=0;v9<v8;v9++){
G v10=0ull;
G v11=(v9!=v10);
if(v11){
G v12=rt_lit("\054",1);
G v13=rt_view(v12);
G v14=f_grailc_expect(v0,v13);
}
G v15=f_grailc_operand(v0);
rt_push(v7,v15);
G v16=0;
}
G v17=rt_lit("\051",1);
G v18=rt_view(v17);
G v19=f_grailc_expect(v0,v18);
G v20=rt_lit("\073",1);
G v21=rt_view(v20);
G v22=f_grailc_expect(v0,v21);
G v23=f_grailc_o(v0,v1);
G v24=*(G*)v0;
G v25=((G*)v24)[3];
G v26=40ull;
rt_push(v25,v26);
G v27=0;
G v28=rt_len(v7);
G v29=v28;
for(G v30=0;v30<v29;v30++){
G v31=0ull;
G v32=(v30!=v31);
if(v32){
G v33=*(G*)v0;
G v34=((G*)v33)[3];
G v35=44ull;
rt_push(v34,v35);
G v36=0;
}
G v37=rt_slot(v7,v30);
G v38=*(G*)v37;
G v39=f_grailc_ov(v0,v38);
}
G v40=rt_lit("\051\073\012",3);
G v41=rt_view(v40);
G v42=f_grailc_o(v0,v41);
G v43=0;
return v43;
}
return 0;}
static G f_grailc_stmt(G v0){{
G v1=rt_lit("\142\162\145\141\153",5);
G v2=rt_view(v1);
G v3=f_grailc_eat(v0,v2);
if(v3){
G v4=rt_lit("\073",1);
G v5=rt_view(v4);
G v6=f_grailc_expect(v0,v5);
G v7=rt_lit("\142\162\145\141\153\073\012",7);
G v8=rt_view(v7);
G v9=f_grailc_o(v0,v8);
G v10=0;
return v10;
}
G v11=rt_lit("\143\157\156\164\151\156\165\145",8);
G v12=rt_view(v11);
G v13=f_grailc_eat(v0,v12);
if(v13){
G v14=rt_lit("\073",1);
G v15=rt_view(v14);
G v16=f_grailc_expect(v0,v15);
G v17=rt_lit("\143\157\156\164\151\156\165\145\073\012",10);
G v18=rt_view(v17);
G v19=f_grailc_o(v0,v18);
G v20=0;
return v20;
}
G v21=rt_lit("\162\145\164\165\162\156",6);
G v22=rt_view(v21);
G v23=f_grailc_eat(v0,v22);
if(v23){
G v24=0ull;
G v25=f_grailc_expr(v0,v24);
G v26=v25;
G v27=rt_lit("\073",1);
G v28=rt_view(v27);
G v29=f_grailc_expect(v0,v28);
G v30=rt_lit("\162\145\164\165\162\156\040",7);
G v31=rt_view(v30);
G v32=f_grailc_o(v0,v31);
G v33=((G*)v26)[0];
G v34=f_grailc_ov(v0,v33);
G v35=rt_lit("\073\012",2);
G v36=rt_view(v35);
G v37=f_grailc_o(v0,v36);
G v38=0;
return v38;
}
G v39=rt_lit("\173",1);
G v40=rt_view(v39);
G v41=f_grailc_is(v0,v40);
if(v41){
G v42=f_grailc_block(v0);
G v43=0;
return v43;
}
G v44=rt_lit("\166\141\162",3);
G v45=rt_view(v44);
G v46=f_grailc_is(v0,v45);
G v47=f_grailc_next_kind(v0);
G v48=261ull;
G v49=(v47==v48);
G v50=(v46+v49);
if(v50){
G v51=rt_lit("\166\141\162",3);
G v52=rt_view(v51);
G v53=f_grailc_eat(v0,v52);
G v54=v53;
G v55=f_grailc_ident(v0);
G v56=v55;
G v57=rt_lit("\072",1);
G v58=rt_view(v57);
G v59=f_grailc_eat(v0,v58);
if(v59){
G v60=f_grailc_parse_type(v0);
G v61=v60;
G v62=rt_lit("\073",1);
G v63=rt_view(v62);
G v64=f_grailc_expect(v0,v63);
G v65=f_grailc_def(v0);
G v66=v65;
G v67=rt_lit("\060\073\012",3);
G v68=rt_view(v67);
G v69=f_grailc_o(v0,v68);
G v70=f_grailc_bind(v0,v56,v61,v66);
G v71=0;
return v71;
}
if(v54){
G v72=rt_lit("\075",1);
G v73=rt_view(v72);
G v74=f_grailc_expect(v0,v73);
}
else{
G v75=rt_lit("\072\075",2);
G v76=rt_view(v75);
G v77=f_grailc_expect(v0,v76);
}
G v78=0ull;
G v79=f_grailc_expr(v0,v78);
G v80=v79;
G v81=rt_lit("\073",1);
G v82=rt_view(v81);
G v83=f_grailc_expect(v0,v82);
G v84=f_grailc_def(v0);
G v85=v84;
G v86=((G*)v80)[0];
G v87=f_grailc_ov(v0,v86);
G v88=rt_lit("\073\012",2);
G v89=rt_view(v88);
G v90=f_grailc_o(v0,v89);
G v91=((G*)v80)[1];
G v92=f_grailc_bind(v0,v56,v91,v85);
G v93=0;
return v93;
}
G v94=rt_lit("\167\150\151\154\145",5);
G v95=rt_view(v94);
G v96=f_grailc_eat(v0,v95);
if(v96){
G v97=rt_lit("\146\157\162\050\073\073\051\173\012",9);
G v98=rt_view(v97);
G v99=f_grailc_o(v0,v98);
G v100=0ull;
G v101=f_grailc_expr(v0,v100);
G v102=v101;
G v103=rt_lit("\151\146\050\041",4);
G v104=rt_view(v103);
G v105=f_grailc_o(v0,v104);
G v106=((G*)v102)[0];
G v107=f_grailc_ov(v0,v106);
G v108=rt_lit("\051\142\162\145\141\153\073\012",8);
G v109=rt_view(v108);
G v110=f_grailc_o(v0,v109);
G v111=f_grailc_block(v0);
G v112=rt_lit("\175\012",2);
G v113=rt_view(v112);
G v114=f_grailc_o(v0,v113);
G v115=0;
return v115;
}
G v116=rt_lit("\146\157\162",3);
G v117=rt_view(v116);
G v118=f_grailc_eat(v0,v117);
if(v118){
G v119=f_grailc_ident(v0);
G v120=v119;
G v121=rt_lit("\151\156",2);
G v122=rt_view(v121);
G v123=f_grailc_expect(v0,v122);
G v124=0ull;
G v125=f_grailc_expr(v0,v124);
G v126=v125;
G v127=f_grailc_def(v0);
G v128=v127;
G v129=((G*)v126)[0];
G v130=f_grailc_ov(v0,v129);
G v131=rt_lit("\073\012",2);
G v132=rt_view(v131);
G v133=f_grailc_o(v0,v132);
G v134=f_grailc_fresh(v0);
G v135=v134;
G v136=rt_lit("\146\157\162\050\107\040",6);
G v137=rt_view(v136);
G v138=f_grailc_o(v0,v137);
G v139=f_grailc_ov(v0,v135);
G v140=rt_lit("\075\060\073",3);
G v141=rt_view(v140);
G v142=f_grailc_o(v0,v141);
G v143=f_grailc_ov(v0,v135);
G v144=*(G*)v0;
G v145=((G*)v144)[3];
G v146=60ull;
rt_push(v145,v146);
G v147=0;
G v148=f_grailc_ov(v0,v128);
G v149=*(G*)v0;
G v150=((G*)v149)[3];
G v151=59ull;
rt_push(v150,v151);
G v152=0;
G v153=f_grailc_ov(v0,v135);
G v154=rt_lit("\053\053\051",3);
G v155=rt_view(v154);
G v156=f_grailc_o(v0,v155);
G v157=*(G*)v0;
G v158=((G*)v157)[10];
G v159=rt_len(v158);
G v160=v159;
G v161=0ull;
G v162=f_grailc_bind(v0,v120,v161,v135);
G v163=f_grailc_block(v0);
G v164=f_grailc_pop_locals(v0,v160);
G v165=0;
return v165;
}
G v166=rt_lit("\155\141\164\143\150",5);
G v167=rt_view(v166);
G v168=f_grailc_eat(v0,v167);
if(v168){
G v169=0ull;
G v170=f_grailc_expr(v0,v169);
G v171=v170;
G v172=f_grailc_deref(v0,v171);
G v173=v172;
G v174=((G*)v173)[0];
G v175=v174;
G v176=((G*)v173)[1];
G v177=f_grailc_ty_arg(v0,v176);
G v178=v177;
G v179=f_grailc_def(v0);
G v180=v179;
G v181=0ull;
G v182=f_grailc_slot(v0,v175,v181);
G v183=rt_lit("\073\012",2);
G v184=rt_view(v183);
G v185=f_grailc_o(v0,v184);
G v186=rt_lit("\173",1);
G v187=rt_view(v186);
G v188=f_grailc_expect(v0,v187);
for(;;){
G v189=rt_lit("\175",1);
G v190=rt_view(v189);
G v191=f_grailc_eat(v0,v190);
G v192=0ull;
G v193=(v191==v192);
if(!v193)break;
{
G v194=f_grailc_ident(v0);
G v195=v194;
G v196=rt_view(v195);
G v197=f_grailc_find_field(v0,v178,v196);
G v198=v197;
G v199=f_grailc_field_ty(v0,v178,v198);
G v200=v199;
G v201=rt_lit("\151\146\050",3);
G v202=rt_view(v201);
G v203=f_grailc_o(v0,v202);
G v204=f_grailc_ov(v0,v180);
G v205=rt_lit("\075\075",2);
G v206=rt_view(v205);
G v207=f_grailc_o(v0,v206);
G v208=f_grailc_on(v0,v198);
G v209=rt_lit("\051\173\012",3);
G v210=rt_view(v209);
G v211=f_grailc_o(v0,v210);
G v212=*(G*)v0;
G v213=((G*)v212)[10];
G v214=rt_len(v213);
G v215=v214;
G v216=rt_lit("\050",1);
G v217=rt_view(v216);
G v218=f_grailc_eat(v0,v217);
if(v218){
G v219=rt_lit("\137",1);
G v220=rt_view(v219);
G v221=f_grailc_eat(v0,v220);
G v222=0ull;
G v223=(v221==v222);
if(v223){
G v224=f_grailc_ident(v0);
G v225=v224;
G v226=f_grailc_def(v0);
G v227=v226;
G v228=1ull;
G v229=f_grailc_slot(v0,v175,v228);
G v230=rt_lit("\073\012",2);
G v231=rt_view(v230);
G v232=f_grailc_o(v0,v231);
G v233=f_grailc_bind(v0,v225,v200,v227);
}
G v234=rt_lit("\051",1);
G v235=rt_view(v234);
G v236=f_grailc_expect(v0,v235);
}
G v237=rt_lit("\075\076",2);
G v238=rt_view(v237);
G v239=f_grailc_expect(v0,v238);
G v240=f_grailc_block(v0);
G v241=rt_lit("\175\145\154\163\145\040",6);
G v242=rt_view(v241);
G v243=f_grailc_o(v0,v242);
G v244=f_grailc_pop_locals(v0,v215);
G v245=rt_lit("\054",1);
G v246=rt_view(v245);
G v247=f_grailc_eat(v0,v246);
G v248=0ull;
G v249=(v247==v248);
if(v249){
G v250=rt_lit("\175",1);
G v251=rt_view(v250);
G v252=f_grailc_expect(v0,v251);
break;
}
}
}
G v253=rt_lit("\141\142\157\162\164\050\051\073\012",9);
G v254=rt_view(v253);
G v255=f_grailc_o(v0,v254);
G v256=0;
return v256;
}
G v257=rt_lit("\151\146",2);
G v258=rt_view(v257);
G v259=f_grailc_eat(v0,v258);
if(v259){
G v260=0ull;
G v261=f_grailc_expr(v0,v260);
G v262=v261;
G v263=rt_lit("\151\146\050",3);
G v264=rt_view(v263);
G v265=f_grailc_o(v0,v264);
G v266=((G*)v262)[0];
G v267=f_grailc_ov(v0,v266);
G v268=*(G*)v0;
G v269=((G*)v268)[3];
G v270=41ull;
rt_push(v269,v270);
G v271=0;
G v272=f_grailc_block(v0);
G v273=rt_lit("\145\154\163\145",4);
G v274=rt_view(v273);
G v275=f_grailc_eat(v0,v274);
if(v275){
G v276=rt_lit("\145\154\163\145",4);
G v277=rt_view(v276);
G v278=f_grailc_o(v0,v277);
G v279=f_grailc_block(v0);
}
G v280=0;
return v280;
}
G v281=rt_lit("\144\162\157\160",4);
G v282=rt_view(v281);
G v283=f_grailc_eat(v0,v282);
if(v283){
G v284=rt_lit("\050",1);
G v285=rt_view(v284);
G v286=f_grailc_expect(v0,v285);
G v287=f_grailc_ident(v0);
G v288=rt_lit("\051",1);
G v289=rt_view(v288);
G v290=f_grailc_expect(v0,v289);
G v291=rt_lit("\073",1);
G v292=rt_view(v291);
G v293=f_grailc_expect(v0,v292);
G v294=0;
return v294;
}
G v295=rt_lit("\141\160\160\145\156\144\137\164\145\170\164",11);
G v296=rt_view(v295);
G v297=f_grailc_eat(v0,v296);
if(v297){
G v298=rt_lit("\162\164\137\141\160\160\145\156\144",9);
G v299=rt_view(v298);
G v300=2ull;
G v301=f_grailc_statement_call(v0,v299,v300);
G v302=0;
return v302;
}
G v303=rt_lit("\160\165\163\150",4);
G v304=rt_view(v303);
G v305=f_grailc_eat(v0,v304);
if(v305){
G v306=rt_lit("\162\164\137\160\165\163\150\142",8);
G v307=rt_view(v306);
G v308=2ull;
G v309=f_grailc_statement_call(v0,v307,v308);
G v310=0;
return v310;
}
G v311=rt_lit("\167\162\151\164\145",5);
G v312=rt_view(v311);
G v313=f_grailc_eat(v0,v312);
if(v313){
G v314=rt_lit("\162\164\137\167\162\151\164\145",8);
G v315=rt_view(v314);
G v316=3ull;
G v317=f_grailc_statement_call(v0,v315,v316);
G v318=0;
return v318;
}
G v319=rt_lit("\141\163\163\145\162\164",6);
G v320=rt_view(v319);
G v321=f_grailc_eat(v0,v320);
if(v321){
G v322=rt_lit("\050",1);
G v323=rt_view(v322);
G v324=f_grailc_expect(v0,v323);
G v325=0ull;
G v326=f_grailc_expr(v0,v325);
G v327=v326;
G v328=rt_lit("\051",1);
G v329=rt_view(v328);
G v330=f_grailc_expect(v0,v329);
G v331=rt_lit("\073",1);
G v332=rt_view(v331);
G v333=f_grailc_expect(v0,v332);
G v334=rt_lit("\151\146\050\041",4);
G v335=rt_view(v334);
G v336=f_grailc_o(v0,v335);
G v337=((G*)v327)[0];
G v338=f_grailc_ov(v0,v337);
G v339=rt_lit("\051\141\142\157\162\164\050\051\073\012",10);
G v340=rt_view(v339);
G v341=f_grailc_o(v0,v340);
G v342=0;
return v342;
}
G v343=f_grailc_assignment_ahead(v0);
if(v343){
G v344=f_grailc_ident(v0);
G v345=v344;
G v346=rt_view(v345);
G v347=f_grailc_find_local(v0,v346);
G v348=v347;
G v349=0ull;
G v350=(v348==v349);
if(v350){
G v351=rt_lit("\165\156\144\145\146\151\156\145\144\040\141\163\163\151\147\156\155\145\156\164",20);
G v352=rt_view(v351);
G v353=f_grailc_fail(v0,v352);
}
G v354=1ull;
G v355=(v348-v354);
G v356=f_grailc_local_id(v0,v355);
G v357=v356;
G v358=1ull;
G v359=(v348-v358);
G v360=f_grailc_local_ty(v0,v359);
G v361=v360;
G v362=v357;
G v363=0ull;
G v364=v363;
G v365=f_grailc_kind(v0);
G v366=46ull;
G v367=(v365==v366);
if(v367){
G v368=1ull;
G v369=f_grailc_field_path(v0,v357,v361,v368);
G v370=v369;
G v371=((G*)v370)[0];
v362=v371;
G v372=1ull;
v364=v372;
}
G v373=f_grailc_kind(v0);
G v374=v373;
G v375=f_grailc_advance(v0);
G v376=v362;
G v377=61ull;
G v378=(v374!=v377);
if(v378){
if(v364){
G v379=f_grailc_def(v0);
v376=v379;
G v380=rt_lit("\052\050\107\052\051",5);
G v381=rt_view(v380);
G v382=f_grailc_o(v0,v381);
G v383=f_grailc_ov(v0,v362);
G v384=rt_lit("\073\012",2);
G v385=rt_view(v384);
G v386=f_grailc_o(v0,v385);
}
else{
G v387=f_grailc_def(v0);
v376=v387;
G v388=f_grailc_ov(v0,v357);
G v389=rt_lit("\073\012",2);
G v390=rt_view(v389);
G v391=f_grailc_o(v0,v390);
}
}
G v392=0ull;
G v393=f_grailc_expr(v0,v392);
G v394=v393;
G v395=rt_lit("\073",1);
G v396=rt_view(v395);
G v397=f_grailc_expect(v0,v396);
G v398=61ull;
G v399=(v374!=v398);
if(v399){
G v400=f_grailc_compound_operator(v374);
G v401=((G*)v394)[0];
G v402=f_grailc_binary(v0,v400,v376,v401);
G v403=v402;
G v404=0ull;
G v405=f_grailc_val(v403,v404);
v394=v405;
}
if(v364){
G v406=rt_lit("\052\050\107\052\051",5);
G v407=rt_view(v406);
G v408=f_grailc_o(v0,v407);
}
G v409=f_grailc_ov(v0,v362);
G v410=*(G*)v0;
G v411=((G*)v410)[3];
G v412=61ull;
rt_push(v411,v412);
G v413=0;
G v414=((G*)v394)[0];
G v415=f_grailc_ov(v0,v414);
G v416=rt_lit("\073\012",2);
G v417=rt_view(v416);
G v418=f_grailc_o(v0,v417);
G v419=0;
return v419;
}
G v420=0ull;
G v421=f_grailc_expr(v0,v420);
G v422=v421;
G v423=rt_lit("\073",1);
G v424=rt_view(v423);
G v425=f_grailc_expect(v0,v424);
G v426=0;
return v426;
}
return 0;}
static G f_grailc_host_fn(G v0,G v1,G v2){{
G v3=*(G*)v0;
G v4=((G*)v3)[8];
G v5=rt_rec(5);
G v6=rt_lit("\150\157\163\164",4);
G v7=rt_view(v6);
G v8=rt_copy(v7);
((G*)v5)[0]=v8;
G v9=rt_copy(v1);
((G*)v5)[1]=v9;
G v10=0ull;
((G*)v5)[2]=v10;
G v11=0ull;
((G*)v5)[3]=v11;
((G*)v5)[4]=v2;
rt_push(v4,v5);
G v12=0;
G v13=0;
return v13;
}
return 0;}
static G f_grailc_main(void){{
G v0=rt_rec(14);
G v1=rt_new();
((G*)v0)[0]=v1;
G v2=rt_new();
((G*)v0)[1]=v2;
G v3=0ull;
((G*)v0)[2]=v3;
G v4=rt_new();
((G*)v0)[3]=v4;
G v5=rt_new();
((G*)v0)[4]=v5;
G v6=rt_new();
((G*)v0)[5]=v6;
G v7=rt_new();
((G*)v0)[6]=v7;
G v8=rt_new();
((G*)v0)[7]=v8;
G v9=rt_new();
((G*)v0)[8]=v9;
G v10=rt_new();
((G*)v0)[9]=v10;
G v11=rt_new();
((G*)v0)[10]=v11;
G v12=0ull;
((G*)v0)[11]=v12;
G v13=0ull;
((G*)v0)[12]=v13;
G v14=0ull;
((G*)v0)[13]=v14;
G v15=v0;
G v16=5ull;
G v17=v16;
for(G v18=0;v18<v17;v18++){
G v19=(G)&v15;
G v20=1ull;
G v21=(v18+v20);
G v22=0ull;
G v23=f_grailc_intern(v19,v21,v22);
}
G v24=(G)&v15;
G v25=rt_lit("\141\162\147\143",4);
G v26=rt_view(v25);
G v27=0ull;
G v28=f_grailc_host_fn(v24,v26,v27);
G v29=(G)&v15;
G v30=rt_lit("\141\162\147",3);
G v31=rt_view(v30);
G v32=2ull;
G v33=f_grailc_host_fn(v29,v31,v32);
G v34=(G)&v15;
G v35=rt_lit("\162\145\141\144\137\146\151\154\145",9);
G v36=rt_view(v35);
G v37=2ull;
G v38=f_grailc_host_fn(v34,v36,v37);
G v39=(G)&v15;
G v40=rt_lit("\167\162\151\164\145\137\146\151\154\145",10);
G v41=rt_view(v40);
G v42=0ull;
G v43=f_grailc_host_fn(v39,v41,v42);
G v44=(G)&v15;
G v45=rt_lit("\160\162\151\156\164",5);
G v46=rt_view(v45);
G v47=1ull;
G v48=f_grailc_host_fn(v44,v46,v47);
G v49=(G)&v15;
G v50=rt_lit("\143\157\155\155\141\156\144",7);
G v51=rt_view(v50);
G v52=0ull;
G v53=f_grailc_host_fn(v49,v51,v52);
G v54=f_host_argc();
G v55=v54;
G v56=2ull;
G v57=(v56<v55);
if(!v57)abort();
G v58=3ull;
G v59=v58;
for(G v60=0;v60<v59;v60++){
G v61=1ull;
G v62=(v60==v61);
if(v62){
G v63=(G)&v15;
G v64=rt_lit("\043\151\156\143\154\165\144\145\040\042\147\162\141\151\154\137\162\164\056\143\042\012",22);
G v65=rt_view(v64);
G v66=f_grailc_o(v63,v65);
}
G v67=2ull;
G v68=v67;
for(;;){
G v69=(v68<v55);
if(!v69)break;
{
G v70=(G)&v15;
G v71=f_grailc_load_file(v70,v68);
G v72=(G)&((G*)v15)[13];
G v73=rt_xchg(v72,v68);
G v74=(G)&v15;
G v75=1ull;
G v76=(v60+v75);
G v77=f_grailc_toplevel(v74,v76);
G v78=1ull;
G v79=(v68+v78);
v68=v79;
}
}
}
G v80=((G*)v15)[12];
G v81=v80;
G v82=0ull;
G v83=(v81==v82);
if(v83){
G v84=(G)&v15;
G v85=rt_lit("\156\157\040\160\165\142\154\151\143\040\145\156\164\162\171\040\146\165\156\143\164\151\157\156\040\167\151\164\150\040\141\164\040\155\157\163\164\040\157\156\145\040\160\141\162\141\155\145\164\145\162",51);
G v86=rt_view(v85);
G v87=f_grailc_fail(v84,v86);
}
G v88=((G*)v15)[8];
G v89=1ull;
G v90=(v81-v89);
G v91=rt_slot(v88,v90);
G v92=v91;
G v93=*(G*)v92;
G v94=((G*)v93)[0];
G v95=rt_view(v94);
G v96=rt_copy(v95);
G v97=v96;
G v98=*(G*)v92;
G v99=((G*)v98)[1];
G v100=rt_view(v99);
G v101=rt_copy(v100);
G v102=v101;
G v103=*(G*)v92;
G v104=((G*)v103)[3];
G v105=v104;
G v106=(G)&v15;
G v107=rt_lit("\151\156\164\040\155\141\151\156\050\151\156\164\040\141\162\147\143\054\143\150\141\162\052\052\141\162\147\166\051\173\162\164\137\141\162\147\143\075\141\162\147\143\073\162\164\137\141\162\147\166\075\141\162\147\166\073",56);
G v108=rt_view(v107);
G v109=f_grailc_o(v106,v108);
G v110=1ull;
G v111=(v105==v110);
if(v111){
G v112=(G)&v15;
G v113=rt_lit("\151\146\050\141\162\147\143\041\075\062\051\162\145\164\165\162\156\040\062\073",20);
G v114=rt_view(v113);
G v115=f_grailc_o(v112,v114);
}
G v116=(G)&v15;
G v117=rt_lit("\160\162\151\156\164\146\050\042\045\154\154\165\134\156\042\054\050\165\156\163\151\147\156\145\144\040\154\157\156\147\040\154\157\156\147\051",36);
G v118=rt_view(v117);
G v119=f_grailc_o(v116,v118);
G v120=(G)&v15;
G v121=rt_view(v97);
G v122=rt_view(v102);
G v123=f_grailc_mangle(v120,v121,v122);
G v124=1ull;
G v125=(v105==v124);
if(v125){
G v126=(G)&v15;
G v127=rt_lit("\050\162\164\137\166\151\145\167\050\146\137\150\157\163\164\137\141\162\147\050\061\051\051\051\051\073\162\145\164\165\162\156\040\060\073\175\012",37);
G v128=rt_view(v127);
G v129=f_grailc_o(v126,v128);
}
else{
G v130=(G)&v15;
G v131=rt_lit("\050\051\051\073\162\145\164\165\162\156\040\060\073\175\012",15);
G v132=rt_view(v131);
G v133=f_grailc_o(v130,v132);
}
G v134=rt_new();
G v135=v134;
G v136=((G*)v15)[3];
G v137=rt_len(v136);
G v138=v137;
for(G v139=0;v139<v138;v139++){
G v140=((G*)v15)[3];
G v141=rt_slot(v140,v139);
G v142=*(G*)v141;
rt_pushb(v135,v142);
}
G v143=1ull;
G v144=f_host_arg(v143);
G v145=v144;
G v146=rt_view(v145);
G v147=rt_view(v135);
G v148=f_host_write_file(v146,v147);
return v148;
}
return 0;}
static G f_lexer_letter(G v0){{
G v1=64ull;
G v2=(v1<v0);
G v3=91ull;
G v4=(v0<v3);
G v5=(v2&v4);
G v6=96ull;
G v7=(v6<v0);
G v8=123ull;
G v9=(v0<v8);
G v10=(v7&v9);
G v11=(v5+v10);
G v12=95ull;
G v13=(v0==v12);
G v14=(v11+v13);
return v14;
}
return 0;}
static G f_lexer_digit(G v0){{
G v1=47ull;
G v2=(v1<v0);
G v3=58ull;
G v4=(v0<v3);
G v5=(v2&v4);
return v5;
}
return 0;}
static G f_lexer_whitespace(G v0){{
G v1=32ull;
G v2=(v0==v1);
G v3=9ull;
G v4=(v0==v3);
G v5=(v2+v4);
G v6=10ull;
G v7=(v0==v6);
G v8=(v5+v7);
G v9=12ull;
G v10=(v0==v9);
G v11=(v8+v10);
G v12=13ull;
G v13=(v0==v12);
G v14=(v11+v13);
return v14;
}
return 0;}
static G f_lexer_punctuation(G v0){{
G v1=40ull;
G v2=(v0==v1);
G v3=41ull;
G v4=(v0==v3);
G v5=(v2+v4);
G v6=123ull;
G v7=(v0==v6);
G v8=(v5+v7);
G v9=125ull;
G v10=(v0==v9);
G v11=(v8+v10);
G v12=60ull;
G v13=(v0==v12);
G v14=(v11+v13);
G v15=62ull;
G v16=(v0==v15);
G v17=(v14+v16);
G v18=44ull;
G v19=(v0==v18);
G v20=(v17+v19);
G v21=58ull;
G v22=(v0==v21);
G v23=(v20+v22);
G v24=59ull;
G v25=(v0==v24);
G v26=(v23+v25);
G v27=61ull;
G v28=(v0==v27);
G v29=(v26+v28);
G v30=43ull;
G v31=(v0==v30);
G v32=(v29+v31);
G v33=45ull;
G v34=(v0==v33);
G v35=(v32+v34);
G v36=42ull;
G v37=(v0==v36);
G v38=(v35+v37);
G v39=47ull;
G v40=(v0==v39);
G v41=(v38+v40);
G v42=37ull;
G v43=(v0==v42);
G v44=(v41+v43);
G v45=38ull;
G v46=(v0==v45);
G v47=(v44+v46);
G v48=94ull;
G v49=(v0==v48);
G v50=(v47+v49);
G v51=46ull;
G v52=(v0==v51);
G v53=(v50+v52);
G v54=33ull;
G v55=(v0==v54);
G v56=(v53+v55);
G v57=63ull;
G v58=(v0==v57);
G v59=(v56+v58);
return v59;
}
return 0;}
static G f_lexer_pair_kind(G v0,G v1){{
G v2=45ull;
G v3=(v0==v2);
G v4=62ull;
G v5=(v1==v4);
G v6=(v3&v5);
if(v6){
G v7=256ull;
return v7;
}
G v8=61ull;
G v9=(v0==v8);
G v10=62ull;
G v11=(v1==v10);
G v12=(v9&v11);
if(v12){
G v13=257ull;
return v13;
}
G v14=61ull;
G v15=(v0==v14);
G v16=61ull;
G v17=(v1==v16);
G v18=(v15&v17);
if(v18){
G v19=258ull;
return v19;
}
G v20=33ull;
G v21=(v0==v20);
G v22=61ull;
G v23=(v1==v22);
G v24=(v21&v23);
if(v24){
G v25=259ull;
return v25;
}
G v26=58ull;
G v27=(v0==v26);
G v28=58ull;
G v29=(v1==v28);
G v30=(v27&v29);
if(v30){
G v31=260ull;
return v31;
}
G v32=58ull;
G v33=(v0==v32);
G v34=61ull;
G v35=(v1==v34);
G v36=(v33&v35);
if(v36){
G v37=261ull;
return v37;
}
G v38=43ull;
G v39=(v0==v38);
G v40=61ull;
G v41=(v1==v40);
G v42=(v39&v41);
if(v42){
G v43=262ull;
return v43;
}
G v44=45ull;
G v45=(v0==v44);
G v46=61ull;
G v47=(v1==v46);
G v48=(v45&v47);
if(v48){
G v49=263ull;
return v49;
}
G v50=42ull;
G v51=(v0==v50);
G v52=61ull;
G v53=(v1==v52);
G v54=(v51&v53);
if(v54){
G v55=264ull;
return v55;
}
G v56=47ull;
G v57=(v0==v56);
G v58=61ull;
G v59=(v1==v58);
G v60=(v57&v59);
if(v60){
G v61=265ull;
return v61;
}
G v62=37ull;
G v63=(v0==v62);
G v64=61ull;
G v65=(v1==v64);
G v66=(v63&v65);
if(v66){
G v67=266ull;
return v67;
}
G v68=42ull;
G v69=(v0==v68);
G v70=42ull;
G v71=(v1==v70);
G v72=(v69&v71);
if(v72){
G v73=267ull;
return v73;
}
G v74=0ull;
return v74;
}
return 0;}
static G f_lexer_tokenize(G v0){{
G v1=rt_new();
G v2=v1;
G v3=rt_len(v0);
G v4=v3;
G v5=0ull;
G v6=v5;
for(;;){
G v7=(v6<v4);
if(!v7)break;
{
G v8=rt_at(v0,v6);
G v9=v8;
G v10=f_lexer_whitespace(v9);
if(v10){
G v11=1ull;
G v12=(v6+v11);
v6=v12;
continue;
}
G v13=47ull;
G v14=(v9==v13);
if(v14){
G v15=0ull;
G v16=v15;
G v17=1ull;
G v18=(v6+v17);
G v19=(v18<v4);
if(v19){
G v20=1ull;
G v21=(v6+v20);
G v22=rt_at(v0,v21);
G v23=47ull;
G v24=(v22==v23);
if(v24){
G v25=1ull;
v16=v25;
}
}
if(v16){
G v26=2ull;
G v27=(v6+v26);
v6=v27;
for(;;){
G v28=(v6<v4);
if(!v28)break;
{
G v29=rt_at(v0,v6);
G v30=10ull;
G v31=(v29==v30);
if(v31){
break;
}
G v32=1ull;
G v33=(v6+v32);
v6=v33;
}
}
continue;
}
}
G v34=v6;
G v35=0ull;
G v36=v35;
G v37=34ull;
G v38=(v9==v37);
if(v38){
G v39=3ull;
v36=v39;
G v40=1ull;
G v41=(v6+v40);
v6=v41;
G v42=0ull;
G v43=v42;
for(;;){
G v44=(v6<v4);
if(!v44)break;
{
G v45=rt_at(v0,v6);
G v46=v45;
G v47=34ull;
G v48=(v46==v47);
if(v48){
G v49=1ull;
G v50=(v6+v49);
v6=v50;
G v51=1ull;
v43=v51;
break;
}
G v52=32ull;
G v53=(v46<v52);
G v54=0ull;
G v55=(v53==v54);
if(!v55)abort();
G v56=92ull;
G v57=(v46==v56);
if(v57){
G v58=1ull;
G v59=(v6+v58);
v6=v59;
G v60=(v6==v4);
if(v60){
break;
}
}
G v61=1ull;
G v62=(v6+v61);
v6=v62;
}
}
if(!v43)abort();
}
else{
G v63=f_lexer_letter(v9);
if(v63){
G v64=1ull;
v36=v64;
G v65=1ull;
G v66=(v6+v65);
v6=v66;
for(;;){
G v67=(v6<v4);
if(!v67)break;
{
G v68=rt_at(v0,v6);
G v69=v68;
G v70=f_lexer_letter(v69);
G v71=f_lexer_digit(v69);
G v72=(v70+v71);
G v73=0ull;
G v74=(v72==v73);
if(v74){
break;
}
G v75=1ull;
G v76=(v6+v75);
v6=v76;
}
}
}
else{
G v77=f_lexer_digit(v9);
if(v77){
G v78=2ull;
v36=v78;
G v79=1ull;
G v80=(v6+v79);
v6=v80;
for(;;){
G v81=(v6<v4);
if(!v81)break;
{
G v82=rt_at(v0,v6);
G v83=f_lexer_digit(v82);
G v84=0ull;
G v85=(v83==v84);
if(v85){
break;
}
G v86=1ull;
G v87=(v6+v86);
v6=v87;
}
}
}
else{
G v88=1ull;
G v89=(v6+v88);
G v90=(v89<v4);
if(v90){
G v91=1ull;
G v92=(v6+v91);
G v93=rt_at(v0,v92);
G v94=f_lexer_pair_kind(v9,v93);
v36=v94;
}
G v95=0ull;
G v96=(v36!=v95);
if(v96){
G v97=2ull;
G v98=(v6+v97);
v6=v98;
G v99=267ull;
G v100=(v36==v99);
if(v100){
G v101=(v6<v4);
if(v101){
G v102=rt_at(v0,v6);
G v103=61ull;
G v104=(v102==v103);
if(v104){
G v105=268ull;
v36=v105;
G v106=1ull;
G v107=(v6+v106);
v6=v107;
}
}
}
}
else{
G v108=f_lexer_punctuation(v9);
if(!v108)abort();
v36=v9;
G v109=1ull;
G v110=(v6+v109);
v6=v110;
}
}
}
}
G v111=rt_rec(4);
((G*)v111)[0]=v36;
G v112=rt_slice(v0,v34,v6);
((G*)v111)[1]=v112;
((G*)v111)[2]=v34;
((G*)v111)[3]=v6;
rt_push(v2,v111);
G v113=0;
}
}
G v114=rt_rec(4);
G v115=0ull;
((G*)v114)[0]=v115;
G v116=rt_slice(v0,v4,v4);
((G*)v114)[1]=v116;
((G*)v114)[2]=v4;
((G*)v114)[3]=v4;
rt_push(v2,v114);
G v117=0;
return v2;
}
return 0;}
int main(int argc,char**argv){rt_argc=argc;rt_argv=argv;printf("%llu\n",(unsigned long long)f_grailc_main());return 0;}
