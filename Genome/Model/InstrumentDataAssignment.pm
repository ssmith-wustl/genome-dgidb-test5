package Genome::Model::InstrumentDataAssignment;

use strict;
use warnings;
use Genome;

class Genome::Model::InstrumentDataAssignment {
    table_name => 'MODEL_INSTRUMENT_DATA_ASSGNMNT',
    id_by => [
        model => { 
            is => 'Genome::Model',
            id_by => 'model_id',
        },
        instrument_data => { 
            is => 'Genome::InstrumentData',
            id_by => 'instrument_data_id',
        },
    ],
    has => [
        first_build_id => { is => 'NUMBER', len => 10, is_optional => 1 },
        
        filter_desc         => { is => 'Text', is_optional => 1, 
                                valid_values => ['forward-only','reverse-only',undef],
                                doc => 'limit the reads to use from this instrument data set' },
        
        first_build         => { is => 'Genome::Model::Build', id_by => 'first_build_id', is_optional => 1 },
        
        #< Attributes from the instrument data >#
        run_name            => { via => 'instrument_data'},
        
        #< Left over from Genome::Model::ReadSet >#
        # PICK ONE AND FIX EVERYTHING THAT USES THIS
        subset_name         => { via => 'instrument_data'},
        run_subset_name     => { via => 'instrument_data', to => 'subset_name'},
        
        # PICK ONE AND FIX EVERYTHING THAT USES THIS
        short_name          => { via => 'instrument_data' },
        run_short_name      => { via => 'instrument_data', to => 'short_name' },
        library_name        => { via => 'instrument_data' },
        sample_name         => { via => 'instrument_data' },
        sequencing_platform => { via => 'instrument_data' },
        full_path           => { via => 'instrument_data' },
        full_name           => { via => 'instrument_data' },
        _calculate_total_read_count     => { via => 'instrument_data' },
        unique_reads_across_library     => { via => 'instrument_data' },
        duplicate_reads_across_library  => { via => 'instrument_data' },
        median_insert_size              => { via => 'instrument_data'},
        sd_above_insert_size            => { via => 'instrument_data'},
        is_paired_end                   => { via => 'instrument_data' },
    ],
    has_optional_transient => [
        _alignment => {
            is => 'Genome::InstrumentData::Alignment',
        },
        _alignments => {
            is => 'Genome::InstrumentData::Alignment',
            is_many => 1,
        },
    ],
    has_many_optional => [
        events => {
            is => 'Genome::Model::Event',
            reverse_id_by => 'instrument_data_assignment',
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

# FIXME temporary - copy model instrument data as inputs, when all 
#  inst_data is an input, this (the whole create) can be removed
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    if ( not $self->model_id or not $self->model ) {
        $self->error_message("No model id or model.");
        #$self->delete;
        return $self;
    }
    
    if ( not $self->instrument_data_id or not $self->instrument_data ) {
        $self->error_message("No instrument data id or instrument data.");
        #$self->delete;
        return $self;
    }

    # Adding as input cuz of mock inst data
    unless ( $self->model->add_input(
            name => 'instrument_data',
            value_class_name => $self->instrument_data->class,
            value_id => $self->instrument_data->id,
        ) ) {
        $self->error_message("Can't add instrument data (".$self->instrument_data_id.") as an input to mode.");
        $self->delete;
        return;
    }

    return $self;
}

sub __errors__ {
    my ($self) = shift;

    my @tags = $self->SUPER::__errors__(@_);
    unless (Genome::Model->get($self->model_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['model_id'],
                                            desc => "There is no model with id ". $self->model_id,
                                        );
    }

    unless (Genome::InstrumentData->get($self->instrument_data_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['instrument_data_id'],
                                            desc => "There is no instrument data with id ". $self->instrument_data_id,
                                        );
    }
    return @tags;
}

sub alignment_directory {
    my $self = shift;
    my $alignment = $self->alignment;
    return unless $alignment;
    return $alignment->alignment_directory;
}

sub alignment {
    my $self = shift;

    my $model = $self->model;
    unless ($model->type_name eq 'reference alignment') {
        $self->error_message('Can not create an alignment object for model type '. $model->type_name);
        return;
    }
    my @alignments;
    unless ($self->_alignments) {
        my %params = (
                      instrument_data_id => $self->instrument_data_id,
                      aligner_name => $model->read_aligner_name,
                      reference_name => $model->reference_sequence_name,
                  );

        # These are tracked in the alignment identity 
        if ($model->read_aligner_version) {
            $params{'aligner_version'} = $model->read_aligner_version;
        }
        if ($model->read_aligner_params) {
            $params{'aligner_params'} = $model->read_aligner_params;
        }

        # This is tracked in the alignment identity, but has special code.
        # TODO: merge this with the filter.
        if ($model->force_fragment) {
            $params{'force_fragment'} = $model->force_fragment;
        }

        # These are possibly not tracked, and as such could be breaking things.
        if ($model->read_trimmer_name) {
            $params{'trimmer_name'} = $model->read_trimmer_name;
        }
        if ($model->read_trimmer_version) {
            $params{'trimmer_version'} = $model->read_trimmer_version;
        }
        if ($model->read_trimmer_params) {
            $params{'trimmer_params'} = $model->read_trimmer_params;
        }

        # These should be given generic names, or merged into the aligner parameters.
        if ($model->picard_version) {
            $params{'picard_version'} = $model->picard_version;
        }
        if ($model->samtools_version) {
            $params{'samtools_version'} = $model->samtools_version;
        }

        # New.  This will probably eventually composite any filters on the processing profile
        # with explicit, per-data filters.  The former are preferred, but the later are needed
        # for people to do experiments.
        if ($self->filter_desc) {
            $params{'filter_name'} = $self->filter_desc;
        }

        my $alignment = Genome::InstrumentData::Alignment->create(%params);
        unless ($alignment) {
            $self->error_message('Failed to create an alignment object');
            return;
        }

        #$self->_alignment($alignment);
        push @alignments, $alignment;
        #Now create 'Paired End Read 1' fwd alignment
        if ($model->force_fragment && $self->instrument_data->is_paired_end) {
            my $instrument_data = $self->instrument_data;
            $params{instrument_data_id} = $instrument_data->fwd_seq_id;
            my $alignment_fwd = Genome::InstrumentData::Alignment->create(%params);
            unless ($alignment_fwd) {
                $self->error_message('Failed to create a fwd alignment object');
                return;
            }
            push @alignments, $alignment_fwd;
        }
        $self->_alignments(\@alignments);
    }
    my @return = $self->_alignments;
    return $return[0];
}

sub alignments {
    my $self = shift;
    $self->alignment(@_);
    return $self->_alignments;
}

sub read_length {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    unless ($instrument_data) {
        die('no instrument data for id '. $self->instrument_data_id .'  '. Data::Dumper::Dumper($self));
    }
    my $read_length = $instrument_data->read_length;
    if ($read_length <= 0) {
        die("Impossible value '$read_length' for read_length field for instrument data:". $self->id);
    }
    return $read_length;
}
sub yaml_string {
    my $self = shift;
    return YAML::Dump($self);
}

sub delete {
    my $self = shift;

    $self->warning_message('DELETING '. $self->class .': '. $self->id);
    return $self->SUPER::delete();
}

1;

#$HeadURL$
#$Id$
