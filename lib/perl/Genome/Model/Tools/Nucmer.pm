package Genome::Model::Tools::Nucmer;

use strict;
use warnings;

use Genome;

my $DEFAULT = '3.22-64';

class Genome::Model::Tools::Nucmer{
    is => 'Command',
    has => [
        use_version => {
            is => 'Text',
            is_optional => 1,
            doc => "Version of nucmer to use, default is $DEFAULT",
        },
    ],
};

sub help_brief {
}

sub help_detail {
    return <<EOS
EOS
}

my %NUCMER_VERSIONS = (
    '3.15'    => '/gsc/pkg/bio/mummer/MUMmer3.15/nucmer',
    '3.20'    => '/gsc/pkg/bio/mummer/MUMmer3.20/nucmer',
    '3.21'    => '/gsc/pkg/bio/mummer/MUMmer3.21/nucmer',
    '3.22'    => '/gsc/pkg/bio/mummer/MUMmer3.22/nucmer',
    '3.22-64' => '/gsc/pkg/bio/mummer/MUMmer3.22-64/nucmer',
);

sub path_for_nucmer_version {
    my $self = shift;
    my $version = shift;
    die ("No path for version: $version") if not exists $NUCMER_VERSIONS{$version};
    return $NUCMER_VERSIONS{$version};
}

sub nucmer_path {
    return $_[0]->path_for_nucmer_version( $_[0]->use_version );
}

sub available_nucmer_versions {
    return keys %NUCMER_VERSIONS;
}

1;
