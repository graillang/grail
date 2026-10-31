#include <stdint.h>
#include <string.h>
#include <stdio.h>
static uint64_t mono(uint64_t value,uint64_t*target){*target=99;return value;}
static uint64_t erased(const void*value,uint64_t*target){*target=99;uint64_t out;memcpy(&out,value,sizeof(out));return out;}
int main(void){uint64_t x=7;uint64_t direct=mono(x,&x);x=7;uint64_t wrong=erased(&x,&x);x=7;uint64_t argument=x;uint64_t correct=erased(&argument,&x);if(direct!=7||wrong!=99||correct!=7)return 1;printf("%llu %llu %llu\n",(unsigned long long)direct,(unsigned long long)wrong,(unsigned long long)correct);}
