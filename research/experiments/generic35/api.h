#ifndef G35_API
#define G35_API
#include <stdint.h>
#include <stddef.h>
typedef struct{const unsigned char*p;size_t n;} Span;
typedef struct{unsigned char*p;size_t n,c;} Text;
typedef struct{Span span;Text name;uint64_t kind;} Token;
typedef struct{uint64_t start,end,left,right;Text error;} Node;
typedef struct{void*p;size_t n,c;} Vec;
typedef union{long double scalar;void*pointer;uint64_t integer;} NativeAlign;
typedef struct{size_t size,align;void(*drop)(void*);} Type;
void *b_alloc(size_t);void *b_realloc(void*,size_t);void b_free(void*);
void e_push(Vec*,const void*,const Type*);int e_pop(Vec*,void*,const Type*);
void *e_get(Vec*,size_t,const Type*);void e_drop(Vec*,const Type*);
#define DECLARE(T,N) void m_push_##N(Vec*,T);int m_pop_##N(Vec*,T*);T*m_get_##N(Vec*,size_t);void m_drop_##N(Vec*);
DECLARE(uint64_t,num) DECLARE(Text,text) DECLARE(Token,token) DECLARE(Node,node)
#endif
