
package Genome::Model::Tools::Maq::RemovePcrArtifacts_C;

use Genome::Model::Tools::Maq::MapUtils;
use Inline 'C' => 'Config' => @Genome::Model::Tools::Maq::MapUtils::CONFIG;

use Inline C => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

/**********************************************************************/
int fragdedup(gzFile fpin, gzFile fpkeepseq, gzFile fpdelseq) 
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = 0;
    maqmap_write_header(fpkeepseq, mm);
    maqmap_write_header(fpdelseq, mm);
    maqmap1_t curr_mm, best_mm;
    
    get_record(fpin, &best_mm);
    while(get_record(fpin, &curr_mm))
    {
        if((int)curr_mm.seqid != (int)best_mm.seqid || curr_mm.pos != best_mm.pos)
        { 
            put_record(fpkeepseq, &best_mm); 
            memcpy(&best_mm, &curr_mm, sizeof(curr_mm));            
        }
        else if( curr_mm.seq[MAX_READLEN-1]>best_mm.seq[MAX_READLEN-1] ||
            (curr_mm.seq[MAX_READLEN-1]==best_mm.seq[MAX_READLEN-1] &&
             curr_mm.size > best_mm.size))
        {            
            put_record(fpdelseq, &best_mm);            
            memcpy(&best_mm, &curr_mm, sizeof(curr_mm));            
        }
        else
            put_record(fpdelseq,&curr_mm);
    }
    put_record(fpkeepseq, &best_mm);    
    return 1;   
}

/**********************************************************************/
int remove_dup_frags (char *infile, char *keepfile, char *delfile)
{
    gzFile fpin = gzopen(infile, "r");
    if (fpin == NULL) { printf("Unable to open file '%s'\n",infile); return 0; }

    gzFile fpkeepseq = gzopen(keepfile, "w");
    if (fpkeepseq == NULL) { printf("Unable to open file '%s'\n",keepfile); return 0; }

    gzFile fpdelseq = gzopen(delfile, "w");
    if (fpdelseq == NULL) { printf("Unable to open file '%s'\n",delfile); return 0; }

    fragdedup(fpin,fpkeepseq, fpdelseq);

    gzclose(fpin);
    gzclose(fpkeepseq);
    gzclose(fpdelseq);
    return 0;
}

END_C

1;
