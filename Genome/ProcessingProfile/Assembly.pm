package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Assembly{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
                      sequencing_platform => {
                                              doc => 'The sequencing platform used to produce the read sets to be assembled',
                                              valid_values => ['454', 'solexa'],
                                          },
                      assembler_name => {
                                         doc => 'The name of the assembler to use when assembling read sets',
                                         valid_values => ['newbler'],
                                     },
                      assembler_params => {
                                           doc => 'A string of parameters to pass to the assembler',
                                           is_optional => 1,
                                       },
		      assembler_version => {
			                     doc => 'Version of assembler to use',
					     valid_values => ['2.0.01.12', '2.0.00.20-1', '2.0.00.20-64', '2.0.00.17-64', '2.0.00.12-64', '1.1.03.24.7-64', '1.1.03.24-64', '03092009', '01212009', '10282008', '07252008', '01252008'],
					 },
		      version_subdirectory => {
			                   doc => '454 version subdirectory name',
					   valid_values => ['offInstrumentApps','mapasm454_source'],
		                     },
                      read_trimmer_name => {
                                            doc => 'The name of the software to use when trimming read sets',
                                            is_optional => 1,
                                        },
                      read_trimmer_params => {
                                              doc => 'A string of parameters to pass to the read_trimmer',
                                              is_optional => 1,
                                          },
                      read_filter_name => {
                                           doc => 'The name of the software to use when filtering read sets',
                                           is_optional => 1,
                                       },
                      read_filter_params => {
                                             doc => 'A string of parameters to pass to the read_filter',
                                             is_optional => 1,
                                         },

    ],
};

sub stages {
    my @stages = qw/
        setup_project
        assemble
    /;
    return @stages;
}

sub setup_project_job_classes {
    my @classes = qw/
            Genome::Model::Event::Build::Assembly::FilterReadSet
            Genome::Model::Event::Build::Assembly::TrimReadSet
            Genome::Model::Event::Build::Assembly::AddReadSetToProject
    /;
    #Genome::Model::Event::Build::Assembly::AssignReadSetToModel
    return @classes;
}

sub assemble_job_classes {
    my @classes = qw/
            Genome::Model::Event::Build::Assembly::Assemble
    /;
    return @classes;
}

sub setup_project_objects {
    my $self = shift;
    my $model = shift;
    # return ($model->unbuilt_instrument_data, $model->built_instrument_data);
    # WAS:
    # return $model->unbuilt_instrument_data;
    my @builds = $self->model->builds;
    unless ( @builds ) {
        die "Model (".$self->model->id.") has no builds, and cannot get unbuilt instrument data";
    }
    return $builds[$#builds]->instrument_data;
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

