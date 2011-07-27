#ifndef OV_H
#define OV_H
#include "stack.h"
typedef void (*ov_callback_t)(void *variation, s_stack * reads);
typedef void *(*ov_next_func)(void *stream);
typedef unsigned int (*ov_begin_func)(void *item);
typedef unsigned int (*ov_end_func)(void *item);
typedef void (*ov_free_func)(void *ptr);

typedef struct {
    ov_next_func next;
    ov_free_func free;
    ov_begin_func beginf;
    ov_end_func endf;
    void *stream_data;
} ov_stream_t;

typedef struct { 
    int begin;
    int end;
} ov_loc_type;

ov_stream_t *new_stream(ov_next_func mnext,
          ov_free_func mfree,
          ov_begin_func mbegin,
          ov_end_func mend,
          void * stream_data);
		  
void fire_callback_for_overlaps (ov_stream_t * v_stream, 
                                 ov_stream_t * r_stream, 
								 ov_callback_t callback);
#endif //defined OV_H
