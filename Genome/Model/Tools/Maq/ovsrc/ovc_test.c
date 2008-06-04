#include <stdio.h>
#include <stdlib.h>
#include "snplist.h"
#include "ov.h"
#include "maqmap.h"
#include "dedup.h"
#include "bfa.h"

int g_last_rseqid;
int g_last_vseqid;
int g_num_seqs;

void * next_r(void * r_stream) 
{
    ov_stream_t *stream = (ov_stream_t*)r_stream;
    maqmap1_t *m1 =malloc(sizeof(maqmap1_t));
    if(!m1) {printf("Couldn't allocate m1 record\n");return NULL;}    
    gzFile *fp = (gzFile *)(stream->stream_data);
    long long offset = gztell(fp);
    int size=0;
    if((size = gzread(fp,m1, sizeof(maqmap1_t))))
    {
        if(size != sizeof(maqmap1_t)) 
        {
            printf("size is only %d, seqid is %d\n",size,m1->seqid);
            //dealing with a truncated file
            free(m1);
            return NULL;
        }
        
        if(m1->seqid!=g_last_rseqid)
        {
            gzseek(fp,offset,SEEK_SET);
            free(m1);            
            return NULL;
        }        
        return (void*)m1;
    }
    else
    {
        free(m1);
        return NULL;
    }
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
    //HACK 
    snp_stream *s = (snp_stream *)stream->stream_data;
    snp_item *item = get_next_snp(s);
    if(item &&item->seqid!=g_last_vseqid)
    {
        fseek(s->fp,-(strlen(item->line)+1),SEEK_CUR);
        free(item);
        return NULL;        
    }
    return (void *)item;	
}

int advance_seqid(void *rstream, void *vstream)
{

    ov_stream_t *stream = (ov_stream_t*)rstream;
    maqmap1_t *m1 =malloc(sizeof(maqmap1_t));    
    gzFile *fp = (gzFile *)(stream->stream_data);
    stream = (ov_stream_t *)vstream;
    snp_stream *s = (snp_stream *)stream->stream_data;
    snp_item temp;
    snp_item *item = &temp;
    int size = 0;
    long long offset = 0;
    do
    {
        if(g_last_rseqid<=g_last_vseqid)
            while((offset = gztell(fp))&&(size = gzread(fp,m1, sizeof(maqmap1_t))))
            {
                if(size != sizeof(maqmap1_t)||size == 0) 
                {
                    printf("size is only %d, seqid is %d\n",size,m1->seqid);
                    //dealing with a truncated file
                    free(m1);
                    return 0;
                }
                if(m1->seqid>g_last_rseqid)
                {
                    gzseek(fp,offset,SEEK_SET);
                    g_last_rseqid = m1->seqid;
                    free(m1);
                    if(g_last_rseqid>=g_num_seqs) return 0;
                    break;
                }
            }
        
        if(g_last_rseqid>g_last_vseqid)
            while(item =get_next_snp(s))
            {
                if(item->seqid>g_last_vseqid)
                {
                    fseek(s->fp,-(strlen(item->line)+1),SEEK_CUR);
                    g_last_vseqid=item->seqid;
                    free(item);
                    if(g_last_vseqid>=g_num_seqs) return 0;
                    break;
                }        
            }
        if(!item || gzeof(fp))return 0;
    }
    while(g_last_vseqid != g_last_rseqid);
    
    return 1;
}

int init_seqid(void *rstream, void *vstream)
{

    ov_stream_t *stream = (ov_stream_t*)rstream;
    maqmap1_t m1;    
    gzFile *fp = (gzFile *)(stream->stream_data);
    stream = (ov_stream_t *)vstream;
    snp_stream *s = (snp_stream *)stream->stream_data;
    snp_item temp;
    snp_item *item = &temp;
    long long offset = 0;
    do
    {
        if(g_last_rseqid<g_last_vseqid)
            while((offset = gztell(fp))&&gzread(fp,&m1, sizeof(maqmap1_t)))
            {
                
                if(m1.seqid>g_last_rseqid)
                {
                    gzseek(fp,offset,SEEK_SET);
                    printf("setting rseqid %d %d\n", m1.seqid, g_last_rseqid);
                    g_last_rseqid = m1.seqid;                    
                    break;
                }
            }
        
        if(g_last_rseqid>g_last_vseqid)
            while((offset = ftell(s->fp))&&(item =get_next_snp(s)))
            {
                if(item->seqid>g_last_vseqid)
                {
                    fseek(s->fp,offset,SEEK_SET);
                    g_last_vseqid=item->seqid;
                    free(item);
                    break;
                }        
            }
        if(!item || gzeof(fp)){printf("error in init\n"); return 0;}
    }
    while(g_last_vseqid != g_last_rseqid);
    
    return 1;
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
    long long offset = 32-(position&0x1f);//position%32 
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
    //if(g_queue_is_empty(reads)) return;
    GList *item = g_queue_peek_head_link(reads);
    if(g_queue_is_empty(reads)) item = NULL;
    mreads->count = g_queue_get_length(reads);
    check_size(mreads);
    
    int current_pos = mreads->count-1;
    if (!g_queue_is_empty(reads)) do//yes, hacky
    {
        maqmap1_t *read = (maqmap1_t *)(item->data);
        mreads->reads[current_pos] = read;
        if(read->map_qual>10)current_pos--;
    }while(item = g_list_next(item));
    current_pos++;
    int i = 0;
    if(current_pos>0) for(i=0;i<(mreads->count)-current_pos;i++){ mreads->reads[i] = mreads->reads[i+current_pos]; }
    mreads->count-=current_pos;
    //check for the case where the last record doesn't overlap
    while(mreads->count>0&&(mreads->reads[mreads->count-1]->pos>>1)>var_overlap->end) { //printf("count is %d\n",current_pos);
    mreads->count--;}
    //if(mreads->count<=0) return;
    
    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 0);//A allele
    rc[0] = match_reads->count;//g_queue_get_length(reads);
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
    int iref_base= get_base(ref_base);
    printf("%s\t%d,%d,%d,%d\t\t",var_overlap->line, rc[0],rc[1],rc[2],rc[3]);
    printf("%d,%d,%d,%d\t%c\t",urc[0],urc[1],urc[2],urc[3],ref_base);
    printf("%d,%d,%d,%d\t\t",rc[iref_base],urc[iref_base],q[iref_base],mq[iref_base]);
    int unique_read_count = ur_old(mreads);
    printf("%d,%d,%d,%d\t\t%d,%d,%d,%d\t%d\n",v1[0],v1[1],v1[2],v1[3],v2[0],v2[1],v2[2],v2[3],unique_read_count);
}

int ovc_filter_variations(char *mapfilename,char *snpfilename)
//int main(int argc, char ** argv)
{
//    char * mapfilename = strdup(argv[1],256);
//    char * snpfilename = strdup(argv[2], 256);
    gzFile reffp = gzopen(mapfilename,"r");
    maqmap_t *mm = maqmap_read_header(reffp);
    g_num_seqs = mm->n_ref;
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
    //init seqids
    ov_stream_t *stream = (ov_stream_t*)r_stream;
    maqmap1_t *m1 =malloc(sizeof(maqmap1_t));    
    gzFile *fp = (gzFile *)(stream->stream_data);
    if(gzread(reffp,m1, sizeof(maqmap1_t)))
    {
        gzrewind(reffp);
        maqmap_read_header(reffp);
        free(m1);
        g_last_rseqid = m1->seqid;
    }
    else return 1;   

    snp_item *item = get_next_snp(snps);
    rewind(snps->fp);
    g_last_vseqid=item->seqid;
    free(item);
    if(!init_seqid(r_stream, v_stream))return 1;//make sure they are are equal
    do
    {
        fire_callback_for_overlaps(
            v_stream,
            r_stream,  
            callback_def  
        );
    } while(advance_seqid(r_stream,v_stream));
}
