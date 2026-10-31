#include "api.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
static unsigned freed;
static void drop_text(void*p){free(((Text*)p)->p);++freed;}
static void exchange(const Type*t,void*a,void*b){if(!t->size||t->align>_Alignof(NativeAlign))abort();_Alignas(NativeAlign)unsigned char temporary[t->size];memcpy(temporary,a,t->size);memcpy(a,b,t->size);memcpy(b,temporary,t->size);}
static void choose(const Type*t,int condition,void*out,void*a,void*b){memcpy(out,condition?a:b,t->size);if(t->drop)t->drop(condition?b:a);}
int main(void){uint64_t a[256]={7},b[256]={11};Type array={sizeof(a),_Alignof(uint64_t),0};exchange(&array,a,b);if(a[0]!=11||b[0]!=7)return 1;Text x={malloc(1),1,1},y={malloc(1),1,1},out;if(!x.p||!y.p)abort();x.p[0]=3;y.p[0]=4;Type text={sizeof(Text),_Alignof(Text),drop_text};exchange(&text,&x,&y);choose(&text,1,&out,&x,&y);if(out.p[0]!=4||freed!=1)return 2;drop_text(&out);if(freed!=2)return 3;puts("11 7 4 2");}
