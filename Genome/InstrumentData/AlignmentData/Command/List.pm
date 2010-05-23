package Genome::InstrumentData::AlignmentData::Command::List;
use strict;
use warnings;
use Genome;

class Genome::InstrumentData::AlignmentData::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name => { is_constant => 1, value => 'Genome::InstrumentData::AlignmentData' },
        filter => { 
            shell_args_position => 1, 
            default_value => '' 
        },
        show => {
            default_value => 'id,instrument_data_id,reference_name,aligner_name,aligner_version,aligner_params,trimmer_name,trimmer_version,trimmer_params,filter_name,test_name,output_dir'
        },
    ],
    doc => 'list alignment data sets'
};

1;

