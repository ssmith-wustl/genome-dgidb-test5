package Genome::Model::Tools::Maq::CLinkage;

use strict;
use warnings;

use above 'Genome';
use File::Basename;

class Genome::Model::Tools::Maq::CLinkage {
    is_abstract => 1,
};


# $version_dir is the pathname to the maq version-specific subdir
sub _get_config_hash {
    my($class,$version) = @_;

    $DB::single=1;

    #print "in _get_config_hash version is $version\n";

    # First, determine what dir we should look in
    my $p = __PACKAGE__ . '.pm';
    $p =~ s/::/\//g;
    my $loaded_dir = dirname($INC{$p}) . "/";
    #print "module load dir is $loaded_dir\n";

    my $machine_type = 'uname -m';
    # We want non-itanium to compile as 32-bit for now
    my $inline_dir = $ENV{'HOME'} . ($machine_type =~ m/ia64/ ? "/_InlineItanium" : "/_Inline32");
    mkdir($inline_dir) unless -d $inline_dir;   # Why isn't it creating this dir for us anymore?!

    my $libmaq = "maq" . $version;

    return ( DIRECTORY => $inline_dir,
             LIBS => "-L$loaded_dir -L/gsc/pkg/bio/maq/ -L/gsc/pkg/bio/maq/zlib/lib/ -l$libmaq -lz -lm",
             INC => "-I$loaded_dir -I/gsc/pkg/bio/maq/zlib/include/",
             CCFLAGS => '-D_FILE_OFFSET_BITS=64' . ($machine_type =~ m/ia64/ ? '' : ' -m32'),
             #BUILD_NOISY => 1,
             #AUTO_INCLUDE => "#include \"$version_dir/../c_linkage.cpp\"",
           );
}
             
             


1;


