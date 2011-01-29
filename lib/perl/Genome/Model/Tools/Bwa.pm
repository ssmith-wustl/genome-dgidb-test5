package Genome::Model::Tools::Bwa;

use strict;
use warnings;

use Genome;
use File::Basename;

my $DEFAULT = '0.5.9';

class Genome::Model::Tools::Bwa {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of bwa to use, default is $DEFAULT" },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run BWA or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools bwa ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the BWA suite of tools can be found at http://bwa.sourceforege.net.
EOS
}


my %BWA_VERSIONS = (
	'0.4.2' => '/gsc/pkg/bio/bwa/bwa-0.4.2-64/bwa',
	'0.4.9' => '/gsc/pkg/bio/bwa/bwa-0.4.9-64/bwa',
	'0.5.0' => '/gsc/pkg/bio/bwa/bwa-0.5.0-64/bwa',
	'0.5.1' => '/gsc/pkg/bio/bwa/bwa-0.5.1-64/bwa',
    '0.5.2' => '/gsc/pkg/bio/bwa/bwa-0.5.2-64/bwa',
    '0.5.3' => '/gsc/pkg/bio/bwa/bwa-0.5.3-64/bwa',
    '0.5.4' => '/gsc/pkg/bio/bwa/bwa-0.5.4-64/bwa',
    '0.5.5' => '/gsc/pkg/bio/bwa/bwa-0.5.5-64/bwa',
    '0.5.6' => '/gsc/pkg/bio/bwa/bwa-0.5.6-64/bwa',
    '0.5.7' => '/gsc/pkg/bio/bwa/bwa-0.5.7-64/bwa',
    '0.5.7-6' => '/gsc/pkg/bio/bwa/bwa-0.5.7-6-64/bwa',
    '0.5.8a' => '/gsc/pkg/bio/bwa/bwa-0.5.8a-64/bwa',
    '0.5.8c' => '/gsc/pkg/bio/bwa/bwa-0.5.8c-64/bwa',
    '0.5.9rc1' => '/gsc/pkg/bio/bwa/bwa-0.5.9rc1-64/bwa',
    '0.5.9' => '/gsc/pkg/bio/bwa/bwa-0.5.9-64/bwa',
    'bwa'   => 'bwa',
);


sub bwa_path {
    my $self = $_[0];
    return $self->path_for_bwa_version($self->use_version);
}

sub available_bwa_versions {
    my $self = shift;
    return keys %BWA_VERSIONS;
}

sub path_for_bwa_version {
    my $class = shift;
    my $version = shift;

    if (defined $BWA_VERSIONS{$version}) {
        return $BWA_VERSIONS{$version};
    }
    die('No path for bwa version '. $version);
}

sub default_bwa_version {
    die "default samtools version: $DEFAULT is not valid" unless $BWA_VERSIONS{$DEFAULT};
    return $DEFAULT;
}
        
sub default_version { return default_bwa_version; }

sub supports_bam_input {
    my $class = shift;
    my $version = shift;

    my %ok_versions = {'0.5.9rc1' => 1,
                       '0.5.9'  => 1};

    return (exists $ok_versions{$version});

}

1;

