package Genome::Model::Assembly;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Assembly {
    is => 'Genome::Model',
    has => [
            read_set_assignment_events   => { is => 'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
                                              is_many => 1,
                                              reverse_id_by => 'model',
                                              where => [ "event_type like" => 'genome-model build assembly assign-read-sets%'],
                                              doc => 'each case of a read set being assigned to the model',
                                        },
        ],
};

sub test {
    # Hard coded param for now
    return 1;
}

sub assembly_directory {
    my $self = shift;
    return $self->data_directory . '/assembly';
}

sub read_set_class_name { 
    return 'Genome::RunChunk::454';
}

sub input_read_set_class_name {
    my $self = shift;
    return $self->read_set_class_name->_dw_class;
}

sub compatible_read_set_ids {
    my $self = shift;
    my @compatible_read_sets = $self->input_read_set_class_name->get(sample_name => $self->sample_name);
    my @ids = map {$_->region_id} @compatible_read_sets;
    return @ids;
}

sub get_or_create_compatible_read_sets {
    my $self = shift;
    my @read_sets;
    
    my @compatible_read_set_ids = $self->compatible_read_set_ids;
    for my $read_set_id (@compatible_read_set_ids) {
        my $read_set = $self->read_set_class_name->get_or_create_from_read_set_id($read_set_id);
        unless($read_set) {
            die("Failed to find read set '$read_set_id'");
        }
        push @read_sets, $read_set;
    }
    return @read_sets;
}

sub available_read_sets {
    my $self = shift;
    my @compatible_read_sets = $self->get_or_create_compatible_read_sets;
    my @read_set_assignment_events = $self->read_set_assignment_events;
    my %prior = map { $_->run_id => 1 } @read_set_assignment_events;
    my @available_read_sets = grep { not $prior{$_->id} } @compatible_read_sets;
    return @available_read_sets;
}


1;
