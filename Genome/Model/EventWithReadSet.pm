package Genome::Model::EventWithReadSet;

use strict;
use warnings;

use Genome;

class Genome::Model::EventWithReadSet {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
            read_set       => { is => 'Genome::RunChunk', id_by => 'read_set_id', constraint_name => 'event_run' },
            read_set_link  => { is => 'Genome::Model::ReadSet', id_by => ['model_id','read_set_id'] },
            read_set_name  => { via => 'read_set', to => 'full_name' },
            read_set_id    => {
                               is => 'NUMBER',
                               len => 11,
                               doc => 'the id of thegenome_model_run on which to operate',
                           },
            run_name            => { via => 'read_set_link' },
            run_short_name      => { via => 'read_set_link' },
            run_subset_name     => { via => 'read_set_link', to => 'subset_name' },
            library_name        => { via => 'read_set_link' },
            sample_name         => { via => 'read_set_link' },
            alignment_directory => { via => 'read_set_link'},
            read_set_alignment_directory  => {
                                          calculate_from => ['alignment_directory','read_set_link'],
                                          calculate => q|
                                              return sprintf('%s/%s/%s_%s',
                                                             $alignment_directory,
                                                             $read_set_link->run_name,
                                                             $read_set_link->subset_name,
                                                             $read_set_link->seq_id,
                                                            );
                                          |,
                            },
            #This is temporary so the 454 test runs without creating a bunch of lengthy blat alignments
            #Please fix once a standard testing scheme is developed
            new_read_set_alignment_directory => {
                                                 calculate_from => ['alignment_directory','read_set_link'],
                                                 calculate => q|
                                              return sprintf('%s/%s/%s/%s',
                                                             $alignment_directory,
                                                             $read_set_link->sample_name,
                                                             $read_set_link->run_name,
                                                             $read_set_link->subset_name,
                                                            );
                                          |,
                                             },

        # deprecated
        read_set_directory  => {
                                calculate_from => ['model','read_set_link'],
                                calculate => q|
                                    return sprintf('%s/runs/%s/%s',$model->data_directory,
                                                                   $read_set_link->sequencing_platform,
                                                                   $read_set_link->name);
                                |,
                                doc => 'Only keep this as long as we are moving old read data',
                                is_deprecated => 1,
                            },
        run                 => { is => 'Genome::RunChunk', id_by => 'read_set_id', is_deprecated => 1 }, # use read_set
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
                and $_->property_name !~ /(model_id|read_set_id)/
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

    unless (Genome::RunChunk->get(id => $self->read_set_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['read_set_id'],
                                            desc => "There is no genome run with read_set_id ". $self->read_set_id,
                                        );
    }
    return @tags;
}

sub resolve_log_directory {
    my $self = shift;
    return sprintf('%s/logs/%s/%s',
                   $self->model->latest_build_directory,
                   $self->read_set_link->sequencing_platform,
                   $self->run_name
               );
}

1;

