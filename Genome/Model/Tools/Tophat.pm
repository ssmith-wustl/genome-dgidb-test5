package Genome::Model::Tools::Tophat;

use strict;
use warnings;

use Genome;
use File::Basename;

my $DEFAULT = '1.0.10';

class Genome::Model::Tools::Tophat {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of tophat to use, default is $DEFAULT" },
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
    "Tools to run Tophat or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools tophat ...    
EOS
}

sub help_detail {
    return <<EOS
More information about the Tophat aligner can be found at http://tophat.cbcb.umd.edu/.
EOS
}


my %TOPHAT_VERSIONS = (
    '0.7.1' => '/gsc/pkg/bio/tophat/tophat-0.7.1-64/bin/tophat',
    '0.7.2' => '/gsc/pkg/bio/tophat/tophat-0.7.2-64/bin/tophat',
    '1.0.10' => '/gsc/pkg/bio/tophat/tophat-1.0.10-64/bin/tophat',
    'tophat'   => 'tophat',
);


sub tophat_path {
    my $self = $_[0];
    return $self->path_for_tophat_version($self->use_version);
}

sub available_tophat_versions {
    my $self = shift;
    return keys %TOPHAT_VERSIONS;
}

sub path_for_tophat_version {
    my $class = shift;
    my $version = shift;

    if (defined $TOPHAT_VERSIONS{$version}) {
        return $TOPHAT_VERSIONS{$version};
    }
    die('No path for tophat version '. $version);
}

sub default_tophat_version {
    die "default tophat version: $DEFAULT is not valid" unless $TOPHAT_VERSIONS{$DEFAULT};
    return $DEFAULT;
}

1;

