package Genome::ProcessingProfile::ReferenceAlignment::Solexa;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ReferenceAlignment::Solexa {
    is => 'Genome::ProcessingProfile::ReferenceAlignment',
};
sub stages {
    my @stages = qw/
        alignment
        deduplication
        reference_coverage
        variant_detection
        generate_reports
        verify_successful_completion
    /;
    return @stages;
}

sub alignment_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::ReferenceAlignment::AlignReads
    /;
    return @sub_command_classes;
}

sub reference_coverage_job_classes {
    my $self = shift;
    if ($self->dna_type eq 'cdna' || $self->dna_type eq 'rna') {
        my @steps = (
                   'Genome::Model::Command::Build::ReferenceAlignment::Layers',
                   'Genome::Model::Command::Build::ReferenceAlignment::RefCov',
               );
        return @steps;
    }
    return;
}


sub variant_detection_job_classes {
    my @steps = (
        'Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype',
        'Genome::Model::Command::Build::ReferenceAlignment::FindVariations'
    );

    return @steps;
}

sub deduplication_job_classes {
    my @steps = ( 
        'Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries',
    );
    return @steps;
}

sub generate_reports_job_classes {
    my @steps = (
        'Genome::Model::Command::Build::ReferenceAlignment::RunReports'
    );
    return @steps;
}


sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub alignment_objects {
    my $self = shift;
    my $model = shift;
    return $model->instrument_data;
}

sub reference_coverage_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}


sub variant_detection_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub deduplication_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub generate_reports_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}


sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
}
1;

