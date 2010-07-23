package Genome::Model::Tools::Tigra;

use strict;
use warnings;

use Genome; 
use File::Basename;

my $DEFAULT = '0.0.1';
#3Gb
#my $DEFAULT_MEMORY = 402653184;

class Genome::Model::Tools::Tigra {
    is  => 'Command',
    has => [
        use_version => { 
            is  => 'Version', 
            doc => "samtools version to be used, default is $DEFAULT. ", 
            is_optional   => 1, 
            default_value => $DEFAULT,   
        },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run tigra or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt tigra  
EOS
}

sub help_detail {                           
    return <<EOS 
tigra is a denovo assembler using short reads
EOS
}


my %VERSIONS = (
    '0.0.1' => '/gsc/scripts/pkg/bio/tigra/tigra-0.0.1/tigra.pl',
);


sub path_for_tigra_version {
    my ($class, $version) = @_;
    $version ||= $DEFAULT;
    my $path = $VERSIONS{$version};
    return $path if defined $path and -x $path;
    die 'No path found or valid for tigra version: '.$version;
}


sub default_tigra_version {
    die "Current default tigra version: $DEFAULT is not valid" unless $VERSIONS{$DEFAULT};
    return $DEFAULT;
}
 
    
sub tigra_path {
    my $self = shift;
    return $self->path_for_tigra_version($self->use_version);
}


1;

