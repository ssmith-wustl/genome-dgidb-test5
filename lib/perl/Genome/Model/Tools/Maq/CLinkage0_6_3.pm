package Genome::Model::Tools::Maq::CLinkage0_6_3;

use strict;
use warnings;

use Genome;
use Genome::Model::Tools::Maq::CLinkage;

# This module is the bridge between the CLinkage perl module 
# and the maq C code.  Its necessity seems to be a horrible
# hack:
#     1) we want to be able to specify at runtime what version
#        of maq to use
#     2) Inline::C/CPP only wants to parse the C code at compile
#        time
#     3) Inline::C/CPP only wants to read C code from the same
#        source file as the Perl module it's in
# Maybe using Dynaloader and a shared library maq could make this
# stuff more elegant
#
# In the meantime, here's some notes on using this thing:
# 
# You need to have a file called maq0.6.5.a either in the same
# directory at CLinkage*.pm, or in /gsc/pkg/bio/maq/, and pass
# in the use_version option when creating a Tools::Maq sub-command 
# (such as MapMerge).
#
# If you want to support a new version of maq, (version 0.1.2, for
# example) here's what to do:
# 1) download the source and unpack it
# 2) ./configure
# 3) Edit the makefile, remove the "-m64" option from
#    CFLAGS and CXXFLAGS, and add "-FPIC".  Now they should look
#    something like this:
#    CFLAGS = -Wall -FPIC -D_FASTMAP -g -O2
# 4) make
#    This will build the whole application
# 5) rm main.o
# 6) ar rcs libmaq0.1.2.a *.o
#    This will combine the remaining object files into a library.
# 7) Copy the library to one of the places it needs to be.
# 8) Make a copy of this file and call it CLinkage0_1_2.pm
# 9) Edit this new module and change the line below containing the
#    call to _get_config_hash() and place the version number with
#    the new version
# 10) Don't forget to change the version string in the package name
#    at the top, too

our @CONFIG;
BEGIN {
    @CONFIG = Genome::Model::Tools::Maq::CLinkage->_get_config_hash('0.6.3');
    #print "Got back config: ",join("\n",@CONFIG),"\n";
}


use Inline 'CPP' => 'Config' => @CONFIG;


use Inline CPP => <<'END_C';


// taking all the args on the Perl stack, fill in fake_argv
// as if the items came from the command line
// returns the number of items from the stack (ie., fake_argc)
// Caller will need to free the pointer that gets returned
static char **perl_stack_to_argv(int *fake_argc, ...) {

    Inline_Stack_Vars;

    *fake_argc = Inline_Stack_Items;
    char **fake_argv = (char **) malloc(sizeof(char *) * *fake_argc);

    int i;
    for (i = 0; i < *fake_argc; i++) {
        SV *sv = Inline_Stack_Item(i);
        fake_argv[i] = SvPV(sv, PL_na);
    }

    return fake_argv;
}


static void _print_arglist(int argc, char **argv) {
    printf("Printing %d items\n", argc);

    int i;
    for (i = 0; i < argc; i++) {
        printf("%s\n",argv[i]);
    }
    printf("That's all\n");
}

#ifdef __cplusplus
extern "C" {
#endif
int ma_mapmerge(int argc, char *argv[]);
#ifdef __cplusplus
}
#endif

extern void mapping_merge_core(char *out, int n, char **fn);

int mapmerge(char *output, ...) {

    char **fake_argv;
    int fake_argc;

    fake_argv = perl_stack_to_argv(&fake_argc);  // argv[0] is still output

    mapping_merge_core(output, fake_argc - 1, fake_argv + 1);

    free(fake_argv);

    return 1;
}

END_C

1;
