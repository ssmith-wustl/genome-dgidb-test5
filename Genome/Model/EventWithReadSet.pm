package Genome::Model::EventWithReadSet;

use strict;
use warnings;

use Genome;

class Genome::Model::EventWithReadSet {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
            instrument_data_assignment => {
                                           is => 'Genome::Model::InstrumentDataAssignment',
                                           id_by => ['model_id','instrument_data_id'],
                                       },
            read_set_name  => { via => 'instrument_data_assignment', to => 'full_name' },
            instrument_data_id    => {
                               is => 'NUMBER',
                               len => 11,
                               doc => 'the id of the instrument data on which to operate',
                           },
            run_name            => { via => 'instrument_data_assignment' },
            run_short_name      => { via => 'instrument_data_assignment' },
            run_subset_name     => { via => 'instrument_data_assignment', to => 'subset_name' },
            library_name        => { via => 'instrument_data_assignment' },
            sample_name         => { via => 'instrument_data_assignment' },

        # deprecated
        alignment_directory => { via => 'instrument_data_assignment'},
        read_set_alignment_directory  => { via => 'instrument_data_assignment'} ,
    ],
    sub_classification_method_name => '_get_sub_command_class_name',
};

sub desc {
    my $self = shift;
    my $desc = $self->SUPER::desc;
    $desc .= " for read set " . $self->read_set_name;
    return $desc;
}

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep {
            not (
                $_->class_name eq __PACKAGE__
                and $_->property_name !~ /(model_id|instrument_data_id)/
            )
        } shift->SUPER::_shell_args_property_meta(@_);
}

sub invalid {
    my ($self) = shift;

    my @tags = $self->SUPER::invalid(@_);
    unless (Genome::Model->get($self->model_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['model_id'],
                                            desc => "There is no model with id ". $self->model_id,
                                        );
    }

    if (!Genome::InstrumentData->get($self->instrument_data_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['instrument_data_id'],
                                            desc => "There is no instrument data with instrument_data_id ". $self->instrument_data_id,
                                        );
    }
    return @tags;
}

sub resolve_log_directory {
    my $self = shift;
    return sprintf('%s/logs/%s/%s',
                   $self->model->latest_build_directory,
                   $self->instrument_data_assignment->sequencing_platform,
                   $self->run_name
               );
}

1;

