#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Takes 3 command-line args, all of thich are paths to files
// first file should contain pathnames to sequence-sorted fastq files that may have
//    reads with duplicate sequences
// second file contains pathnames to new fastq files we'll be creating that will contain
//    unique sequences
// third file contains pathname to new fastq files that will store all the duplicate (non
//    unique) sequences.

int main(int argc, char **argv) {
    FILE *sorted_list=fopen(argv[1], "r");
    FILE *unique_list=fopen(argv[2], "r");
    FILE *redund_list=fopen(argv[3], "r");
    int file_count=700;
    int i=0;;
    FILE **input_streams = malloc(sizeof(FILE *) * file_count);
    char* filename=NULL;
    size_t length=0;
    
    while(getline(&filename, &length, sorted_list) != -1) {
        filename[strlen(filename)-1]='\0';
        printf("Opening %s\n", filename);
        input_streams[i] = fopen(filename, "r");
        if (input_streams[i] == NULL) {
            perror("Can't fdopen a read handle");
            return 0;
        }
    free(filename);
    filename=NULL;
    length=0;
    i++;
    }
    i=0;
    FILE **unique_streams = malloc(sizeof(FILE *) * file_count);
    while(getline(&filename, &length, unique_list) != -1) {
        filename[strlen(filename)-1]='\0';
        printf("Opening %s\n", filename);
        unique_streams[i] = fopen(filename, "w");
        if (unique_streams[i] == NULL) {
            perror("Can't fdopen a write handle");
            return 0;
        }
        free(filename);
        filename=NULL;
        length=0;
        i++;
    }
    i=0;
    FILE **dups_streams = malloc(sizeof(FILE *) * file_count);
    while(getline(&filename, &length, redund_list) != -1) {
        filename[strlen(filename)-1]='\0';
        printf("Opening %s\n", filename);
        dups_streams[i] = fopen(filename, "w");
        if (dups_streams[i] == NULL) {
            perror("Can't fdopen a write handle");
            return 0;
        }
        free(filename);
        filename=NULL;
        length=0;
        i++;
    }
    file_count=i;
    
    int open_fd_count = file_count;
    char *last_sequence_seen = "";

    char **sequences = calloc(file_count, 40);   // Let's assumme the max read is 40 bytes.  
    char **read_names = calloc(file_count, 40);  // read names look like @HWI-EAS75__12004_4_200_126_555, should be less than 40
    char **quality_strings = calloc(file_count, 40); // quality strings are the same len as the reads

    // fill in the first record from each input file
    char **throwaway = calloc(40,1);
    size_t max_read_len = 40;
    for ( i = 0; i < file_count; i++) {
        if (getline(&read_names[i], &max_read_len, input_streams[i]) == -1) {
            perror("Can't read a record");
            return 0;
        }

        if (getline(&sequences[i], &max_read_len, input_streams[i]) == -1) {
            perror("Can't read a record");
            return 0;
        }

        if (getline(throwaway, &max_read_len, input_streams[i]) == -1) {
            perror("Can't read a record");
            return 0;
        }


        if (getline(&quality_strings[i], &max_read_len, input_streams[i]) == -1) {
            perror("Can't read a record");
            return 0;
        }
    }
          

    long int test_count = 0;
    while(open_fd_count) {
        // Find the file with the lowest sorting sequence
        int head_fn = 0;
        char *head_sequence = sequences[0];

        int n;
        for(n = 1; n < file_count; n++) {
            if (strcmp(sequences[n], head_sequence) < 0)  {
                head_fn = n;
                head_sequence = sequences[n];
            }
        }

        if (strcmp(head_sequence, last_sequence_seen)) {  // not equal
            fprintf(unique_streams[head_fn], "%s%s+\n%s",
                                             read_names[head_fn],
                                             sequences[head_fn],
                                             quality_strings[head_fn]);
         last_sequence_seen=head_sequence;
        } else {
            fprintf(dups_streams[head_fn], "%s%s+\n%s",
                                             read_names[head_fn],
                                             sequences[head_fn],
                                             quality_strings[head_fn]);
        }

        //if(test_count++ == 1000000)
        //    break;
        if(test_count++ % 5000000 == 0)
            printf("Reached %d\n", test_count);
        
        // get the next record
        max_read_len = 40;
        if (getline(&read_names[head_fn], &max_read_len, input_streams[head_fn]) == -1) {
            // EOF?
            sequences[head_fn] = "Z";
            fclose(input_streams[head_fn]);
            fclose(unique_streams[head_fn]);
            fclose(dups_streams[head_fn]);
            open_fd_count--;

            continue;
        }

        max_read_len = 40;
        if (getline(&sequences[head_fn], &max_read_len, input_streams[head_fn]) == -1) {
            perror("Can't read a record");
            return 0;
        }

        max_read_len = 40;
        if (getline(throwaway, &max_read_len, input_streams[head_fn]) == -1) {
            perror("Can't read a record");
            return 0;
        }

        max_read_len = 40;
        if (getline(&quality_strings[head_fn], &max_read_len, input_streams[head_fn]) == -1) {
            perror("Can't read a record");
            return 0;
        }
    }
}

