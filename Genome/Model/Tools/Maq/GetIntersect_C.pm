package Genome::Model::Tools::Maq::GetIntersect_C;

our $cflags;
our $libs;
our $inline_dir;
BEGIN
{
    $inline_dir = "$ENV{HOME}/_Inline32";
    $cflags = `pkg-config glib-2.0 --cflags`;
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib '.`pkg-config glib-2.0 --libs`;        
};

use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => $inline_dir,
            INC => '-I/gscuser/jschindl -I/gsc/pkg/bio/maq/zlib/include',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64 -m32 '.$cflags,
            LD => '/gscmnt/936/info/jschindl/gcc32/ld',
            LIBS => '-L/gscuser/jschindl -L/gsc/pkg/bio/maq/zlib/lib -lz -lmaq '.$libs,
            NAME => __PACKAGE__
            );


use Inline C => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))
void write_seq_ov (char *maqfile, char *seqfile, char * outfile);
int main(int argc, char **argv)
{
    write_seq_ov (argv[1], argv[2], argv[3]);
    return;
}

/**********************************************************************/
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
//            if(*seq == -1) 
//                printf("Didn't find %s\n",ref_seq_name);
//            else 
//                printf("Found %s\n",ref_seq_name);
            if(*seq != -1) { *pos--;return 1;  }          
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
void print_seq_ov (char *maqfile, char *seqfile)
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
    //ret = get_next_seq_pos(fp, &seqid, &pos, mm);        
    //if(!ret) goto cleanup;
    
    while((ret = get_next_seq_pos(fp, &seqid, &pos, mm)))
    {
        while(get_record(fpin, &curr_mm))
        {  
            if(seqid != curr_mm.seqid) continue;
            if((curr_mm.pos>>1) > pos) break;
            if(((curr_mm.pos>>1) + curr_mm.size - 1) < pos) continue;
            printf("%s %d %d %d\n", curr_mm.name, curr_mm.seqid, curr_mm.pos>>1, curr_mm.size);    
        }    
    }
 
    // before and after read count for a given start site position
    // chromosme, position, read count before, read count after                

cleanup:
    if(mm) maq_delete_maqmap(mm);
    if(fpin) gzclose(fpin);
    if(fp) fclose(fp);
    return;
}

/**********************************************************************/
void write_seq_ov (char *maqfile, char *seqfile, char * outfile)
{
    gzFile fpin = NULL;
    FILE *fp = NULL;
    maqmap_t  *mm = NULL;
    fpin = gzopen(maqfile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",maqfile); goto cleanup; }
    
    gzFile fpout = NULL;
    fpout = gzopen(outfile, "w");
    fp = fopen(seqfile, "r");
    if (fp == NULL) { printf("Unable to open file '%s'\n",seqfile); goto cleanup; }
    
    mm = maqmap_read_header(fpin);   
    maqmap_write_header(fpout, mm); 
    if(mm == NULL) { printf("Unable to get header from maq file.\n"); goto cleanup; }
    maqmap1_t curr_mm;    
    int seqid, pos, ret;
    //ret = get_next_seq_pos(fp, &seqid, &pos, mm);        
    //if(!ret) goto cleanup;
    
    get_record(fpin, &curr_mm);
    while((ret = get_next_seq_pos(fp, &seqid, &pos, mm)))
    {
        if(seqid >= curr_mm.seqid) break; 
    }
    
    do
    {
        do
        {
            if(seqid != curr_mm.seqid) continue;
            if((curr_mm.pos>>1) > pos) break;
            if(((curr_mm.pos>>1) + curr_mm.size - 1) < pos)
            {
                continue;
            } 
            put_record(fpout, &curr_mm);                
        }
        while(get_record(fpin, &curr_mm));
    }
    while((ret = get_next_seq_pos(fp, &seqid, &pos, mm)));
    
    // before and after read count for a given start site position
    // chromosme, position, read count before, read count after                

cleanup:
    if(mm) maq_delete_maqmap(mm);
    if(fpin) gzclose(fpin);
    if(fpout) gzclose(fpout);
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

END_C

1;
