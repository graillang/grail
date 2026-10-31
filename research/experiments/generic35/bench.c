#define _POSIX_C_SOURCE 200809L
#include "api.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <time.h>
static uint64_t live,allocations,releases;
void*b_alloc(size_t n){void*p=malloc(n?n:1);if(!p)abort();++live;++allocations;return p;}
void*b_realloc(void*p,size_t n){int fresh=p==0;void*q=realloc(p,n);if(!q)abort();if(fresh){++live;++allocations;}return q;}
void b_free(void*p){if(p){if(!live)abort();--live;++releases;}free(p);}
static Text text(Span s){Text t={b_alloc(s.n?s.n:1),s.n,s.n};if(s.n)memcpy(t.p,s.p,s.n);return t;}
static void drop_text(void*p){b_free(((Text*)p)->p);}
static void drop_token(void*p){b_free(((Token*)p)->name.p);}
static void drop_node(void*p){b_free(((Node*)p)->error.p);}
#if ERASED
static const Type num_info={sizeof(uint64_t),_Alignof(uint64_t),0},text_info={sizeof(Text),_Alignof(Text),drop_text},token_info={sizeof(Token),_Alignof(Token),drop_token},node_info={sizeof(Node),_Alignof(Node),drop_node};
#endif
#if ERASED
#define PUSH(N,V,X) do{__typeof__(X) snapshot=(X);e_push(V,&snapshot,&N##_info);}while(0)
#define POP(N,V,X) e_pop(V,&(X),&N##_info)
#define GET(T,N,V,I) ((T*)e_get(V,I,&N##_info))
#define DROP(N,V) e_drop(V,&N##_info)
#else
#define PUSH(N,V,X) m_push_##N(V,X)
#define POP(N,V,X) m_pop_##N(V,&(X))
#define GET(T,N,V,I) m_get_##N(V,I)
#define DROP(N,V) m_drop_##N(V)
#endif
uint64_t stress(void);
static int initial(unsigned char c){return(c>='a'&&c<='z')||(c>='A'&&c<='Z')||c=='_';}
static int digit(unsigned char c){return c>='0'&&c<='9';}
static uint64_t now(void){struct timespec t;if(clock_gettime(CLOCK_MONOTONIC,&t))abort();return(uint64_t)t.tv_sec*1000000000+t.tv_nsec;}
int main(int argc,char**argv){if(argc!=3)return 2;FILE*f=fopen(argv[1],"rb");if(!f)return 3;if(fseek(f,0,SEEK_END))abort();long length=ftell(f);if(length<0)abort();rewind(f);unsigned char*source=malloc((size_t)length+1);if(!source)abort();if(fread(source,1,(size_t)length,f)!=(size_t)length)abort();fclose(f);size_t count=(size_t)strtoull(argv[2],0,10);if(count>10000000)abort();
uint64_t begin=now();Vec nums={0};uint64_t checksum=0;for(uint64_t i=0;i<count;++i)PUSH(num,&nums,i);for(size_t i=0;i<count;++i)checksum+=*GET(uint64_t,num,&nums,i);uint64_t value;while(POP(num,&nums,value))checksum+=value;DROP(num,&nums);uint64_t numeric=now()-begin;
Vec tokens={0},names={0},nodes={0};uint64_t token_count=0;begin=now();for(size_t i=0;i<(size_t)length;){if(!initial(source[i])&&!digit(source[i])){++i;continue;}size_t start=i;int number=digit(source[i]);++i;while(i<(size_t)length&&(number?digit(source[i]):(initial(source[i])||digit(source[i]))))++i;Span span={source+start,i-start};Token t={span,text(span),(uint64_t)(number?2:1)};PUSH(token,&tokens,t);Text name=text(span);PUSH(text,&names,name);Node node={start,i,token_count,token_count+1,text(span)};PUSH(node,&nodes,node);++token_count;}
for(size_t i=0;i<tokens.n;++i){Token*t=GET(Token,token,&tokens,i);if(t->span.n!=t->name.n||memcmp(t->span.p,t->name.p,t->span.n))abort();checksum+=t->span.n+t->name.n+t->kind;}
Token t;for(size_t i=0;i<token_count/2;++i){if(!POP(token,&tokens,t))abort();checksum+=t.kind;drop_token(&t);}DROP(token,&tokens);Text name;while(POP(text,&names,name)){checksum+=name.n;drop_text(&name);}DROP(text,&names);for(size_t i=0;i<nodes.n;++i){Node*n=GET(Node,node,&nodes,i);checksum+=n->start+n->end+n->left+n->right+n->error.n;}DROP(node,&nodes);uint64_t objects=now()-begin;checksum+=stress();if(live||allocations!=releases)abort();printf("%"PRIu64" %"PRIu64" %"PRIu64" %"PRIu64" %"PRIu64"\n",checksum,token_count,allocations,numeric,objects);free(source);return 0;}
