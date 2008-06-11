#include <stdio.h>
#include <stdlib.h>

extern int ovc_filter_variations(char *mapfilename,char *snpfilename, int qual_cutoff);

int main (int argc, char **argv)
{
  if (argc < 4) {
    fprintf(stderr, "Usage: maqval <in.map> <location.tsv> <quality>\n");
    return 1;
  }
	return ovc_filter_variations(argv[1],argv[2], atoi(argv[3]));
}
