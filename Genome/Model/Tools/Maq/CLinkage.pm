package Genome::Model::Tools::Maq::CLinkage;

use strict;
use warnings;

use Genome;
use Genome::InlineConfig;
use File::Basename;

class Genome::Model::Tools::Maq::CLinkage {
    is_abstract => 1,
};


# $version_dir is the pathname to the maq version-specific subdir
sub _get_config_hash {
    my($class,$version) = @_;

    # First, determine what dir we should look in
    my $p = __PACKAGE__ . '.pm';
    $p =~ s/::/\//g;
    my $loaded_dir = dirname($INC{$p}) . "/";
    my $libmaq = "maq" . $version;
    
    #FIXME: This home directory code is temporary until systems deploys our library fleet around the star system 
    return ( DIRECTORY => Genome::InlineConfig::DIRECTORY(),
             LIBS => "-L$loaded_dir -L/gsc/lib/ -L/gsc/pkg/bio/maq/zlib/lib/ -l$libmaq -lz -lm",
             INC => "-I$loaded_dir -I/gsc/pkg/bio/maq/zlib/include/",
             CCFLAGS => Genome::InlineConfig::CCFLAGS(), 
             #BUILD_NOISY => 1,
           );
}
             
1;

