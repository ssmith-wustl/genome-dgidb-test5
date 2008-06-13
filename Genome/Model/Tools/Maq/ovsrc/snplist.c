#include "snplist.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static unsigned int get_seqid(char *name, int n_ref, char**ref_name)
{
	static char **last_ref_name = NULL;
	static char *last_name = NULL;
	static unsigned int last_seqid = 0;
    if(!last_name) 
    {
        last_name = malloc(1);
        last_name[0] = 0x00;    
    }
	if(ref_name == last_ref_name &&
	   !strcmp(last_name, name))
	{
		return last_seqid;
	}
	else
	{
		last_ref_name = ref_name;
        if(last_name) free(last_name);
        last_name = malloc(sizeof(name));
        if(!last_name) 
        {
            printf("Could not allocate string!\n");
            exit(1);
        }
		strcpy(last_name, name);
		int count = 0;
		while((strcmp(ref_name[last_seqid%n_ref],name)!=0) &&
              count<n_ref)
        {        
            last_seqid++;
            count++;
        }
        if(count>=n_ref) {printf("Couldn't find %s in map file\n", name); return -1;}	
		last_seqid = last_seqid%n_ref;
	}	
	return last_seqid;
}

snp_item *get_next_snp(snp_stream *s)
{
	FILE *fp = s->fp;
	int n_ref = s->num_refs;
	char **ref_names = s->ref_names;
	    
	snp_item *snp = calloc(1, sizeof(snp_item));
    if(!snp)
    {
        printf("snp allocation failed.\n");
        return NULL;
    }
	if(!fgets(snp->line, 1024, fp)) 
	{
		free(snp);
		return NULL;
	}
    snp->line[strlen(snp->line)-1] = 0x00;
	//sscanf(snp->line, "%s %d %d %c %c", snp->name, &(snp->begin), &(snp->end), &(snp->var1), &(snp->var2));
    sscanf(snp->line, "%s %d %c %c", snp->name, &(snp->begin), &(snp->var1), &(snp->var2));
    snp->end = snp->begin;
    snp->begin--;
    snp->end--;
	snp->seqid = get_seqid(snp->name, n_ref, ref_names);

	return snp;
}
