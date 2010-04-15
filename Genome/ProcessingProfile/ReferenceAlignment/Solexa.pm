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
        transcript_annotation
        generate_reports
    /;
    return @stages;
}

sub alignment_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Event::Build::ReferenceAlignment::AlignReads
    /;
    return @sub_command_classes;
}

sub reference_coverage_job_classes {
    my $self = shift;
    if ($self->dna_type eq 'cdna' || $self->dna_type eq 'rna') {
        if ($self->reference_sequence_name =~ /^XStrans_adapt_smallRNA_ribo/) {
            my @steps = (
                'Genome::Model::Event::Build::ReferenceAlignment::RefCov',
            );
            return @steps;
        }
    }
    if (defined($self->capture_set_name)) {
        my @steps = (
            'Genome::Model::Event::Build::ReferenceAlignment::CoverageStats',
        );
        return @steps;
    }
    return;
}

sub variant_detection_job_classes {
    my @steps = (
        'Genome::Model::Event::Build::ReferenceAlignment::UpdateGenotype',
        'Genome::Model::Event::Build::ReferenceAlignment::FindVariations'
    );
    return @steps;
}

sub deduplication_job_classes {
    my @steps = ( 
        'Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries',
        'Genome::Model::Event::Build::ReferenceAlignment::PostDedupReallocate',
    );
    return @steps;
}

sub transcript_annotation_job_classes{
    my $self = shift;
    if (defined($self->annotation_reference_transcripts)){
        my @steps = (
            'Genome::Model::Event::Build::ReferenceAlignment::AnnotateAdaptor',
            #'Genome::Model::Event::Build::ReferenceAlignment::AnnotateTranscriptVariants',
            'Genome::Model::Event::Build::ReferenceAlignment::AnnotateTranscriptVariantsParallel',
        );
        return @steps;
    }
    return;
}

sub generate_reports_job_classes {
    my $self = shift;
    if (defined($self->indel_finder_name)) {
        my @steps = (
            'Genome::Model::Event::Build::ReferenceAlignment::RunReports'
        );
    return @steps;
    }
    return;
}

sub alignment_objects {

    my ($self, $model) = @_;

    my @assignments = $model->instrument_data_assignments();

    $DB::single = 1;

    my @instrument_data_ids = map { $_->instrument_data_id() } @assignments;
    my @solexa_instrument_data = Genome::InstrumentData::Solexa->get( \@instrument_data_ids );

    unless (scalar @solexa_instrument_data == scalar @instrument_data_ids) {
        $self->warning_message('Failed to find all of the assigned instrument data for model: '.$model->id.'. Now trying imported data');
        my @imported_instrument_data = Genome::InstrumentData::Imported->get( \@instrument_data_ids );
        
        push @solexa_instrument_data, @imported_instrument_data;
        unless (scalar @solexa_instrument_data == scalar @instrument_data_ids) {
            $self->error_message('Still did not find all of the assigned instrument data for model: '.$model->id.' even after trying imported data.  Bailing out!');
            die $self->error_message;
        }
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

sub transcript_annotation_objects {
    my $self = shift;
    my $model = shift;
    return 'all_sequences';
}

1;

