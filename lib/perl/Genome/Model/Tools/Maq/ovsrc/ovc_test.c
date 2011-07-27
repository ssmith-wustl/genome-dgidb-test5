#include <stdio.h>
#include <stdlib.h>
#include "snplist.h"
#include "ov.h"
#include "maqmap.h"
#include "dedup.h"
#include "bfa.h"
#include "stack.h"
#include <glib.h>

int g_last_rseqid;
int g_last_vseqid;
int g_num_seqs;
int g_qual_cutoff;
maqmap1_t *g_m1;

void * next_r(void * r_stream) 
{
    ov_stream_t *stream = (ov_stream_t*)r_stream;
    static maqmap1_t junk;
    maqmap1_t *m1 =&junk;
    //if(!g_m1) m1=malloc(sizeof(maqmap1_t));
    if(!m1&&!g_m1) {fprintf(stderr,"Couldn't allocate m1 record\n");return NULL;}    
    gzFile *fp = (gzFile *)(stream->stream_data);
    int size=sizeof(maqmap1_t);
    if(g_m1||(size = gzread(fp,m1, sizeof(maqmap1_t))))
    {
        if(g_m1)
            m1=g_m1;
        if(size != sizeof(maqmap1_t)) 
        {
            //printf("size is only %d, seqid is %d\n",size,m1->seqid);
            //dealing with a truncated file
            //free(m1);
            return NULL;
        }
        
        if(m1->seqid!=g_last_rseqid)
        {
            //printf("gseqids don't match, returning NULL\n");
            g_m1=m1;
            return NULL;
        }
        if(g_m1)
            g_m1 = NULL;            
        
        if(m1->map_qual<g_qual_cutoff) m1->pos=0;//hacky, but should avoid the situation where crap reads are clogging up the queue       
        return (void*)m1;//printf("Returning %s\n",m1->name);
    }
    else
    {
        //free(m1);
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
    long long offset = ftell(s->fp);
    snp_item *item = get_next_snp(s);
    //printf("snp is %s\n",item->line);
    if(item &&item->seqid!=g_last_vseqid)
    {
        fprintf(stderr,"vseqids don't match, returning NULL %d\n",strlen(item->line));    
        fseek(s->fp,offset,SEEK_SET);
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
    int size = sizeof(maqmap1_t);
    do
    {
        if(g_last_rseqid<=g_last_vseqid)
        {
            if(g_m1)
            {
                memcpy(m1,g_m1,sizeof(maqmap1_t));
                free(g_m1);
                g_m1 = NULL;
            }
            else
                size = gzread(fp,m1, sizeof(maqmap1_t));                    
            do
            {                
                if(size != sizeof(maqmap1_t)||size == 0) 
                {
                    //fprintf(stderr,"size is only %d, seqid is %d\n",size,m1->seqid);
                    //dealing with a truncated file
                    free(m1);
                    return 0;
                }
                if(m1->seqid>g_last_rseqid)
                {
                    g_m1 = m1;                    
                    g_last_rseqid = m1->seqid;                    
                    if(g_last_rseqid>=g_num_seqs) return 0;
                    break;
                }
            } while((size = gzread(fp,m1, sizeof(maqmap1_t))));
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
    maqmap1_t *m1 =malloc(sizeof(maqmap1_t));    
    gzFile *fp = (gzFile *)(stream->stream_data);
    stream = (ov_stream_t *)vstream;
    snp_stream *s = (snp_stream *)stream->stream_data;
    snp_item temp;
    snp_item *item = &temp;
    int size =sizeof(maqmap1_t);
    do
    {
    
        if(g_last_rseqid<g_last_vseqid)
        {
            if(g_m1)
            {
                free(m1);
                m1=g_m1;
                g_m1 = NULL;
            }
            else
                size = gzread(fp,m1, sizeof(maqmap1_t));                    
            do
            {                
                if(size != sizeof(maqmap1_t)||size == 0) 
                {
                    //fprintf(stderr,"size is only %d, seqid is %d\n",size,m1->seqid);
                    //dealing with a truncated file
                    free(m1);
                    return 0;
                }
                if(m1->seqid>g_last_rseqid)
                {
                    g_m1 = m1;                    
                    g_last_rseqid = m1->seqid;                    
                    if(g_last_rseqid>=g_num_seqs) return 0;
                    break;
                }
            } while((size = gzread(fp,m1, sizeof(maqmap1_t))));
        }        
        
        if(g_last_rseqid>g_last_vseqid)
            while(1)
            {
                long long offset = ftell(s->fp);
                item =get_next_snp(s);
                if(!item) return 0;
                if(item->seqid>g_last_vseqid)
                {
                    fseek(s->fp,offset,SEEK_SET);
                    g_last_vseqid=item->seqid;
                    free(item);
                    break;
                }        
            }
        if(!item || gzeof(fp)){fprintf(stderr,"error in init\n"); return 0;}
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
    int i =0;
    maqmap1_t **preads = reads->reads;//makes things easier to read below
    match_reads->count =0;
    for(i=0;i<reads->count;i++)
    {
        check_size(match_reads);
        int base_pos = ref_position - (preads[i]->pos>>1);
        int read_base = (preads[i]->seq[base_pos]>>6)&3;
        if(base == read_base) 
        {
            match_reads->reads[match_reads->count] = preads[i];
            match_reads->count++;
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
    *q = reads->count?(int)((total_qual/(double)(reads->count))+0.5):0;/*add 0.5 to round instead of trunc*/
}

static int get_base(char base)
{
    if(tolower(base)=='a') return 0;
    if(tolower(base)=='c') return 1;
    if(tolower(base)=='g') return 2;
    if(tolower(base)=='t') return 3;
    if(tolower(base)=='n') return 4;
    
    return -1;
}

/* sub _lookup_iub_code {
    my($self,$code) = @_;

    $self->{'_iub_code_table'} ||= {
             A => ['A', 'A'],
             C => ['C', 'C'],
             G => ['G', 'G'],
             T => ['T', 'T'],
             M => ['A', 'C'],
             K => ['G', 'T'],
             Y => ['C', 'T'],
             R => ['A', 'G'],
             W => ['A', 'T'],
             S => ['G', 'C'],
             D => ['A', 'G', 'T'],
             B => ['C', 'G', 'T'],
             H => ['A', 'C', 'T'],
             V => ['A', 'C', 'G'],
             N => ['A', 'C', 'G', 'T'],
          };
    return @{$self->{'_iub_code_table'}->{$code}};
} */

static void get_variant_bases(char iub_code, int * base, int *count)
{
    *count = 2;
    
    switch (iub_code) {
		case 'A': 
            base[0]=0;
            base[1]=0;
            *count=1;
            break;
        case 'C':
            base[0]=1;
            base[1]=1;
            *count=1;
            break;
        case 'G':
            base[0]=2;
            base[1]=2;
            *count=1;
            break;
        case 'T':
            base[0]=3;
            base[1]=3;
            *count=1;
            break;
        case 'M':
            base[0]=0;//A
            base[1]=1;//C 
            break;
        case 'K':
            base[0]=2;//G
            base[1]=3;//T
            break;
        case 'Y':
            base[0]=1;//C
            base[1]=3;//T 
            break;
        case 'R':
            base[0]=0;//A
            base[1]=2;//G
            break;
        case 'W':
            base[0]=0;//A
            base[1]=3;//T
            break;
        case 'S':
            base[0]=2;//G
            base[1]=1;//C 
            break;
        case 'D':
            base[0]=0;//A
            base[1]=2;//G         
            base[2]=3;//T
            *count =3;
            break;
        case 'B':
            base[0]=1;//C
            base[1]=2;//G
            base[2]=3;//T
            *count=3;
            break;
        case 'H':
            base[0]=0;//A
            base[1]=1;//C
            base[2]=3;//T
            *count=3;
            break;
        case 'V':
            base[0]=0;//A
            base[1]=1;//C
            base[2]=2;//G
            *count=3;
            break;
        case 'N':
            base[0]=0;//A
            base[1]=1;//C
            base[2]=2;//G
            base[3]=3;//T
            *count=4;
            break;
        break;        
		}
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
        fprintf(stderr,"Could not find seq %s\n", name);
        return 4;
    }        
	bit64_t word = bfa1->seq[position>>5];
    bit64_t mask = bfa1->mask[position>>5];
    //changed from 32 to 31 to handle base coordinates starting at 0 (not 1)...
    long long offset = 31-(position&0x1f);//position%32 
    return (mask>>(offset<<1)&3)? "ACGT"[word>>(offset<<1)&3] : 'N'; 
}



int ur_old(map_array *reads)
{
    int i = 0;
    static GHashTable *hash = NULL;
    hash = hash?hash:g_hash_table_new_full(g_str_hash,g_str_equal,free, free);
    char *read_string;
    
    for(i = 0;i<reads->count;i++)
    {
        read_string = malloc(70);
        get_read_lc(reads->reads[i],read_string);
        g_hash_table_insert(hash,read_string,NULL);
    }
    int ur = g_hash_table_size(hash);
    g_hash_table_remove_all(hash);
    return ur;
}

/*map_array * get_urc26(map_array *reads, map_array *clipped_match_reads, long position)
{
    clipped_match_reads->count = reads->count;
    check_size(clipped_match_reads);
        
    int current_pos = 0;
    int i = 0;
    if(reads->count) 
        for(i=0;i<reads->count;i++)
        {
            maqmap1_t *read = reads->reads[i];
            clipped_match_reads->reads[current_pos] = read;
            long read_start = read->pos>>1;
            long read_end = read->pos>>1+read->size;
            //this code works because have already tested reads smaller than 26 bases to see if they fit
            if(read->pos&1)
                if((read_end-26)<=position)
                    current_pos++;
            
            else
                if((read_start+26)>=position)
                    current_pos++;
        }
    current_pos++;   
    
    clipped_match_reads->count-=(mreads->count-current_pos);
    return clipped_match_reads;

}*/

int get_urc26(map_array *reads, long position)
{        
    int current_pos = 0;
    int i = 0;
    if(reads->count) 
        for(i=0;i<reads->count;i++)
        {
            maqmap1_t *read = reads->reads[i];
            long read_start = read->pos>>1;
            long read_end = (read_start+read->size)-1;
            //this code works because I have already tested reads smaller than 26 bases to see if they fit
            if(read->pos&1)
                if((read_end-25)<=position)
                    current_pos++;
            
            else
                if((read_start+25)>=position)
                    current_pos++;
        }
    return current_pos;
}
/* quick hack, will remove function above later or make this more generic */
int get_urc27(map_array *reads, long position)
{        
    int current_pos = 0;
    int i = 0;
    if(reads->count) 
        for(i=0;i<reads->count;i++)
        {
            maqmap1_t *read = reads->reads[i];
            long read_start = read->pos>>1;
            long read_end = (read_start+read->size)-1;
            //this code works because I have already tested reads smaller than 27 bases to see if they fit
            if(read->pos&1)
                if((read_end-26)<=position)
                    current_pos++;
            
            else
                if((read_start+26)>=position)
                    current_pos++;
        }
    return current_pos;
}

void callback_def (void *variation, s_stack * reads)
{
    double junk[100];
    int rc[4];//acgt
    int urc[4];//acgt
    int q[4];//acgt
    int mq[4];//acgt
    int ursc[4];//acgt
    int urc26[4];//acgt
    int vbase[4];
    int vcount;
    char bases[4] = "ACGT";    
    
    mreads->count = 0;
    match_reads->count = 0; 
    snp_item * var_overlap = (snp_item *)variation; 
    int iref_base = get_base(var_overlap->var1);
    
    
    get_variant_bases(var_overlap->var2,vbase,&vcount);
    mreads->count = s_length(reads);
    int stack_size = s_length(reads);
    check_size(mreads);    
    int current_pos = 0;
    int i = 0;//printf("Reads lengths are %d\n",s_length(reads));
    if ( s_length(reads)) 
        for(i=0;i<stack_size;i++)
        {
    
            maqmap1_t *read = (maqmap1_t *)s_peek_nth(reads,i);
            mreads->reads[current_pos] = read;            
            if(read->map_qual>=g_qual_cutoff)current_pos++;            
        }
    
    mreads->count=current_pos;
    //check for the case where the last record doesn't overlap
    
    while(mreads->count>0&&(((mreads->reads[mreads->count-1]->pos)>>1)>var_overlap->end)) 
    {    
        mreads->count--;
    }
    
    //fprintf(stdout, "%s\n",var_overlap->line); return;
    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 0);//A allele
    rc[0] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[0],&mq[0]);
    urc[0] = dedup_count(match_reads->reads, match_reads->count, 26);
    urc26[0] = get_urc26(match_reads, var_overlap->begin);
    ursc[0] = ur_old(match_reads);

    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 1);//C allele
    rc[1] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[1],&mq[1]);
    urc[1] = dedup_count(match_reads->reads, match_reads->count, 26);    
    urc26[1] = get_urc26(match_reads, var_overlap->begin);
    ursc[1] = ur_old(match_reads);
    
    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 2);//G allele
    rc[2] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[2],&mq[2]);
    urc[2] = dedup_count(match_reads->reads, match_reads->count, 26);
    urc26[2] = get_urc26(match_reads, var_overlap->begin);
    ursc[2] = ur_old(match_reads);

    get_matching_reads(mreads, match_reads,var_overlap->begin, 20, 3);//T allele
    rc[3] = match_reads->count;
    get_quality_stats(match_reads, var_overlap->begin,&q[3],&mq[3]);
    urc[3] = dedup_count(match_reads->reads, match_reads->count, 26);
    urc26[3] = get_urc26(match_reads, var_overlap->begin);
    ursc[3] = ur_old(match_reads);
//header:      RC(A,C,G,T) URC(A,C,G,T) REF Ref(RC,URC,Q,MQ) Var1(RC, URC,Q,MQ) Var2(RC,URC,Q,MQ) URCbyContent
//header:      RC(A,C,G,T) URC(A,C,G,T) URC26(A,C,G,T) URSC(A,C,G,T) REF Ref(RC,URC,URC26,URSC,Q,MQ) Var1(RC,URC,URC26,URSC,Q,MQ) Var2(RC,URC,URC26,URSC,Q,MQ) ...
//csv_in_line  2,0,3,4     4,0,3,3      4,0,3,3       A   2,4,30,30             2,2,2,30,30            2,2,2,30,30             
   
    fprintf(stdout, "%s\t%d,%d,%d,%d\t\t",var_overlap->line, rc[0],rc[1],rc[2],rc[3]);
    fprintf(stdout, "%d,%d,%d,%d\t\t",urc[0],urc[1],urc[2],urc[3]);
    fprintf(stdout, "%d,%d,%d,%d\t\t",urc26[0],urc26[1],urc26[2],urc26[3]);
    fprintf(stdout, "%d,%d,%d,%d\t\t",ursc[0],ursc[1],ursc[2],ursc[3]);
    if(iref_base == 4)
        for(i = 0;i<4;i++)
            fprintf(stdout, "%c\t%d,%d,%d,%d,%d,%d\t\t",bases[i],rc[i],urc[i],urc26[i],ursc[i],q[i],mq[i]);            
    else if(iref_base != -1)
        fprintf(stdout, "%c\t%d,%d,%d,%d,%d,%d\t\t",bases[iref_base],rc[iref_base],urc[iref_base],urc26[iref_base],ursc[iref_base],q[iref_base],mq[iref_base]);
    else 
        fprintf(stdout, "%s invalid reference base!");
    for(i=0;i<vcount;i++)
    {
        int b = vbase[i];
        if(b==iref_base)continue;
        fprintf(stdout, "%c\t%d,%d,%d,%d,%d,%d\t\t",bases[b],rc[b],urc[b],urc26[b],ursc[b],q[b],mq[b]);
    }
    fprintf(stdout,"\n");
}

int ovc_filter_variations(char *mapfilename,char *snpfilename, int qual_cutoff,char *output)
{
    g_qual_cutoff = qual_cutoff;
    gzFile reffp = gzopen(mapfilename,"r");
    if(reffp)
        fprintf(stderr,"opened %s\n",mapfilename);
    else 
    {
        fprintf(stderr,"Could not open %s\n",mapfilename);
        exit(1);
    }
    maqmap_t *mm = maqmap_read_header(reffp);
    fprintf(stderr,"Finished reading mapfile header\n");
    g_num_seqs = mm->n_ref;
    mreads = calloc(1,sizeof(map_array));
    match_reads = calloc(1,sizeof(map_array));
    init_map_array(mreads);
    init_map_array(match_reads);
    FILE *stdoutsave = stdout;
    if(output&&strlen(output))
    {
        //fprintf(stderr,"here is the output file %s\n",output);
        stdout = fopen(output, "w");
        if(!stdout)
        {
            fprintf(stderr,"Could not open output file %s\n",output);
            exit(1);
        }
    }

    snp_stream *snps = calloc(1,sizeof(snp_stream));
	snps->fp = fopen(snpfilename,"r");
    if(!snps->fp)
    {
        fprintf(stderr, "Could not open snpfile %s.\n",snpfilename);
        exit(1);    
    }
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
        g_m1=m1;
        g_last_rseqid = m1->seqid;
    }
    else return 1;   

    snp_item *item = get_next_snp(snps);
    rewind(snps->fp);
    g_last_vseqid=item->seqid;
    free(item);
    int i = 0;
    if(!init_seqid(r_stream, v_stream))return 1;//make sure they are are equal
    i = g_last_rseqid;
    do
    {
        fprintf(stderr, "Running on chromosome %s\n", mm->ref_name[i]);i++;
        fire_callback_for_overlaps(
            v_stream,
            r_stream,  
            callback_def  
        );
        fprintf(stderr,"After fire callback\n");
        
    } while(advance_seqid(r_stream,v_stream));
    if(stdout != stdoutsave) fclose(stdout);
    stdout = stdoutsave;
}
