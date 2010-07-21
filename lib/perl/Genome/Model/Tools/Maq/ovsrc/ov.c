#include <stdio.h>
#include <stdlib.h>
#include "ov.h"
#include "maqmap.h"
#include "stack.h"

#define NEXT(a) a->next(a)
#define FREE(a,b) a->free?a->free(b):free(b)
#define BEGIN(a,b) (a->beginf?a->beginf(b):((ov_loc_type *)b)->begin)
#define END(a,b) (a->endf?a->endf(b):((ov_loc_type *)b)->end)

ov_stream_t *new_stream(ov_next_func mnext,
          ov_free_func mfree,
          ov_begin_func mbegin,
          ov_end_func mend,
          void *stream_data)
{
    ov_stream_t *s = malloc(sizeof(ov_stream_t));    
    s->next = mnext;
    s->free = mfree;
    s->beginf = mbegin;
    s->endf = mend;
    s->stream_data = stream_data;    
    return s;
}

void fire_callback_for_overlaps (ov_stream_t * v_stream, ov_stream_t * r_stream, ov_callback_t callback)
{
    s_stack * overlapping_reads_queue = create_stack(0);
    void * next_v = NULL;
    void * next_r = NULL;
    int rec_count = 0;
    int i = 0;

    while ((next_v = NEXT(v_stream))&&next_v) {
        rec_count = s_length(overlapping_reads_queue);
        i = 0;  int rem_count = 0;      
        while(i<rec_count&&BEGIN(r_stream, s_peek_nth(overlapping_reads_queue,i)) < BEGIN(v_stream, next_v))
        {
            i++;
            // clear the queue of reads which don't overlap this variation
            // we need to do an explicit check of whether or not the END of the reads queue is 
            // greater than the beginning of the variant since only the beginning of reads are 
            // sorted, not the ends
            if(END(r_stream, s_peek_nth(overlapping_reads_queue,i-1)) >= BEGIN(v_stream, next_v))
                continue;
            s_remove_nth(overlapping_reads_queue,i-1);rem_count++;
            //printf("Before free\n");
            //FREE(r_stream, item);
            //printf("After free\n");        
        }
        //printf("Removed %d reads.\n",rem_count);
        s_compact(overlapping_reads_queue);
        //TODO: check if last item in reads_queue is already greater than next_v, if so, fire callback
		// and continue
        next_r = s_peek_head(overlapping_reads_queue);
        if(s_length(overlapping_reads_queue) &&(BEGIN(r_stream,next_r)>BEGIN(v_stream, next_v)))
        {   
            callback(next_v,overlapping_reads_queue);
            continue;        
        }
        while (next_r = NEXT(r_stream)) {
            //printf ("rec_count %d\n",rec_count);
            //rec_count++;
            //printf("%s\n",((maqmap1_t *)next_r)->name);
            if (END(r_stream, next_r) < BEGIN(v_stream, next_v)) {
                //FREE(r_stream, next_r);
                continue; // read ends before the variant begins
            }
            else if (BEGIN(r_stream, next_r) <= END(v_stream, next_v)) {
                // read ends on or after the variant's begins AND
                // read begins on or before the variant's end
                static maqmap1_t temp_r;
                memcpy(&temp_r,next_r,sizeof(maqmap1_t));
                s_push_head(overlapping_reads_queue, &temp_r);
                //printf("Here2\n");
                continue;
            }
            else {
                // read begins past the end of the variant
                // handle all reporting for this variant here
                //printf("Here3\n");
                //callback(next_v,overlapping_reads_queue);
                //printf("After Callback\n");
                // put this on the end of the list after we've processed it
                // this will get pruned if it doesn't overlap the next variant
                
                //s_push_head(overlapping_reads_queue, next_r);
                
                break;
            }
        }
        //static int linenumber = 0;
        //linenumber++;
        //printf("line %d\n",linenumber);
        callback(next_v,overlapping_reads_queue);
        if(next_r) {
            maqmap1_t * temp_r = malloc(sizeof(maqmap1_t));
            memcpy(temp_r,next_r,sizeof(maqmap1_t));
            s_push_head(overlapping_reads_queue, temp_r);
            //g_queue_push_head(overlapping_reads_queue, next_r);
        }
		if(next_v) FREE(v_stream, next_v);
        //if(!next_r) break;
    }

    //printf("Here\n");
    ////while (!g_queue_is_empty(overlapping_reads_queue)) {
            // clear the queue of reads which don't overlap this variation
            ////gpointer item = g_queue_pop_tail(overlapping_reads_queue);
            //FREE(r_stream, item);
    ////}
    //should be gqueue_free, but for some reason it segfaults....
    free(overlapping_reads_queue);


}
