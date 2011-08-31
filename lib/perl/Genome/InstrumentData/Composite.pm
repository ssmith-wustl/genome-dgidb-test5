package Genome::InstrumentData::Composite;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Composite {
    is => 'UR::Object', #TODO eventually this will be part of SoftwareResults
    has => [
        inputs => {
            is => 'HASH',
            doc => 'a mapping from keys in the strategy to their values (the source data and reference sequences to use)',
        },
        strategy => {
            is => 'Text',
            doc => 'The instructions of how the inputs are to be aligned and/or filtered',
        },
        merge_group => {
            is => 'Text',
            is_constant => 1, #only sample is supported for now
            value => 'sample',
            doc => 'When merging, collect instrument data together that share this property',
        },
        _merged_results => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged',
            is_transient => 1,
            is_optional => 1,
            doc => 'Holds the underlying merged results',
            is_many => 1,
        },
    ],
};

#This method should just use the one from Genome::SoftwareResult and then get will return the existing result and create will run the alignment dispatcher
sub get_or_create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    my $inputs = $self->inputs;
    my $strategy = $self->strategy;

    #This assumes the input name is "instrument_data" and the reference is "reference_sequence_build".
    my $instrument_data = $inputs->{instrument_data};
    my $reference_sequence_build = $inputs->{reference_sequence_build};

    unless($instrument_data and $reference_sequence_build) {
        die $self->error_message('Input names are currently hardcoded. Must specify "instrument_data" and "reference_sequence_build".');
    }

    my %instdata_by_sample;
    for my $instdata (@$instrument_data) {
        $instdata_by_sample{$instdata->sample->id}{$instdata->id} = 1;
    }

    unless ($strategy eq 'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29') {
        die "this module is currently hard-coded to only take 'instrument_data aligned to reference_sequence_build using bwa 0.5.9 [-q 5] then merged using picard 1.29 then deduplicated using picard 1.29' until the new parser is complete...";
    }

    my @alignment_params = (
        'samtools_version' => 'r599',
        'test_name' => undef,
        'aligner_params' => '-t 4 -q 5::',
        'merger_version' => '1.29',
        'aligner_version' => '0.5.9',
        'aligner_name' => 'bwa',
        'merger_name' => 'picard',
        'merger_params' => undef,
        'picard_version' => '1.29',
        'force_fragment' => undef,
        'duplication_handler_name' => 'picard',
        'duplication_handler_version' => '1.29',
        'duplication_handler_params' => undef,
        'trimmer_version' => undef,
        'trimmer_name' => undef,
        'trimmer_params' => undef
    );

    my @results;
    for my $sample_id (keys %instdata_by_sample) {
        my $ihash = $instdata_by_sample{$sample_id};
        my @instdata_ids = sort keys %$ihash;
        my $merged_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->get_with_lock(
            @alignment_params,
            reference_build_id => $reference_sequence_build->id,
            instrument_data_id => \@instdata_ids,
        );
        unless ($merged_alignment_result) {
            $self->error_message("no merged alignments for sample " . Genome::Sample->get($sample_id)->__display_name__);
            next;
        }

        push @results, $merged_alignment_result;
    }
    unless (@results == scalar(keys %instdata_by_sample)) {
        die $self->error_message("Failed to find alignment results for all samples!");
    }

    $self->_merged_results(\@results);
    return $self;
}

sub bam_paths {
    my $self = shift;

    my @results = $self->_merged_results;

    my @bams;
    for my $result (@results) {
        my $bam = $result->merged_alignment_bam_path;
        push @bams, $bam;
    }

    return @bams;
}

1;
