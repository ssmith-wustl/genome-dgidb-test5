#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

#undef MAX_READLEN
int MAX_READLEN =64;
int MAX_READLEN2 =64;

int glob_keep_records;
int glob_del_records;

/**********************************************************************/
/* data structure and funcs for managing a list of sequences might be overkill, but oh well**/

typedef int bl_pos;
typedef struct
{
    int size;
    int used;
    maqmap1_t *_list;    
} bl_list;

void bl_realloc_list(bl_list *list, int size);

void get_read_lc(maqmap1_t *mm, char * string)
{
    int j = 0;
    for (j = 0; j != mm->size; ++j) {
        if (mm->seq[j] == 0) string[j] ='n';
        else string[j]="acgt"[mm->seq[j]>>6&3];
    }
    string[mm->size]=0x00;
    return;    
}


void bl_add(bl_list *list, maqmap1_t *rec) //adds to list
{
    list->used++;
    if(list->used>list->size)
    {
        list->size = (int)(list->size*1.5);
        bl_realloc_list(list, list->size);
    }
    memcpy(&(list->_list[list->used-1]),rec,sizeof(maqmap1_t));   
}

void bl_replace(bl_list *list, maqmap1_t *rec,bl_pos position)
{
   memcpy(&(list->_list[position]), rec,sizeof(maqmap1_t));
}

maqmap1_t *bl_get_at_pos(bl_list *list, bl_pos position)
{
    if(position>=0&&position<list->used)
        return &list->_list[position];
    return NULL;
}

bl_pos bl_find_seq_comp(bl_list *list, maqmap1_t *rec, int comparison_length)
{    
    static char rec_string[64];//64 is MAX_READLEN
    static char cmp_string[64];
    get_read_lc(rec, rec_string);
    int i =0;
    for(i=0;i<list->used;i++)
    {
        if(list->_list[i].size != rec->size) continue;
        int length = rec->size<comparison_length?rec->size:comparison_length;
        length = list->_list[i].size<length?list->_list[i].size:length;
        get_read_lc(&list->_list[i],cmp_string);
        if(((rec->pos)&1))
        {
            int offset = length<comparison_length?0:(length-comparison_length);
            if(!memcmp(&rec_string[offset],&cmp_string[offset],length))
                return i;            
        }
        else
            if(!memcmp(rec_string, cmp_string, length))
                return i;
    }
    return -1;
}

bl_pos bl_find(bl_list *list, maqmap1_t *rec, int comparison_length)
{    
    static char rec_string[64];//64 is MAX_READLEN
    static char cmp_string[64];
    get_read_lc(rec, rec_string);
    int i =0;
    if(list->used>=1) return 0;
    
    return -1;
}

bl_list * bl_create_list(int size)
{
    bl_list * list = malloc(sizeof(maqmap1_t));
    list->size =0;
    list->used =0;
    list->_list = NULL;
    bl_realloc_list(list, size);
    return list;
}

void bl_reset(bl_list * list)
{
   list->used = 0; 
}

void bl_realloc_list(bl_list *list, int size)
{    
    list->size = size;
    list->_list = (maqmap1_t *)realloc((void *)list->_list, sizeof(maqmap1_t)*size);    
}

int bl_dump_list(bl_list *list, gzFile fp)
{
    if(!fp)return list->used;
    int i = 0;
    for(i=0;i<list->used;i++)
    {
        put_record(fp,&list->_list[i]);        
    }
    return list->used;
}

void bl_free_list(bl_list *list)
{
    if(list->size) free(list->_list);
    list->size = 0;
    list->used = 0;
    free(list);
}

int bl_used(bl_list *list)
{
    return list->used;
}
/**********************************************************************/
typedef struct
{
    int size;
    bl_list **lists;    
} bl_array;



bl_array *bl_array_create(int size)
{
    bl_array * array = (bl_array *)malloc(sizeof(bl_array));
    array->size = size;
    array->lists = malloc(size*sizeof(bl_list *));
    
    int i = 0;
    for(i=0;i<size;i++)
    {
        array->lists[i] = bl_create_list(100);
    }
    return array;
}
int bl_array_prune_all(bl_array *array, int last_position, gzFile outfp)
{
    last_position = last_position%(MAX_READLEN*4);
    last_position = last_position<0?last_position+MAX_READLEN*4:last_position; 
    int i =0;
    int num_records_pruned = 0;
    for(i=last_position;i<last_position+MAX_READLEN*4;i++)
    {
        num_records_pruned += bl_dump_list(array->lists[i%(MAX_READLEN*4)],outfp);
        bl_reset(array->lists[i%(MAX_READLEN*4)]);
    }
    return num_records_pruned;
}

int bl_array_prune(bl_array *array, int last_position, int curr_position, gzFile outfp)
{   
    if(curr_position<MAX_READLEN*2) return bl_array_prune_all(array,curr_position,outfp);
    if((curr_position-last_position)>4*MAX_READLEN) curr_position = last_position + MAX_READLEN*4;    
        
    int length = curr_position-last_position;
    last_position = last_position%(MAX_READLEN*4); 
    
    last_position = last_position<0?last_position+MAX_READLEN*4:last_position;
    curr_position = curr_position<0?curr_position+MAX_READLEN*4:curr_position;
    int i =0;
    int num_records_pruned = 0;
    for(i=last_position;i<last_position+length;i++)
    {
        num_records_pruned += bl_dump_list(array->lists[i%(MAX_READLEN*4)],outfp);
        bl_reset(array->lists[i%(MAX_READLEN*4)]);
    }
    return num_records_pruned;
}
int bl_array_prune2(bl_array *array, int last_position, int curr_position, gzFile outfp)
{   
    //if(curr_position<MAX_READLEN*2) return bl_array_prune_all(array,curr_position,outfp);
    if((curr_position-last_position)>4*MAX_READLEN) curr_position = last_position + MAX_READLEN*4;    
        
    int length = curr_position-last_position;
    last_position = last_position%(MAX_READLEN*4); 
    
    last_position = last_position<0?last_position+MAX_READLEN*4:last_position;
    curr_position = curr_position<0?curr_position+MAX_READLEN*4:curr_position;
    int i =0;
    int num_records_pruned = 0;
    for(i=last_position;i<last_position+length;i++)
    {
        num_records_pruned += bl_dump_list(array->lists[i%(MAX_READLEN*4)],outfp);
        bl_reset(array->lists[i%(MAX_READLEN*4)]);
    }
    return num_records_pruned;
}


void process_record(bl_array *array, bl_array *del_array, maqmap1_t *rec, int comparison_length)
{
    
    int position;
    bl_pos matching_best_pos;
    if(rec->pos&0x01) position = rec->pos+rec->size*2-2;//pos+size -2 since it's inclusive 
    else position = rec->pos;
    
    position = position%(MAX_READLEN*4);
    if((matching_best_pos = bl_find( array->lists[position], rec, comparison_length)) != -1)
    {
        maqmap1_t *matching_best = bl_get_at_pos(array->lists[position], matching_best_pos);
        if(matching_best != NULL &&
           rec->seq[MAX_READLEN-1]>matching_best->seq[MAX_READLEN-1])
        {
            bl_add(del_array->lists[position], matching_best);
            bl_replace(array->lists[position], rec,matching_best_pos);
        }
        else
        {
            bl_add(del_array->lists[position],rec);
        }            
    } 
    else
        bl_add(array->lists[position], rec);
}

void bl_array_free(bl_array *array)
{    
    int i = 0;
    for(i=0;i<array->size;i++)
    {
        bl_free_list(array->lists[i]);
    }
    free(array);
}

int dedup_count(maqmap1_t **reads, int read_count, int comparison_length)
{  
    //initialize lists
    
    static bl_array *keep_list = NULL;
    keep_list = keep_list?keep_list:bl_array_create(4*MAX_READLEN);
    static bl_array *del_list = NULL;
    del_list = del_list?del_list:bl_array_create(4*MAX_READLEN);    
        
    int total_records = 1;
    int best_records = 0;
    int del_records = 0;
    int i = 0;
    for(i=0;i<read_count;i++)
    {
        process_record(keep_list, del_list, reads[i], comparison_length);         
    }
    best_records += bl_array_prune_all(keep_list, 0,NULL);
    //bl_array_free(del_list);
    //bl_array_free(keep_list);    
    
    return best_records;
}


/**********************************************************************/
void fragdedup_yav(gzFile fpin, gzFile fpkeepseq, gzFile fpdelseq, int comparison_length) //yav = yet another version
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = 0;
    maqmap_write_header(fpkeepseq, mm);
    maqmap_write_header(fpdelseq, mm);
    maqmap1_t curr_mm, last_mm;    
    //initialize lists
    
    bl_array *keep_list = bl_array_create(4*MAX_READLEN);
    bl_array *del_list = bl_array_create(4*MAX_READLEN);    
        
    int total_records = 1;
    int best_records = 0;
    int del_records = 0;
    
    get_record(fpin, &curr_mm);
    memcpy(&last_mm, &curr_mm, sizeof(curr_mm));
    process_record(keep_list, del_list, &curr_mm, comparison_length);

    while(get_record(fpin, &curr_mm))
    {
        total_records++;
        if((int)curr_mm.seqid == (int)last_mm.seqid && curr_mm.pos != last_mm.pos)
        {
            best_records += bl_array_prune(keep_list, last_mm.pos,curr_mm.pos,fpkeepseq);
            del_records += bl_array_prune(del_list, last_mm.pos,curr_mm.pos,fpdelseq);
            
        }
        else if((int)curr_mm.seqid != (int)last_mm.seqid)
        {
            best_records += bl_array_prune_all(keep_list, last_mm.pos,fpkeepseq);
            del_records += bl_array_prune_all(del_list, last_mm.pos,fpdelseq);        
        }
        process_record(keep_list, del_list, &curr_mm, comparison_length); 
        memcpy(&last_mm, &curr_mm, sizeof(curr_mm));        
    }
    best_records += bl_array_prune_all(keep_list, last_mm.pos,fpkeepseq);
    del_records += bl_array_prune_all(del_list, last_mm.pos,fpdelseq);
    bl_array_free(keep_list);
    bl_array_free(del_list);
    
    printf("Kept %d records, removed %d records, total %d records.\n", best_records, del_records, total_records);    
    glob_keep_records = best_records;
    glob_del_records = del_records;
    
    return;   
}


/**********************************************************************/
void fragdedup(gzFile fpin, gzFile fpkeepseq, gzFile fpdelseq, int comparison_length) 
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = 0;
    maqmap_write_header(fpkeepseq, mm);
    maqmap_write_header(fpdelseq, mm);
    maqmap1_t curr_mm, last_mm;
    bl_list *best_list = bl_create_list(100);
    bl_pos matching_best_pos = -1;
    int total_records = 1;
    
    int best_records = 0;
    int del_records = 0;
    
    get_record(fpin, &curr_mm);
    bl_add(best_list, &curr_mm);
    while(get_record(fpin, &curr_mm))
    {
        total_records++;
        if((int)curr_mm.seqid != (int)last_mm.seqid || curr_mm.pos != last_mm.pos)
        {
            best_records += bl_used(best_list); 
            bl_dump_list(best_list, fpkeepseq);
            bl_reset(best_list); 
            bl_add(best_list, &curr_mm); 
            memcpy(&last_mm, &curr_mm, sizeof(curr_mm));
        }
        else if((matching_best_pos = bl_find( best_list, &curr_mm, comparison_length)) != -1)
        {
            maqmap1_t *matching_best = bl_get_at_pos(best_list, matching_best_pos);
            if(matching_best != NULL &&
               curr_mm.seq[MAX_READLEN-1]>matching_best->seq[MAX_READLEN-1])
            {
                del_records++;
                put_record(fpdelseq, matching_best);
                bl_replace(best_list, &curr_mm,matching_best_pos);
            }
            else
            {
                del_records++;
                put_record(fpdelseq, &curr_mm);                           
            }            
        } 
        else
            bl_add(best_list, &curr_mm);       
        
    }
    best_records += bl_used(best_list);
    bl_dump_list(best_list, fpkeepseq);    
    bl_free_list(best_list);
    printf("Kept %d records, removed %d records, total %d records.\n", best_records, del_records, total_records);    
    return;   
}

/**********************************************************************/

void sort_frags(gzFile fpin, gzFile fpsortseq, int rec_num) 
{

    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = rec_num;
    maqmap_write_header(fpsortseq, mm);
    MAX_READLEN = 1600;
    int MAX_READLEN2 = 400;
    
    maqmap1_t curr_mm, last_mm;
    bl_array *sort_list = bl_array_create(4*MAX_READLEN);
    
    get_record(fpin, &curr_mm);
    int position = (curr_mm.pos);
    position = position%(MAX_READLEN*4);
    position = position <0?position+MAX_READLEN*4:position;
    bl_add(sort_list->lists[position], &curr_mm);
    memcpy(&last_mm, &curr_mm, sizeof(curr_mm));
    
    int max_position_so_far = 0;
    int total_records = 1;
    while(get_record(fpin, &curr_mm))
    {
        total_records++;
        if((int)curr_mm.seqid == (int)last_mm.seqid && ((int)curr_mm.pos > (int)max_position_so_far))
        {
            //printf("removing %d to %d\n", (max_position_so_far-MAX_READLEN2*2-5), ((curr_mm.pos-MAX_READLEN2*2+5)));
            bl_array_prune2(sort_list, max_position_so_far-MAX_READLEN2*2-5, curr_mm.pos-MAX_READLEN2*2+5,fpsortseq ); 
            max_position_so_far = curr_mm.pos;               
        }        
        else if((int)curr_mm.seqid != (int)last_mm.seqid) 
        {
            bl_array_prune_all(sort_list, max_position_so_far-MAX_READLEN*2,fpsortseq);                   
            max_position_so_far = 0;
        }
        int position = (curr_mm.pos);
        position = position%(MAX_READLEN*4);
        position = position <0?(position+MAX_READLEN*4):position;
        bl_add(sort_list->lists[position], &curr_mm);        
        memcpy(&last_mm, &curr_mm, sizeof(curr_mm));                
    }
    
    bl_array_prune_all(sort_list, max_position_so_far-MAX_READLEN*2,fpsortseq);
    bl_array_free(sort_list);
    printf("Sorted %d records.\n",total_records);
    return;   
}



/**********************************************************************/
int fragdedup_original(gzFile fpin, gzFile fpkeepseq, gzFile fpdelseq) 
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = 0;
    maqmap_write_header(fpkeepseq, mm);
    maqmap_write_header(fpdelseq, mm);
    maqmap1_t curr_mm, best_mm;
    int total_records=1;
    int best_records = 0;
    int del_records = 0;
    
    
    get_record(fpin, &best_mm);

    while(get_record(fpin, &curr_mm))
    {
        total_records++;
        if((int)curr_mm.seqid != (int)best_mm.seqid || curr_mm.pos != best_mm.pos)
        {
            best_records++; 
            put_record(fpkeepseq, &best_mm);
            memcpy(&best_mm, &curr_mm, sizeof(curr_mm));            
        }
        else if( curr_mm.seq[MAX_READLEN-1]>best_mm.seq[MAX_READLEN-1] ||
            (curr_mm.seq[MAX_READLEN-1]==best_mm.seq[MAX_READLEN-1] &&
             curr_mm.size > best_mm.size))
        {            
            del_records++;
            put_record(fpdelseq, &best_mm);
            memcpy(&best_mm, &curr_mm, sizeof(curr_mm));            
        }
        else
        {
            del_records++;
            put_record(fpdelseq,&curr_mm);
        }
    }
    best_records++;
    put_record(fpkeepseq, &best_mm);
    printf("Kept %d records, removed %d records, total %d records.\n", best_records, del_records, total_records);    
    return 1;   
}
/**********************************************************************/
void sort_frags_files (char *infile, char *keepfile,int size )
{
    int i;
    MAX_READLEN = 64;
    
    
    
    
    gzFile fpin = gzopen(infile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",infile); return; }

    gzFile fpkeepseq = gzopen(keepfile, "w");
    if (fpkeepseq == NULL) { printf("Unable to open file '%s'\n",keepfile); return; }

    sort_frags(fpin,fpkeepseq,0);

    gzclose(fpin);
    gzclose(fpkeepseq);

    return;
}

int find_ref_seq_id(char *ref_seq_name, maqmap_t * mm)
{
    int i = 0;
    for(i=0;i<mm->n_ref;i++)
    {
        if(!strcmp(ref_seq_name, mm->ref_name[i]))
            return i;
    }
    return -1;
}

int get_next_seq_pos(FILE *fh, int *seq, int *pos, maqmap_t *mm)
{
    static char templine[180];
    static char ref_seq_name[180];
    if(fgets(templine, sizeof(templine), fh))
    {
        if(sscanf(templine, "%s %d", ref_seq_name, pos)==2)
        {
            
            *seq = find_ref_seq_id(ref_seq_name, mm);
            if(*seq == -1) 
                printf("Didn't find %s\n",ref_seq_name);
            else 
                printf("Found %s\n",ref_seq_name);
            if(*seq != -1) return 1;           
        }
    }
    return 0;
}

/**********************************************************************/
void print_seq_names (char *maqfile, char *seqfile)
{
    gzFile fpin = NULL;
    FILE *fp = NULL;
    maqmap_t  *mm = NULL;
    fpin = gzopen(maqfile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",maqfile); goto cleanup; }
    
    fp = fopen(seqfile, "r");
    if (fp == NULL) { printf("Unable to open file '%s'\n",seqfile); goto cleanup; }
    
    mm = maqmap_read_header(fpin);    
    if(mm == NULL) { printf("Unable to get header from maq file.\n"); goto cleanup; }
    maqmap1_t curr_mm;    
    int seqid, pos, ret;
    ret = get_next_seq_pos(fp, &seqid, &pos, mm);        
    if(!ret) goto cleanup;
    
    while(get_record(fpin, &curr_mm))
    {
        while(seqid < curr_mm.seqid || (seqid == curr_mm.seqid && pos < curr_mm.pos>>1))
        {
            if(!(ret = get_next_seq_pos(fp, &seqid, &pos, mm))) break;                    
        }        
        if(seqid == curr_mm.seqid && pos == curr_mm.pos>>1)
        {
            printf("%s %d %d\n", curr_mm.name, curr_mm.seqid, curr_mm.pos>>1);
        } 
        // before and after read count for a given start site position
        // chromosme, position, read count before, read count after                
    }                

cleanup:
    if(mm) maq_delete_maqmap(mm);
    if(fpin) gzclose(fpin);
    if(fp) fclose(fp);
    return;
}

/**********************************************************************/
void print_ref_names(char * maqfile) 
{
    gzFile fpin = gzopen(maqfile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",maqfile); return; }
    maqmap_t  *mm = maqmap_read_header(fpin);
    int l = 0;
    for(l=0;l<mm->n_ref;l++)
    {
        printf("%s\n",mm->ref_name[l]);
    }
    
    fclose(fpin);
}

