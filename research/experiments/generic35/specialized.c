#include "api.h"
#include <stdlib.h>
#include <stdint.h>
#define DEFINE(T,N,DROP) \
void m_push_##N(Vec*v,T x){if(v->n==v->c){size_t c=v->c?v->c*2:8;if(c<v->c||c>SIZE_MAX/sizeof(T))abort();v->p=b_realloc(v->p,c*sizeof(T));v->c=c;}((T*)v->p)[v->n++]=x;}\
int m_pop_##N(Vec*v,T*out){if(!v->n)return 0;*out=((T*)v->p)[--v->n];return 1;}\
T*m_get_##N(Vec*v,size_t i){if(i>=v->n)abort();return &((T*)v->p)[i];}\
void m_drop_##N(Vec*v){for(size_t i=0;i<v->n;++i){T*x=&((T*)v->p)[i];DROP;}b_free(v->p);*v=(Vec){0};}
DEFINE(uint64_t,num,(void)x)
DEFINE(Text,text,b_free(x->p))
DEFINE(Token,token,b_free(x->name.p))
DEFINE(Node,node,b_free(x->error.p))
