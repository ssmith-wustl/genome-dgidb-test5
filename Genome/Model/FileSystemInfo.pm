package Genome::Model::FileSystemInfo;

use strict;
use warnings;

sub new{
    my $pkg = shift;

    my $self = {
        base_directory => "/gscmnt/sata114/info/medseq/",
        runs_list_filename => "/gscmnt/sata114/info/medseq/aml/run_listing.txt",
        sample_data_directory => '/gscmnt/sata114/info/medseq/sample_data/',
    };

    return bless $self, $pkg;
}

sub base_directory{
    return shift->{base_directory};
}

sub runs_list_filename{
    return shift->{runs_list_filename};
}

sub sample_data_directory{
    return shift->{sample_data_directory}
}
1;
