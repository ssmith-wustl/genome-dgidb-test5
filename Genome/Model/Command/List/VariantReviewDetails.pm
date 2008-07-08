package Genome::Model::Command::List::VariantReviewDetails;
use strict;
use warnings;

use above 'Genome';

UR::Object::Type->define(
    class_name => __PACKAGE__, 
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => { is_constant => 1, value => 'Genome::VariantReviewDetail' },
        model               => { is_optional => 1 },
        show                => { default_value => 'chromosome,begin_position,end_position,variant_type,somatic_status' },
    ],
);

sub help_brief{
    return "Stupid test";
}

sub help_synopsis{
    return "gt boolean-test-again --list <list> --logfile <log file for abnormal backups> --separation_char <char>";
}

sub help_detail{
    return "This is a stupid module designed to test out the boolean expression engine.  If found in production, please delete.";
}

1;
