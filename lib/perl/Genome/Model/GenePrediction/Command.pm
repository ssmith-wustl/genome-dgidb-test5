package Genome::Model::GenePrediction::Command;


use strict;
use warnings;

use Genome;

class Genome::Model::GenePrediction::Command {
    is => ['Command','Genome::Utility::FileSystem'],
    doc => "tools to work with gene prediction data sets",
};

sub sub_command_category { 'type specific' }

sub Xcommand_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model gene-prediction';
}

sub Xcommand_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'gene-prediction';
}


1;

#$HeadURL$
#$Id$
