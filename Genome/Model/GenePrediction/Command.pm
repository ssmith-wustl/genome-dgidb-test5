package Genome::Model::GenePrediction::Command;


use strict;
use warnings;

use Genome;

class Genome::Model::GenePrediction::Command {
    is => ['Command','Genome::Utility::FileSystem'],
    doc => "Modularization of gene prediction scripts",
};

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model gene-prediction';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'gene-prediction';
}


1;

#$HeadURL$
#$Id$
