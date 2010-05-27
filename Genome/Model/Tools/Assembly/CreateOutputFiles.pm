package Genome::Model::Tools::Assembly::CreateOutputFiles;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Assembly::CreateOutputFiles {
    is => 'Command',
    has => [ ],
};

#sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for create assembly output files'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly create-output-files ...
EOS
}

sub xhelp_detail {
    return <<EOS
EOS
}

1;
