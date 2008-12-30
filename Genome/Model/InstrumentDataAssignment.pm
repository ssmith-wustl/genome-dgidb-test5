package Genome::Model::InstrumentDataAssignment;

use strict;
use warnings;

use Genome;
class Genome::Model::InstrumentDataAssignment {
    table_name => 'MODEL_INSTRUMENT_DATA_ASSGNMNT',
    id_by => [
    #model_id           => { is => 'NUMBER', len => 10 },
    #instrument_data_id => { is => 'VARCHAR2', len => 1000 },
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
        #< Attributes from the model >#
        alignment_directory => { via => 'model'},
        #< Attributes from the instrument data >#
        run_name => { via => 'instrument_data'},

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
        unique_reads_across_library     => { via => 'instrument_data' },
        duplicate_reads_across_library  => { via => 'instrument_data' },
        median_insert_size => {via => 'instrument_data'},
        sd_above_insert_size => {via => 'instrument_data'},
        is_paired_end => {via => 'instrument_data' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub read_set_alignment_directory {
    my $self = shift;

    return sprintf('%s/%s/%s_%s',
                       $self->alignment_directory,
                       $self->run_name,
                       $self->subset_name,
                       $self->instrument_data->id
                  );
}

1;

#$HeadURL$
#$Id$
