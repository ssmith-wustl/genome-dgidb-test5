
package Genome::InstrumentData::Command::Align;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::Align {
    is => ['Genome::Utility::FileSystem','Command'],
    has_abstract_constant => [
        aligner_name                    => { is => 'Text' },
    ],
    has_input => [
        instrument_data                 => {
                                            is => 'Genome::InstrumentData',
                                            id_by => 'instrument_data_id'
                                        },
        instrument_data_id              => {
                                            is => 'Number',
                                            doc => 'the local database id of the instrument data (reads) to align'
                                        },
    ],
    has_optional_param => [
        reference_build                 => {
                                            is => 'Genome::Model::Build::ReferencePlaceholder',
                                            id_by => 'reference_name',
                                        },
        reference_name                  => {
                                            doc => 'the reference to use by EXACT name, defaults to NCBI-human-build36',
                                            default_value => 'NCBI-human-build36'
                                        },
        version                         => {
                                            is => 'Text', default_value => '0.7.1',
                                            doc => 'the version of maq to use, i.e. 0.6.8, 0.7.1, etc.'
                                        },
        params                          => {
                                            is => 'Text', default_value => '', 
                                            doc => 'any additional params for the aligner in a single string'
                                        },
        force_fragment                  => {
                                            is => 'Boolean', default_value => 0,
                                            doc => 'force paired end instrument data to align as fragment',
                                        }
    ],
    has_optional_output => [
        _alignment                      => { is => 'Genome::InstrumentData::Alignment' },
    ],
    doc => 'align instrument data using one of the available aligners',
};


sub help_synopsis {
return <<EOS
genome instrument-data align maq        -r NCBI-human-build36 -i 2761701954 -v 0.6.5

genome instrument-data align novoalign  -r NCBI-human-build36 -i 2761701954 -v 2.03.12

genome instrument-data align maq -r NCBI-human-build36 -i 2761701954

genome instrument-data align maq --reference-name NCBI-human-build36 --instrument-data-id 2761701954 --version 0.6.5

genome instrument-data align maq -i 2761701954 -v 0.6.5
EOS
}

sub help_detail {
return <<EOS
Launch one of the integrated aligners against identified instrument data.
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    unless ($self->reference_build) {
        unless ($self->reference_name) {
            $self->error_message('No way to resolve reference build without reference_name or refrence_build');
            return;
        }
        my $ref_build = Genome::Model::Build::ReferencePlaceholder->get($self->reference_name);
        unless ($ref_build) {
            $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
                                                                            name => $self->reference_name,
                                                                            sample_type => 'dna',
                                                                        );
        }
        $self->reference_build($ref_build);
    }
    unless ($self->_alignment) {
        my $alignment = Genome::InstrumentData::Alignment->create(
                                                                  instrument_data => $self->instrument_data,
                                                                  reference_build => $self->reference_build,
                                                                  aligner_name => $self->aligner_name,
                                                                  aligner_version => $self->version,
                                                                  aligner_params => $self->params,
                                                                  force_fragment => $self->force_fragment,
                                                              );
        $self->_alignment($alignment);
    }
    return $self;
}

sub execute {
    my $self = shift;

    my $alignment = $self->_alignment;
    my $instrument_data = $alignment->instrument_data;
    my $reference_build = $alignment->reference_build;

    my $alignment_directory = $alignment->alignment_directory;
    my $resource_lock_name = $alignment_directory . '.generate';
    my $lock = $self->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
    unless ($lock) {
        $self->status_message("This data set is still being processed by its creator.  Waiting for existing data lock...");
        $lock = $self->lock_resource(resource_lock => $resource_lock_name);
        unless ($lock) {
            $self->error_message("Failed to get existing data lock!");
            return;
        }
    }
    if ($alignment->verify_alignment_data) {
        $self->status_message("Existing alignment data is available and deemed correct.");
        $self->unlock_resource(resource_lock => $lock);
        return 1;
    } else {
        $self->status_message("No alignment files found...beginning processing and setting marker to prevent simultaneous processing.");
    }
    $self->status_message("OUTPUT PATH: $alignment_directory\n");

    # do this in an eval block so we can unlock the resource cleanly when we finish
    eval {
        # TODO: move onto the instrument data itself as a method
        my $is_paired_end;
        my $upper_bound_on_insert_size;
        if ($instrument_data->is_paired_end && !$self->force_fragment) {
            my $sd_above = $instrument_data->sd_above_insert_size;
            my $median_insert = $instrument_data->median_insert_size;
            $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
            unless($upper_bound_on_insert_size > 0) {
                $self->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
                $upper_bound_on_insert_size= 600;
            }
            # TODO: extract additional details from the read set
            # about the insert size, and adjust the maq parameters.
            $is_paired_end = 1;
        }
        else {
            $is_paired_end = 0;
        }

        my $adaptor_file = $instrument_data->resolve_adaptor_file;
        unless ($adaptor_file){
            die "Failed to resolve adaptor file!"
        }

        # these are general params not infered from the above        
        my $aligner_params = $alignment->aligner_params;

        # This is implemented on a per-aligner basis.
        # When complete a BAM and/or map file should be in the directory.
        $self->run_aligner(
            alignment => $alignment,

            # is all of this really on the alignment object or instrument data already?
            output_directory => $alignment_directory,
            reference_build => $reference_build,
            aligner_params => $aligner_params, 
            is_paired_end => $is_paired_end,
            upper_bound_on_insert_size => $upper_bound_on_insert_size,
            adaptor_file => $adaptor_file,
        );
    };

    if ($@) {
        my $exception = $@;
        $alignment->remove_alignment_directory;
        eval { $self->unlock_resource(resource_lock => $resource_lock_name); };
        die ($exception);
    }

    unless ($self->process_low_quality_alignments) {
        $self->error_message('Failed to process_low_quality_alignments');
        $self->unlock_resource(resource_lock => $lock);
        return;
    }

    unless ($alignment->verify_alignment_data) {
        $self->error_message('Alignment data failed to verify after alignment');
        $self->unlock_resource(resource_lock => $lock);
        return;
    }

    # when unlocked, the data is usable by others...
    $self->unlock_resource(resource_lock => $lock);

    my $alignment_allocation = $alignment->get_allocation;
    if ($alignment_allocation) {
        unless ($alignment_allocation->reallocate) {
            $self->error_message('Failed to reallocate disk space for disk allocation: '. $alignment_allocation->id);
            return;
        }
    }
    return 1;
}

sub get_alignment_statistics {
    my $self = shift;
    die('get_alignment_statistics not implemented for '. $self->class);
}

sub run_aligner {
    die "failed to implement _run_aligner!";
}

sub process_low_quality_alignments {
    die "failed to implement process_low_quality_alignments!";
}

1;

