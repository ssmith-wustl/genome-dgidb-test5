package Genome::Model::Tools::Maq::MapUtils;

=pod

=head1 NAME

B<Genome::Model::Tools::Maq::MapUtils> - Work with maq map DNA sequence alignment files in C via Perl

=head1 SYNOPSIS

use Genome::Model::Tools::Maq::MapUtils;
my $result = Genome::Model::Tools::Maq::MapUtils::some_c_function($some_data);

# or 

use Inline 'C' => 'Config' => @Genome::Model::Tools::Maq::MapUtils::CONFIG;
use Inline 'C' => <<'END_C';
    <your c code here>
END_C


=head1 DESCRIPTION

This module uses Inline::C to make work with maq map files speedy.

For more details on the maq suite of tools for aligning short DNA reads to a reference sequence, see:
http://maq.sourceforge.net/

=head1 METHODS

=over 4

=method char* call_function_pass_string_return_string(char* s)

This utility function will let you pass a function pointer from another module and this function will execute it.

=back

=head1 EXAMPLES

See the commands under Genome::Model::Tools::Maq with "gt maq" on the command-line.

=head1 BUGS

Returning a char* sometimes converts to a Perl string, and sometimes does not.

=over 4

=back

Report bugs to <software@watson.wustl.edu>.

=head1 AUTHOR

Scott Smith <ssmith@watson.wustl.edu>

=cut


use strict;
use warnings;

our @CONFIG;
our $INLINE_DIR;
our $C_INC;
our $C_LIBS;

BEGIN
{
    ($INLINE_DIR) = "$ENV{HOME}/".(`uname -a ` =~ /ia64 / ? '_Inline64' : '_Inline32');
    mkdir $INLINE_DIR unless -d $INLINE_DIR;
    
    my $module_dir = $INC{'Genome/Model/Tools/Maq/MapUtils.pm'};
    $module_dir =~ s/MapUtils.pm$//;
    
    $C_INC = join(" ", map { "-I$_" } (
        "$module_dir/src", 
        "/gscuser/jschindl/svn/gsc/zlib-1.2.3")
    );
    
    $C_LIBS =
        join(" ",
            map { "-L$_" } 
            ('/gscuser/jschindl','/gscuser/jschindl/svn/gsc/zlib-1.2.3')
        )
        . " "
        . join(" ", 
            map { "-l$_" } 
            ('z','maq')
        );

    our @CONFIG = (
            DIRECTORY => $Genome::Model::Tools::Maq::MapUtils::INLINE_DIR,            
            INC => $Genome::Model::Tools::Maq::MapUtils::C_INC,
            CCFLAGS => '-D_FILE_OFFSET_BITS=64',
            LIBS => $Genome::Model::Tools::Maq::MapUtils::C_LIBS
    );

};

use Inline 'C' => 'Config' => @CONFIG;

use Inline 'C' => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char* call_function_pass_string_return_string(void *p, char *s) {
    char* (*x)(char *s) = p;
    printf("returning %ld: %s\n", s, s);
    return (*x)(s);
}

char* test_ssmith (char* s) {
    char r[100];
    sprintf(&r, "c: %s", s);
    return r;
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
???BLOCK MISSING
???BLOCK MISSING
