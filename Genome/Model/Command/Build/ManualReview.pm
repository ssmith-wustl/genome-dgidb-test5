package Genome::Model::Command::Build::ManualReview;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::ManualReview {
    is => 'Genome::Model::Command::Build',
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Build for Manual Review models... not implemented yet"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given ManualReview model.
EOS
}


1;
