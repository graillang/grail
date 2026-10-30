
#include <stdlib.h>
#include <stdint.h>
#include <stddef.h>
void *__real_malloc(size_t);
void *__real_realloc(void*,size_t);
void __real_free(void*);
static long live;
static void *slots[4096];
static unsigned ids[4096], serial, last, previous;
static unsigned find(void*p) {for(unsigned i=0;i<4096;++i)if(slots[i]==p)return i;abort();}
static void track(void*p) {if(!p)return;for(unsigned i=0;i<4096;++i)if(!slots[i]){slots[i]=p;ids[i]=++serial;++live;return;}abort();}
void *__wrap_malloc(size_t n) {void*p=__real_malloc(n);track(p);return p;}
void *__wrap_realloc(void*p,size_t n) {int fresh=p==0;unsigned slot=fresh?0:find(p);void*q=__real_realloc(p,n);if(q){if(fresh)track(q);else slots[slot]=q;}return q;}
void __wrap_free(void*p) {if(p){unsigned i=find(p);previous=last;last=ids[i];slots[i]=0;--live;}__real_free(p);if(live<0)abort();}
uint64_t g_live(void){return (uint64_t)live;}
__attribute__((destructor)) static void check_leaks(void){if(live || previous!=2 || last!=1)abort();}
