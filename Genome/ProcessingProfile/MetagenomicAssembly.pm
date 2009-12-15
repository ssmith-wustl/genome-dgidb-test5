package Genome::ProcessingProfile::MetagenomicAssembly;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MetagenomicAssembly{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        sequencing_platform => {
                                doc => 'The sequencing platform used to produce the read sets to be assembled',
                                valid_values => ['solexa'],
                            },
        assembler_name => {
                           doc => 'The name of the assembler to use when assembling read sets',
                           valid_values => ['velvet'],
                       },
        contaminant_database => {
                           doc => 'The contaminant database to screen the reads against',
                       },
        contaminant_algorithm => {
                                  doc => 'The algorithm to use for screening reads against a contaminant database',
                              }
        ],
};

sub stages {
    my @stages = qw/
        contaminant_screen
        assemble
    /;
    return @stages;
}

sub contaminant_screen_job_classes {
    my @classes = qw/
            Genome::Model::Event::Build::MetagenomicAssembly::ContaminantScreen
    /;
    return @classes;
}

sub assemble_job_classes {
    my @classes = qw/
            Genome::Model::Event::Build::MetagenomicAssembly::Assemble
    /;
    return @classes;
}

sub contaminant_screen_objects {
    my $self = shift;
    my $model = shift;
    return $model->instrument_data;
}

sub assemble_objects {
    my $self = shift;
    my $model = shift;
    return 1;
}

sub instrument_data_is_applicable {
    my $self = shift;
    my $instrument_data_type = shift;
    my $instrument_data_id = shift;
    my $subject_name = shift;

    my $lc_instrument_data_type = lc($instrument_data_type);
    if ($self->sequencing_platform) {
        unless ($self->sequencing_platform eq $lc_instrument_data_type) {
            $self->error_message('The processing profile sequencing platform ('. $self->sequencing_platform
                                 .') does not match the instrument data type ('. $lc_instrument_data_type .')');
            return;
        }
    }

    return 1;
}

1;

