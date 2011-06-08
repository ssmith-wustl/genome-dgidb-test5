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
        sd_below_insert_size            => { via => 'instrument_data'},
        is_paired_end                   => { via => 'instrument_data' },
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


sub __display_name__ {
    my $self = shift;
    my $data = $self->instrument_data;
    return $data->__display_name__;
}


sub create {
    my $class = shift;

    my $caller = caller();
    if ( not $caller or $caller ne 'Genome::Model::Input') {
        Carp::confess('Genome::Model::InstrumentDataAssignment create must be called from Genome::Model::Input create!');
    }

    return $class->SUPER::create(@_);
}

sub delete {
    my $self = shift;

    my $caller = caller();
    if ( not $caller or $caller ne 'Genome::Model::Input') {
        Carp::confess('Genome::Model::InstrumentDataAssignment delete must be called from Genome::Model::Input delete!');
    }

    return $self->SUPER::delete;
}

# TODO: remove this.  There may be multiple read length per instdata.
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

1;

