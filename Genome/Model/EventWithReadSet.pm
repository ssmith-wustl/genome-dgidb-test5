package Genome::Model::EventWithReadSet;

use strict;
use warnings;

use above "Genome";

class Genome::Model::EventWithReadSet {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [
        read_set            => { is => 'Genome::RunChunk', id_by => 'run_id', is_optional => 0, constraint_name => 'event_run' },
        read_set_id         => { via => 'read_set', to => 'seq_id' }, # not really the fk currently (run_id), see below...        
        read_set_name       => { via => 'read_set', to => 'full_name' },

        # use the "read_set" terminology
        run_id              => { is => 'NUMBER', len => 11, is_optional => 0, doc => 'the genome_model_run on which to operate', is_deprecated => 1 }, # don't use
        run                 => { is => 'Genome::RunChunk', id_by => 'run_id', is_deprecated => 1 }, # use read_set

        run_name            => { via => 'read_set' },
        run_short_name      => { via => 'read_set', to => 'short_name' },
        run_subset_name     => { via => 'read_set', to => 'subset_name' },
        
        library_name        => { via => 'read_set' },
        sample_name         => { via => 'read_set' },
        
        alignment_directory => { via => 'model'},
        read_set_alignment_directory  => {
                                          calculate_from => ['alignment_directory','read_set'],
                                          calculate => q|
                                              return sprintf('%s/%s/%s_%s',
                                                             $alignment_directory,
                                                             $read_set->run_name,
                                                             $read_set->subset_name,
                                                             $read_set->seq_id,
                                                            );
                                          |,
                            },
            #This is temporary so the 454 test runs without creating a bunch of lengthy blat alignments
            #Please fix once a standard testing scheme is developed
        new_read_set_alignment_directory => {
                                             calculate_from => ['alignment_directory','read_set'],
                                             calculate => q|
                                              return sprintf('%s/%s/%s/%s',
                                                             $alignment_directory,
                                                             $read_set->sample_name,
                                                             $read_set->run_name,
                                                             $read_set->subset_name,
                                                            );
                                          |,
                                         },

        # deprecated
        read_set_directory  => {
                                calculate_from => ['model','read_set'],
                                calculate => q|
                                    return sprintf('%s/runs/%s/%s',$model->data_directory,
                                                                   $read_set->sequencing_platform,
                                                                   $read_set->name);
                                |,
                                doc => 'Only keep this as long as we are moving old read data',
                                is_deprecated => 1,
                            },
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
                and $_->property_name !~ /(model_id|run_id)/
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

    unless (Genome::RunChunk->get(id => $self->run_id)) {
        push @tags, UR::Object::Tag->create(
                                            type => 'invalid',
                                            properties => ['run_id'],
                                            desc => "There is no genome run with id ". $self->run_id,
                                        );
    }
    return @tags;
}

1;

