package Genome::Model::Tools::Bwa;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Bwa {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => '0.4.9', doc => "Version of bwa to use" },
        arch_os => {
                    calculate => q|
                            my $arch_os = `uname -m`;
                            chomp($arch_os);
                            return $arch_os;
                        |
                },
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

sub bwa_path {
    my $self = $_[0];
    return $self->path_for_bwa_version($self->use_version);
}
my %BWA_VERSIONS = (
		    '0.4.2' => '/gsc/pkg/bio/bwa/bwa-0.4.2-64/bwa',
		    '0.4.9' => '/gsc/pkg/bio/bwa/bwa-0.4.9-64/bwa',
		    '0.5.0' => '/gsc/pkg/bio/bwa/bwa-0.5.0-64/bwa',
                    'bwa'   => 'bwa',
                );

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


1;

