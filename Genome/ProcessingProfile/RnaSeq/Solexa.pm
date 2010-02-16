package Genome::ProcessingProfile::RnaSeq::Solexa;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::RnaSeq::Solexa {
    is => 'Genome::ProcessingProfile::RnaSeq',
};
sub stages {
    my @stages = qw/
        prepare_reads
        alignment
        deduplication
        reference_coverage
        transcript_expression
    /;
    return @stages;
}

sub prepare_reads {
    my @sub_command_classes = qw/
        Genome::Model::Event::Build::RnaSeq::PrepareReads
    /;
    return @sub_command_classes;
}

sub alignment_job_classes {
    my @sub_command_classes = qw/
        Genome::Model::Event::Build::RnaSeq::AlignReads
    /;
    return @sub_command_classes;
}

sub reference_coverage_job_classes {
    my @sub_command_classes = qw/
        Genome::Model::Event::Build::RnaSeq::RefCov
    /;
    return @sub_command_classes;
}

sub deduplication_job_classes {
    my @steps = ( 
        'Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries',
        'Genome::Model::Event::Build::ReferenceAlignment::PostDedupReallocate',
    );
    return @steps;
}

sub transcript_expression_job_classes{
    my $self = shift;
    my @steps = (
        'Genome::Model::Event::Build::RnaSeq::TranscriptExpression',
    );
    return @steps;
}

sub prepare_reads_objects {

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

sub alignment_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub reference_coverage_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub deduplication_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

sub transcript_expression_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

1;

