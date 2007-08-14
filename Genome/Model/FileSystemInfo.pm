package Genome::Model::FileSystemInfo;

use strict;
use warnings;

sub new{
    my $pkg = shift;

    my $self = {
        base_directory => "/gscmnt/sata114/info/medseq/",
        runs_list_filename => "/gscmnt/sata114/info/medseq/aml/run_listing.txt",
    };

    return bless $self, $pkg;
}

sub base_directory{
    return shift->{base_directory};
}

sub runs_list_filename{
    return shift->{runs_list_filename};
}

1;
