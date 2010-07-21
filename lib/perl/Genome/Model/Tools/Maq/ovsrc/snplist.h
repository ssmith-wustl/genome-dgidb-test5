#ifndef SNP_LIST_H
#define SNP_LIST_H

#include <stdio.h>

typedef struct {
   unsigned int begin;
   unsigned int end;
   char name[256];
   unsigned int seqid;
   char var1;
   char var2;
   char line[1024];
} snp_item;

typedef struct {
	FILE *fp;
	int num_refs;
	char ** ref_names;
} snp_stream;

snp_item* get_next_snp(snp_stream *snps);


#endif
