#include <stdio.h>

#define NEXT(a) a->next(a);
#define FREE(a,b) a->free?a->free(b):free(b);
#define BEGIN(a,b) a->begin?a->begin(b):((loc_type *)b)->begin;
#define END(a,b) a->end?a->end(b):((loc_type *)b)->end;

ov_stream_t *new_stream(void * mnext,
          void * mfree,
          void * mbegin,
          void * mend,
          void * stream_data)
{
    ov_stream_t *s = malloc(sizeof(ov_stream_t));    
    s->next = mnext;
    s->free = mfree;
    s->begin = mbegin;
    s->end = mend;
    s->stream_data = stream_data;    
    return s;
}

void fire_callback_for_overlaps (ov_stream_t * v_stream, ov_stream_t * r_stream, ov_callback_t *callback)
{
    GQueue * overlapping_reads_queue = g_queue_new();
    void * next_v = NULL;
    void * next_r = NULL;
    while (next_v = NEXT(v_stream)) {
        while (!g_queue_is_empty(overlapping_reads_queue)&&
                END(r_stream, g_queue_peek_tail(overlapping_reads_queue)) <= BEGIN(v_stream, next_v)) {
            // clear the queue of reads which don't overlap this variation
            gpointer item = g_queue_pop_tail(overlapping_reads_queue);
            FREE(r_stream, item);
        }
        while (next_r = NEXT(r_stream)) {
            if (END(r_stream, next_r) <= BEGIN(v_stream, next_v)) {
                continue; # read ends before the variant begins
            }
            else if (BEGIN(r_stream, next_r) <= END(v_stream, next_v)) {
                // read ends on or after the variant's begins AND
                // read begins on or before the variant's end
                g_queue_push_head(overlapping_reads_queue, next_r);
                continue;
            }
            else {
                // read begins past the end of the variant
                // handle all reporting for this variant here
                callback(next_v,overlapping_reads_queue);
                
                // put this on the end of the list after we've processed it
                // this will get pruned if it doesn't overlap the next variant
                g_queue_push_head(overlapping_reads_queue, next_r);
                break;
            }
        }
    }
    while (!g_queue_is_empty(overlapping_reads_queue)&&
            END(r_stream, g_queue_peek_tail(overlapping_reads_queue)) <= BEGIN(v_stream, next_v)) {
            // clear the queue of reads which don't overlap this variation
            gpointer item = g_queue_pop_tail(overlapping_reads_queue);
            FREE(r_stream, item);
    }
    
    return 1;
}
