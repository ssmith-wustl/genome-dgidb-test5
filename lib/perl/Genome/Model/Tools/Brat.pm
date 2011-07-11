package Genome::Model::Tools::Brat;

use strict;
use warnings;

use Genome;
use File::Basename;

my $DEFAULT = '1.2.1-mod';

class Genome::Model::Tools::Brat {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of brat to use, default is $DEFAULT" },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run BRAT or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools brat ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the BRAT suite of tools can be found at http://compbio.cs.ucr.edu/brat/.
EOS
}

# TODO install this to /gsc/pkg/bio/brat/brat-1.2.1-mod/
my %BRAT_VERSIONS = (
    '1.2.1-mod' => '/gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/brat',
    'brat'   => 'brat',
);


sub brat_path {
    my $self = $_[0];
    return $self->path_for_brat_version($self->use_version);
}

sub available_brat_versions {
    my $self = shift;
    return keys %BRAT_VERSIONS;
}

sub path_for_brat_version {
    my $class = shift;
    my $version = shift;
    unless (defined($version)) {
        $class->status_message("No version specified! Using default version '$DEFAULT'.");
        $version = $DEFAULT;
    }
    if (defined $BRAT_VERSIONS{$version}) {
        return $BRAT_VERSIONS{$version};
    }
    die('No path for brat version '. $version);
}

sub default_brat_version {
    die "default brat version: $DEFAULT is not valid" unless $BRAT_VERSIONS{$DEFAULT};
    return $DEFAULT;
}
        
sub default_version { return default_brat_version; }


# TODO i'm guessing the following are not required

#sub supports_bam_input {
#    my $class = shift;
#    my $version = shift;
#
#    my %ok_versions = ();
#
#    return (exists $ok_versions{$version});
#
#}
#
#sub supports_multiple_reference {
#    my $class = shift;
#    my $version = shift;
#
#    my %ok_versions = ('0.5.9-pem0.1' => 1);
#
#    return exists $ok_versions{$version};
#}

1;

