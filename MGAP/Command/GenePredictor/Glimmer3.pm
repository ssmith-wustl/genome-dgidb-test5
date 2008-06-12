package MGAP::Command::GenePredictor::Glimmer3;

use strict;
use warnings;

class MGAP::Command::GenePredictor::Glimmer3 {
    is => ['MGAP::Command::GenePredictor'],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;


    1;    
}

1;
