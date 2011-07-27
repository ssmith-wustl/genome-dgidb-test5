#include <stdio.h>
#include <stdlib.h>
#include "ov.h"
#include "maqmap.h"
#ifndef STACK_H
#define STACK_H
//need to implement gq look alike
// total hack, uggh, but gqueue sucks..
typedef struct
{
    maqmap1_t data;
    int used;
} s_element;

typedef struct
{
    int size;
    int mem_size;
    int offset;
    s_element * stack;
} s_stack;

s_stack * create_stack(int size);
int s_length(s_stack * stack);
void * s_peek_nth(s_stack * stack, int index);
void s_set_nth(s_stack * stack, int index, void * element);
void * s_peek_head(s_stack *stack);
void s_remove_nth(s_stack *stack, int index);
int __s_peek_nth_used(s_stack *stack,int index);
int s_compact(s_stack *stack);
void s_push_head(s_stack *stack, void *element);

#endif //defined STACK_H
