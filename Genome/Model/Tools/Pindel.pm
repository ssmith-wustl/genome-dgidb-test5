package Genome::Model::Tools::Pindel ;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::Pindel {
    is => 'Command',
    has => [
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run pindel or preprocess input",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 gmt pindel ...    
EOS
}

sub help_detail {                           
    return <<EOS 
EOS
}



1;

