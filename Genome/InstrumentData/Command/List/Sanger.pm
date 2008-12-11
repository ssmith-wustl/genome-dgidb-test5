package Genome::InstrumentData::Command::List::Sanger;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::InstrumentData::Command::List::Sanger {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::InstrumentData::Sanger' 
        },
        #show => { default_value => 'id,name,subject_name,processing_profile_name' },
    ],
    doc => 'list sanger/3730 runs (96-well) available for analysis',
};

sub _base_filter {
    'sequencing_platform=sanger'
}

1;

#$HeadURL: /gscpan/perl_modules/trunk/Genome/InstrumentData/Command/List.pm $
#$Id: /gscpan/perl_modules/trunk/Genome/InstrumentData/Command/List.pm 41086 2008-11-17T19:51:31.012449Z ebelter  $
