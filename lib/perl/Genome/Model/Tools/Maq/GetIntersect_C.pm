package Genome::Model::Tools::Maq::GetIntersect_C;

our $cflags;
our $libs;
BEGIN
{
    $cflags = `pkg-config glib-2.0 --cflags`;
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib '.`pkg-config glib-2.0 --libs`;        
};

use Genome::InlineConfig;
use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => Genome::InlineConfig::DIRECTORY(), 
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
void write_seq_ov (char *maqfile, char *seqfile, char * outfile, int justname);
int main(int argc, char **argv)
{
    write_seq_ov (argv[1], argv[2], argv[3], atoi(argv[4]));
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

int get_next_seq_pos(FILE *fh, char * ref_seq_name, int *seq, int *pos, maqmap_t *mm)
{
    static char templine[180];
    
    if(fgets(templine, sizeof(templine), fh))
    {
        if(sscanf(templine, "%s %d", ref_seq_name, pos)==2)
        {            
            *seq = find_ref_seq_id(ref_seq_name, mm);
            if(*seq != -1) { (*pos)--;return 1;  }          
        }
    }
    return 0;
}

/**********************************************************************/
void write_seq_ov (char *maqfile, char *seqfile, char * outfile, int justname)
{
    gzFile fpin = NULL;
    FILE *fp = NULL;
    maqmap_t  *mm = NULL;
    fpin = gzopen(maqfile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",maqfile); goto cleanup; }
    
    gzFile fpout = NULL;
    FILE *fpout2 = NULL;
    if(justname==0)
        fpout = gzopen(outfile, "w");
    else if(justname == 1)
        fpout2 = fopen(outfile, "w");    
    else if(justname == 2)
    {
        char filename[512];
        strcpy(filename,outfile);
        strcat(filename,".map");
        fpout = gzopen(filename, "w");
        strcpy(filename,outfile);
        strcat(filename,".readlist");
        fpout2 = fopen(filename,"w");    
    }
    fp = fopen(seqfile, "r");
    if (fp == NULL) { printf("Unable to open file '%s'\n",seqfile); goto cleanup; }
    
    mm = maqmap_read_header(fpin);   
    if(fpout) maqmap_write_header(fpout, mm); 
    if(mm == NULL) { printf("Unable to get header from maq file.\n"); goto cleanup; }
    maqmap1_t curr_mm;    
    int seqid, pos, ret;
    char seqname[180];
    

    char filename[256];
    while((ret = get_next_seq_pos(fp, seqname, &seqid, &pos, mm)))
    {
        /*if(justname)
        {            
            sprintf(filename, "%s_%d.readlist",seqname,pos+1);
            fpout2 = fopen(filename, "w");
        }*/
        while(get_record(fpin, &curr_mm))
        {
            if(seqid > curr_mm.seqid)
            {
                while(get_record(fpin, &curr_mm))
                {
                    if(curr_mm.seqid>=seqid) break;        
                }                
            }
            if(seqid != curr_mm.seqid)
            {
                break;            
            }
            if((curr_mm.pos>>1) > pos) break;
            if(((curr_mm.pos>>1) + curr_mm.size - 1) < pos)
            {
                //printf("Skipping %s at %d\n",curr_mm.name, curr_mm.pos>>1);
                continue;
            }
            //else
            //{
            //    printf("position is %d, read start %d read end %d\n", pos,curr_mm.pos>>1,(curr_mm.pos>>1) + curr_mm.size - 1); 
            //                 printf("Writing %s at %d, size %d\n",curr_mm.name, curr_mm.pos>>1,curr_mm.size);
            //}
            if(justname==1||justname==2)
                //fprintf(fpout2, "%s\n", curr_mm.name);
                fprintf(fpout2, "\@%s\t%s\t%d\t%c\t%d\t%u\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
				curr_mm.name, mm->ref_name[curr_mm.seqid], (curr_mm.pos>>1) + 1,
				(curr_mm.pos&1)? '-' : '+', curr_mm.dist, curr_mm.flag, curr_mm.map_qual, (signed char)curr_mm.seq[MAX_READLEN-1],
				curr_mm.alt_qual, curr_mm.info1&0xf, curr_mm.info2, curr_mm.c[0], curr_mm.c[1], curr_mm.size);
            if(justname ==0||justname==2)
                put_record(fpout, &curr_mm);                
        }        
        /*if(justname)
        {
            if(fpout2) fclose(fpout2);
            fpout2 = NULL;
        }  */      
    }   
    
    // before and after read count for a given start site position
    // chromosme, position, read count before, read count after                

cleanup:
    if(mm) maq_delete_maqmap(mm);
    if(fpin) gzclose(fpin);
    if(fpout2) fclose(fpout2);
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
