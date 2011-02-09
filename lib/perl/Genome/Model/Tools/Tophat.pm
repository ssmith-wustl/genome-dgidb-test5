package Genome::Model::Tools::Tophat;

use strict;
use warnings;

use Genome;
use File::Basename;

my $DEFAULT = '1.1.2';

class Genome::Model::Tools::Tophat {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => $DEFAULT, doc => "Version of tophat to use, default is $DEFAULT" },
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
    '0.7.1'  => '/gsc/pkg/bio/tophat/tophat-0.7.1-64/bin/tophat',
    '0.7.2'  => '/gsc/pkg/bio/tophat/tophat-0.7.2-64/bin/tophat',
    '1.0.10' => '/gsc/pkg/bio/tophat/tophat-1.0.10-64/bin/tophat',
    # These are 64-bit installations.  tophat is really a python script and is OS dependent.
    '1.0.12' => '/gsc/pkg/bio/tophat/tophat-1.0.12/bin/tophat',
    '1.0.13' => '/gsc/pkg/bio/tophat/tophat-1.0.13/bin/tophat',
    '1.0.14' => '/gsc/pkg/bio/tophat/tophat-1.0.14/tophat',
    '1.1.0'  => '/gsc/pkg/bio/tophat/tophat-1.1.0/tophat',
    '1.1.2'  => '/gsc/pkg/bio/tophat/tophat-1.1.2/tophat',
    '1.1.4'  => '/gsc/pkg/bio/tophat/tophat-1.1.4/tophat',
    '1.2.0'  => '/gsc/pkg/bio/tophat/tophat-1.2.0/tophat',
    'tophat' => 'tophat',
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

