package Genome::ProcessingProfile::RnaSeq::Solexa;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::RnaSeq::Solexa {
    is => 'Genome::ProcessingProfile::RnaSeq',
};

sub stages {
    my @stages = qw/
        alignment
        expression
    /;
    return @stages;
}

sub alignment_job_classes {
    my @sub_command_classes = qw/
        Genome::Model::Event::Build::RnaSeq::AlignReads
    /;
    return @sub_command_classes;
}

sub expression_job_classes{
    my $self = shift;
    my @steps = (
        'Genome::Model::Event::Build::RnaSeq::Expression',
    );
    return @steps;
}

sub alignment_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub expression_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

1;

