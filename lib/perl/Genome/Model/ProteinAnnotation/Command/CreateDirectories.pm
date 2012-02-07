package Genome::Model::ProteinAnnotation::Command::CreateDirectories;

use strict;
use warnings;
use File::Temp;

class Genome::Model::ProteinAnnotation::Command::CreateDirectories {
    is  => 'Command::V2',
    has => [
        output_directory => { is => 'FilesystemPath', is_input => 1 },
        lsf_queue => { is_param => 1, default_value => 'short',},
        lsf_resource => { is_param => 1, default_value => 'rusage[tmp=100]',},
    ],
    doc => 'initialize directory structure'
};

sub sub_command_category { 'pipeline' }

sub sub_command_sort_position { 1 }


sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub shortcut {
    # this is so lightweight that shortcut can do all of the work
    shift->execute(@_)
}

sub execute {
    my $self = shift;
    die "not implemented";
    return 1;
}
 
1;
