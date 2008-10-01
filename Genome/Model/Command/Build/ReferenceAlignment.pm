package Genome::Model::Command::Build::ReferenceAlignment;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment {
    is => 'Genome::Model::Command::Build',
    has => [
            testing_flag => {
                             is => 'Integer',
                             doc =>'When set to 1, turns off automatic RunJobsing...',
                             is_optional=>1,
                             default=>0,
                         },
    ],
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "align reads to a reference genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build reference-alignment 
EOS
}

sub help_detail {
    return <<"EOS"
build a model of the alignment to a reference genome
EOS
}

sub command_subclassing_model_property {
    return 'sequencing_platform';
}

sub subordinate_job_classes {
    my $class = shift;
    $class = ref($class) if ref($class);
    die ("Please implement subordinate_job_classes in abstract class '$class'");
}
1;

