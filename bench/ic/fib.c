#include <stdio.h>
#include <stdlib.h>
static unsigned long fib(unsigned long n){return n<2?n:fib(n-1)+fib(n-2);}
int main(int c,char**v){unsigned long n=strtoul(v[1],0,10),a=0;for(unsigned long i=0;i<n;i++)a+=fib(20+(i&0));printf("%lu\n",a);}
