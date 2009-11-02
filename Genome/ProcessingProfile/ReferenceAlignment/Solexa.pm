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
        if ($self->reference_sequence_name eq 'XStrans_adapt_smallRNA_ribo') {
            my @steps = (
                'Genome::Model::Command::Build::ReferenceAlignment::RefCov',
            );
            return @steps;
        }
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
        'Genome::Model::Command::Build::ReferenceAlignment::PostDedupReallocate',
    );
    return @steps;
}

sub generate_reports_job_classes {
    my $self = shift;
    if (defined($self->indel_finder_name)) {
        my @steps = (
            'Genome::Model::Command::Build::ReferenceAlignment::RunReports'
        );
    return @steps;
    }
    return;
}


sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub alignment_objects {

    my ($self, $model) = @_;

    my @assignments = $model->instrument_data_assignments();

    my @instrument_data_ids = map { $_->instrument_data_id() } @assignments;
    my @solexa_instrument_data = Genome::InstrumentData::Solexa->get( \@instrument_data_ids );
    unless (@solexa_instrument_data) {
        $self->warning_message('Failed to find instrument data for model: '.$model->id.'. Now try imported data');
        @solexa_instrument_data = Genome::InstrumentData::Imported->get( \@instrument_data_ids );
        $self->warning_message('Failed to find imported data for model: '.$model->id.' either') unless @solexa_instrument_data;
    }
    return @solexa_instrument_data;
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

