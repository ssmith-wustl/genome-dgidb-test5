#include <stdio.h>
#include <stdlib.h>
#include "ov.h"
#include "maqmap.h"
#include "stack.h"

//need to implement gq look alike
// total hack, uggh, but gqueue sucks..

s_stack * create_stack(int size)
{
    s_stack * stack = malloc(1*sizeof(s_stack));
    stack->stack = malloc(15000000*sizeof(s_element));
    stack->mem_size = 15000000;
    stack->offset = 0;
    stack->size = 0;
}

int s_length(s_stack * stack)
{
    return stack->size;      
}

void * s_peek_nth(s_stack * stack, int index)
{
    int true_index = stack->offset+index;
    if(true_index>=stack->mem_size)
    {
        return (void *)&(stack->stack[true_index-stack->mem_size].data);
    }
    else
    {
        return (void *)&(stack->stack[true_index].data);
    }
}

void s_set_nth(s_stack * stack, int index, void * element)
{
    int true_index = stack->offset+index;
    if(true_index>=stack->mem_size)
    {
        memcpy(&stack->stack[true_index-stack->mem_size].data,element,sizeof(maqmap1_t));
        stack->stack[true_index-stack->mem_size].used = 1;
    }
    else
    {
        memcpy(&stack->stack[true_index].data,element,sizeof(maqmap1_t));
        stack->stack[true_index].used = 1;
    }
    return;
}

void * s_peek_head(s_stack *stack)
{
    return s_peek_nth(stack,stack->size-1);
}

void s_remove_nth(s_stack *stack, int index)
{
    int true_index = stack->offset+index;
    if(true_index>=stack->mem_size)
    {
        
        stack->stack[true_index-stack->mem_size].used = 0;    
    }
    else
    {        
        stack->stack[true_index].used = 0;
    }
    return;    
}

int __s_peek_nth_used(s_stack *stack,int index)
{
    int true_index = stack->offset+index;
    if(true_index>=stack->mem_size)
    {   printf("Wrapped around.\n\n\n\n\n");
        return stack->stack[true_index-stack->mem_size].used;
    }
    else
    {
        return stack->stack[true_index].used;
    }

}

int s_compact(s_stack *stack)
{
    int rem_count = 0;
    int prev_index = stack->offset;
    int i;
    for(i=stack->offset;(i%stack->mem_size)<(stack->size+stack->offset);i++)
    {
        if(__s_peek_nth_used(stack,i) == 0)
        {
            rem_count++;//printf("Removing read.\n");
        }
        else 
        {
            s_set_nth(stack,prev_index%stack->mem_size,s_peek_nth(stack,i%stack->mem_size));
            prev_index++;//printf("Keeping read. %d\n", i);
        }               
    }
    //printf("In s_compact, removed %d reads.\n", rem_count);
    stack->size-=rem_count;
    if(stack->size < 0)printf("SIZE IS LESS THAN ZERO!!! \n\n\n\n\n\n");
    return 1;
}

void s_push_head(s_stack *stack, void *element)
{
    stack->size++;
    if(stack->size>=stack->mem_size)
    {
        printf("Stack overflow error.  Exiting... \n");
        exit(1);
    }
    else
    {
        s_set_nth(stack, stack->size-1,element);
    }
}

