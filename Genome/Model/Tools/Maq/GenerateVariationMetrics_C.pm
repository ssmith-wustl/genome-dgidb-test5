package Genome::Model::Tools::Maq::GenerateVariationMetrics_C;

our $inline_dir;
our $cflags;
our $libs;
our $ovsrc;
BEGIN
{
    $ovsrc =  `wtf Genome::Model::Tools::Maq::GenerateVariationMetrics_C`;
    print "here is the ovsrc directory ", $ovsrc;
    
    chomp $ovsrc;
    ($ovsrc) = $ovsrc =~/(.*)\/GenerateVariationMetrics_C\.pm/;
    ($inline_dir) = "$ENV{HOME}/".(`uname -m` =~ /ia64/ ? '_InlineItanium' : '_Inline32');
    mkdir $inline_dir;
    $cflags = `pkg-config glib-2.0 --cflags`;
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib '.`pkg-config glib-2.0 --libs`;
        
};

use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => $inline_dir,
            INC => "-I$ovsrc".' -I/gscuser/jschindl/svn/gsc/zlib-1.2.3',
            CCFLAGS => `uname -m` =~ /ia64/ ? '-D_FILE_OFFSET_BITS=64 '.$cflags:'-D_FILE_OFFSET_BITS=64 -m32 '.$cflags,
            LD => '/gscmnt/936/info/jschindl/gcc32/ld',
            LIBS => '-L/gscuser/jschindl/svn/gsc/zlib-1.2.3 -lz '.$libs,
            NAME => __PACKAGE__
            );

use Inline C => <<'END_C';
#include "ovsrc/snplist.c"
#include "ovsrc/maqmap.c"
#include "ovsrc/ov.c" 
#include "ovsrc/dedup.c"
#include "ovsrc/bfa.c"
#include "ovsrc/ovc_test.c"

int filter_variations(char *mapfilename,char *snpfilename, int qual_cutoff, char *outputmapfile)
{
    return ovc_filter_variations(mapfilename,snpfilename, qual_cutoff, outputmapfile);
}

END_C

1;
