package Genome::Model::Tools::Maq::ExampleUsingC_C;

use Genome::Model::Tools::Maq::MapUtils;
use Inline 'C' => 'Config' => @Genome::Model::Tools::Maq::MapUtils::CONFIG;

use strict;
use warnings;

use Inline 'C' => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int test_ssmith (char* s) {
    return printf("c: %s\n", s);
}

void* test_ssmith_fptr() {
    return &test_ssmith;
}


END_C


1;

__END__
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef PATH_MAX
#define PATH_MAX 256
#endif

// MAX_FILES:      Maximum number of FastQ's supported.
// MAX_TOKEN_LEN:  maximum supported read label length / sequence length
// MAX_LINE_LEN:   explained in notes above.  Rounding out to +4 to
//                 promote 4-byte alignment.
#define  MAX_FILES       700
#define  MAX_TOKEN_LEN   64
#define  MAX_LINE_LEN    (MAX_TOKEN_LEN+4)

int     file_count;

char    readlabel[MAX_FILES][MAX_LINE_LEN];
char    sequence[MAX_FILES][MAX_LINE_LEN];
char    quality[MAX_FILES][MAX_LINE_LEN];

typedef struct {
  FILE           *in_fh;
  FILE           *uniq_fh;
  FILE           *dup_fh;
  char           *infile;
  char           *uniqfile;
  char           *dupfile;
  unsigned int    unique;
  unsigned int    libdups;
  unsigned int    rundups;
} data_t;

data_t data[MAX_FILES];


////////////////////////////////////////////////////////////////////////
int open_fof_files(
        char     *sorted_file_pathname,
        char     *unique_file_pathname,
        char     *duplicate_file_pathname,
        int      *file_count) {

    if (!sorted_file_pathname || !unique_file_pathname || !duplicate_file_pathname) {
        perror("open_fof_files():  Required arguments not available");
        return 1;
    }
    FILE  *sorted_foflist = fopen(sorted_file_pathname, "r");
    FILE  *unique_foflist = fopen(unique_file_pathname, "r");
    FILE  *dups_foflist   = fopen(duplicate_file_pathname, "r");

    if (!sorted_foflist || !sorted_foflist || !dups_foflist) {
        perror("Can't fopen() FOFs in open_fof_files()");
        return 1;
    }
    char        filename[3][PATH_MAX];
    int         cnt=0;

    while (cnt < MAX_FILES &&
           fgets(filename[0], PATH_MAX, sorted_foflist) &&
           fgets(filename[1], PATH_MAX, unique_foflist) &&
           fgets(filename[2], PATH_MAX, dups_foflist)) {
        filename[0][strlen(filename[0])-1] = '\0';  /* remove newline */
        filename[1][strlen(filename[1])-1] = '\0';  /* remove newline */
        filename[2][strlen(filename[2])-1] = '\0';  /* remove newline */
        data[cnt].infile  = strdup(filename[0]);
        if (strcmp(filename[1],"/dev/null"))
            data[cnt].uniqfile = strdup(filename[1]);
        if (strcmp(filename[2],"/dev/null"))
            data[cnt].dupfile = strdup(filename[2]);

        if ((data[cnt].in_fh = fopen(data[cnt].infile, "r")) == NULL) {
            perror("open_fof_files(): Can't fopen() infile");
            return 1;
        }
        if (data[cnt].uniqfile != NULL) {
            if ((data[cnt].uniq_fh = fopen(data[cnt].uniqfile, "w")) == NULL) {
                perror("open_fof_files(): Can't fopen() uniqfile");
                return 1;
            }
        }
        if (data[cnt].dupfile) {
            if ((data[cnt].dup_fh = fopen(data[cnt].dupfile, "w")) == NULL) {
                perror("open_fof_files(): Can't fopen() dupfile");
                return 1;
            }
        }
    cnt++;
    }
    if (file_count != NULL)
        *file_count = cnt;
    return 0;
}

////////////////////////////////////////////////////////////////////////
int get_fastq_record(int next) {
    int     ret=0;
    char    throwaway[MAX_LINE_LEN];
    if (data[next].in_fh == NULL ||
        fgets(readlabel[next], MAX_LINE_LEN, data[next].in_fh) == NULL ||
        fgets(sequence[next],  MAX_LINE_LEN, data[next].in_fh) == NULL ||
        fgets(throwaway,       MAX_LINE_LEN, data[next].in_fh) == NULL ||
        fgets(quality[next],   MAX_LINE_LEN, data[next].in_fh) == NULL) {

        strcpy(sequence[next],"");
        if (data[next].in_fh) {
            fclose(data[next].in_fh);
            data[next].in_fh = NULL;
        }
        if (data[next].uniq_fh) {
            fclose(data[next].uniq_fh);
            data[next].uniq_fh = NULL;
        }
        if (data[next].dup_fh) {
            fclose(data[next].dup_fh);
            data[next].dup_fh = NULL;
        }
        ret=1;
    }
    return ret;
}

////////////////////////////////////////////////////////////////////////
void put_fastq_record(FILE *fpout, int ndx) {
    fprintf(fpout, "%s%s+\n%s",
                   readlabel[ndx],
                   sequence[ndx],
                   quality[ndx]);
}

////////////////////////////////////////////////////////////////////////
// Find the input stream with the next record.
// Now in reverse alpha order.
int next_sequence() {
    int next = 0;
    int lv;
    for(lv = 1; lv < file_count; lv++) {
        if (strcmp(sequence[lv], sequence[next]) > 0) {
            next = lv;
        }
    }
    return next;
}

////////////////////////////////////////////////////////////////////////
int make_uniques(
     char *sorted_file_pathname,
     char *unique_file_pathname,
     char *duplicate_file_pathname,
     char *statistics_file_pathname) {

    if (!sorted_file_pathname || !unique_file_pathname ||
        !duplicate_file_pathname || !statistics_file_pathname) {
        printf("make_uniques: not all arguments specified\n");
        return 0;
    }

    memset(readlabel, 0, sizeof(readlabel));   /* clearing per record information */
    memset(sequence, 0, sizeof(sequence));
    memset(quality, 0, sizeof(quality));

    memset(data, 0, sizeof(data));

    if (open_fof_files(sorted_file_pathname,
                       unique_file_pathname,
                       duplicate_file_pathname,
                       &file_count)) {
        printf("make_uniques: could not open required files\n");
        return 0;
    }
    int        open_fd_count = file_count;

    int        next;
    int        last = -1;
    char       last_seq[MAX_LINE_LEN] = "~";

    FILE      *statistics = fopen(statistics_file_pathname,"w");

    // fill in the first record from each input file
    int   lv;
    for ( lv = 0; lv < file_count; lv++) {
        *readlabel[lv] = *sequence[lv] = *quality[lv] = '\0';
        if (get_fastq_record(lv))
            open_fd_count--;
    }

    while(open_fd_count) {
        // Find the file with the lowest sorting sequence
        next = next_sequence();

        if (strcmp(sequence[next], last_seq)) {  // not equal
            ++data[next].unique;
            if (data[next].uniq_fh)
                put_fastq_record(data[next].uniq_fh, next);
            last = next;
            strcpy(last_seq,sequence[last]);
        }
        else if (data[next].dup_fh) { // duplicate of some sort (across this lib)
            ++data[next].libdups;
            if (!data[next].dup_fh) {
                fprintf(statistics,
                        "ERROR: Duplicate detected and unreportable next=%d seq=%s matches last=%d\n",
                        next,last_seq,last);
                return 0;
            }
            put_fastq_record(data[next].dup_fh, next);
            if(data[last].dupfile) {
                //current run
                ++data[next].rundups;
            } else {
                //previous run.. nothing to do..
            }
            last = next;
            // strcpy above would be a no-op
        }
        else {
            fprintf(statistics,
                    "ERROR: Duplicate detected in file next=%d seq=%s matches last=%d\n",
                    next,last_seq,last);
//      printf("%d %d %s %s",last, next, last_seq, sequence[next]);
            return 0;
        }

        if (get_fastq_record(next))
            open_fd_count--;
    }

    for ( lv = 0; lv < file_count; lv++) {
        fprintf(statistics,"%lu\t%lu\t%lu\n", data[lv].unique, data[lv].libdups, data[lv].rundups);
    }
    fclose(statistics);

    return 1;
}



END_C

1;
