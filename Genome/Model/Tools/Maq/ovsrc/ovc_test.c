#include <stdio.h>
#include <stdlib.h>
#include "snplist.h"
#include "ov.h"
#include "maqmap.h"
#include "dedup.h"
#include "bfa.h"



void * next_r(void * r_stream) 
{
    ov_stream_t *stream = (ov_stream_t*)r_stream;
    maqmap1_t *m1 =malloc(sizeof(maqmap1_t));    
    gzFile *fp = (gzFile *)(stream->stream_data);
    return gzread(fp,m1, sizeof(maqmap1_t))?(void*)m1:NULL;
}

unsigned int begin_r(void * item)
{
    maqmap1_t *read = (maqmap1_t *)item;
    int position = read->pos>>1;
    return position;

}
unsigned int end_r(void * item)
{
    maqmap1_t *read = (maqmap1_t *)item;
    int position = read->pos>>1;
    return position+read->size-1;
}

void * next_v(void *pstream)
{
    ov_stream_t *stream = (ov_stream_t *)pstream;
    snp_stream *s = (snp_stream *)stream->stream_data;
	return get_next_snp(s);
}

typedef struct
{
    maqmap1_t **reads;
    int size; 
    int count;
} map_array;

map_array *mreads;
map_array *match_reads;
FILE *fpbfa;

void init_map_array(map_array *arr)
{
    arr->reads=NULL;
    arr->size=20;
    arr->count=0;
    arr->reads = realloc(arr->reads,arr->size*sizeof(maqmap1_t *));
}

void check_size(map_array *arr)
{
    if( arr->count>=arr->size)
    {
        arr->size = arr->count+20;
        arr->reads = realloc(arr->reads,arr->size*sizeof(maqmap1_t *));
    }
}

void get_matching_reads(map_array *reads, map_array *match_reads, int ref_position, int quality, int base)
{
    //we pass in the address of a pointer to a pointer to maqmap1_t array, ugghh
    int i =0;
    int base_comp = (~base)&3;//0123,acgt,complement of binary 00 is 11, 01 is 10, 10 is 01, 11 is 00
    maqmap1_t **preads = reads->reads;//makes things easier to read below
    match_reads->count =0;
    for(i=0;i<reads->count;i++)
    {
        check_size(match_reads);
        int base_pos = ref_position - (preads[i]->pos>>1);
        int strand = preads[i]->pos&1;
        int read_base = preads[i]->seq[base_pos]>>6&3;

        if(strand==0)
        {
            if(base == read_base) 
            {
                match_reads->reads[match_reads->count] = preads[i];
                match_reads->count++;
            }
        }
        else //strand ==1
        {
           if(base_comp == read_base)
           {
                match_reads->reads[match_reads->count] = preads[i];
                match_reads->count++;
           }
        }          
    }

}

void get_quality_stats(map_array *reads, int ref_position, int *q, int *mq)
{
    int i =0;
    maqmap1_t **preads = reads->reads;//makes things easier to read below
    double total_qual = 0.0;
    double max_qual = 0.0;
    for(i=0;i<reads->count;i++)
    {  
        int base_pos = ref_position - (reads->reads[i]->pos>>1);
        int read_base = preads[i]->seq[base_pos]>>6&3;
        int read_qual = preads[i]->seq[base_pos]&0x3f;
        total_qual+=read_qual;
        max_qual = max_qual<read_qual?read_qual:max_qual;          
    }
    *mq = max_qual;
    *q = reads->count?(int)(total_qual/(double)(reads->count)):0;
}

static int get_base(char base)
{
    if(tolower(base)=='a') return 0;
    if(tolower(base)=='c') return 1;
    if(tolower(base)=='g') return 2;
    if(tolower(base)=='t') return 3;
    
    return -1;
}

static char get_ref_base(long long position, char *name, int seqid)
{
    static int last_seqid;
    //static char last_base;
    static nst_bfa1_t *last_bfa1=NULL;
    nst_bfa1_t *bfa1=NULL;
    if(last_seqid == seqid&&last_bfa1)
    {
         bfa1 = last_bfa1;  
    }
    else
    {
        if(last_bfa1) nst_delete_bfa1(last_bfa1);
        while(bfa1 = nst_load_bfa1(fpbfa))
        {
            if(!strcmp(bfa1->name,name)) break;
            nst_delete_bfa1(bfa1);
        }
        last_bfa1 = bfa1;
        last_seqid = seqid;                
    }
    if(!bfa1) 
    {
        printf("Could not find seq %s\n", name);
        return 4;
    }        
	bit64_t word = bfa1->seq[position>>5];
    bit64_t mask = bfa1->mask[position>>5];
    int offset = 32-(position&0x1f);//position%32 
    return (mask>>(offset<<1)&3)? "ACGT"[word>>(offset<<1)&3] : 'N'; 
}

int ur_old(map_array *reads)
{
    int i = 0;
    static GHashTable *hash = NULL;
    hash = hash?hash:g_hash_table_new(g_str_hash,g_str_equal);
    for(i = 0;i<reads->count;i++)
    {
        g_hash_table_insert(hash,reads->reads[i]->name,NULL);
    }
    int ur = g_hash_table_size(hash);
    g_hash_table_remove_all(hash);
    return ur;
}

void callback_def (void *variation, GQueue * reads)
{
    int rc[4];//acgt
    int urc[4];//acgt
    int q[4];//acgt
    int mq[4];//acgt
    int v1base;
    int v2base;
    int v1[4];//RC,URC,Q, MQ
    int v2[4];//RC,URC,Q, MQ
    char ref_base;
    
    mreads->count = 0;
    match_reads->count = 0;    
    snp_item * var_overlap = (snp_item *)variation;  
    v1base = get_base(var_overlap->var1);
    v2base = get_base(var_overlap->var2);
    //printf("%d - %d\n", var_overlap->begin, var_overlap->end);
    if(g_queue_is_empty(reads)) return;
    GList *item = g_queue_peek_head_link(reads);
    mreads->count = g_queue_get_length(reads);
    check_size(mreads);
    
    int current_pos = 0;
    do
    {
        maqmap1_t *read = (maqmap1_t *)(item->data);
        mreads->reads[current_pos] = read;
        current_pos++;
    }while(item = g_list_next(item));

    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 0);//A allele
    rc[0] = g_queue_get_length(reads);
    get_quality_stats(match_reads, var_overlap->begin,&q[0],&mq[0]);
    urc[0] = dedup_count(match_reads->reads, match_reads->count, 26);

    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 1);//C allele
    rc[1] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[1],&mq[1]);
    urc[1] = dedup_count(match_reads->reads, match_reads->count, 26);    
    
    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 2);//G allele
    rc[2] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[2],&mq[2]);
    urc[2] = dedup_count(match_reads->reads, match_reads->count, 26);

    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 3);//T allele
    rc[3] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[3],&mq[3]);
    urc[3] = dedup_count(match_reads->reads, match_reads->count, 26);
//header:      RC(A,C,G,T) URC(A,C,G,T) REF Ref(RC,URC,Q,MQ) Var1(RC, URC,Q,MQ) Var2(RC,URC,Q,MQ) URCbyContent
//csv_in_line  2,0,3,4     4,0,3,3      A   2,4,30,30        2,2,30,30           2,2,30,30         3    
    v1[0] = rc[v1base];v1[1]=urc[v1base];v1[2]=q[v1base];v1[3]=mq[v1base]; 
    v2[0] = rc[v2base];v2[1]=urc[v2base];v2[2]=q[v2base];v2[3]=mq[v2base];
    ref_base = get_ref_base(var_overlap->begin, var_overlap->name, var_overlap->seqid);
    int iref_base = get_base(ref_base);
    printf("%s\t%d,%d,%d,%d\t\t",var_overlap->line, rc[0],rc[1],rc[2],rc[3]);
    printf("%d,%d,%d,%d\t%c\t",urc[0],urc[1],urc[2],urc[3],ref_base);
    printf("%d,%d,%d,%d\t\t",rc[iref_base],urc[iref_base],q[iref_base],mq[iref_base]);
    int unique_read_count = ur_old(mreads);
    printf("%d,%d,%d,%d\t\t%d,%d,%d,%d\t%d\n",v1[0],v1[1],v1[2],v1[3],v2[0],v2[1],v2[2],v2[3],unique_read_count);
}

int ovc_filter_variations(char *mapfilename,char *snpfilename)
{
    gzFile reffp = gzopen(mapfilename,"r");
    maqmap_t *mm = maqmap_read_header(reffp);
    mreads = calloc(1,sizeof(map_array));
    match_reads = calloc(1,sizeof(map_array));
    init_map_array(mreads);
    init_map_array(match_reads);
    
    fpbfa = fopen("/gscmnt/sata114/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.bfa","r");
	//nst_load_bfa(fpbfa);
    snp_stream *snps = calloc(1,sizeof(snp_stream));
	snps->fp = fopen(snpfilename,"r");
	snps->num_refs = mm->n_ref;
	snps->ref_names = mm->ref_name;
    ov_stream_t * r_stream = new_stream(&next_r, NULL, &begin_r, &end_r, reffp );
    ov_stream_t * v_stream = new_stream(&next_v, NULL, NULL, NULL, snps);
    fire_callback_for_overlaps(
        v_stream,
        r_stream,  
        callback_def  
    );
}
