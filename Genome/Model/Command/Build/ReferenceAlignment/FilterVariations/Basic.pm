package Genome::Model::Command::AddReads::FilterVariations::Basic;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::AddReads::FilterVariations::Basic {
    is => ['Genome::Model::Command::AddReads::FilterVariations'],
    sub_classification_method_name => 'class',
    has => [ ]
};

sub sub_command_sort_position { 100 }

sub help_brief {
    "Create filtered lists of variations."
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments filter-variations none --model-id 5 --ref-seq-id 22 
EOS
}

sub help_detail {
    return <<"EOS"
    This is a no-op dummy filter step for use by test suites, etc.  In all "production" cases, you want some sort of filtering.
EOS
}

sub execute {
    my $self=shift;
    $self->status_message("no filtering");
    return 1;
}

1;

