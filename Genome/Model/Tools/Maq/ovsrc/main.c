#include <stdio.h>
#include <stdlib.h>

int main (int argc, char **argv)
{
  if (argc < 3) {
    fprintf(stderr, "Usage: maqval <in.map> <location.tsv>\n");
    return 1;
  }
	return ovc_filter_variations(argv[1],argv[2]);
}
