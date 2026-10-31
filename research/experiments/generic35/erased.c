#include "api.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
static void reserve(Vec*v,const Type*t){if(!t->size||t->align>_Alignof(NativeAlign))abort();if(v->n<v->c)return;size_t c=v->c?v->c*2:8;if(c<v->c||c>SIZE_MAX/t->size)abort();v->p=b_realloc(v->p,c*t->size);v->c=c;}
void e_push(Vec*v,const void*x,const Type*t){reserve(v,t);memcpy((char*)v->p+v->n*t->size,x,t->size);++v->n;}
int e_pop(Vec*v,void*out,const Type*t){if(!v->n)return 0;--v->n;memcpy(out,(char*)v->p+v->n*t->size,t->size);return 1;}
void*e_get(Vec*v,size_t i,const Type*t){if(i>=v->n)abort();return(char*)v->p+i*t->size;}
void e_drop(Vec*v,const Type*t){if(t->drop)for(size_t i=0;i<v->n;++i)t->drop((char*)v->p+i*t->size);b_free(v->p);*v=(Vec){0};}
