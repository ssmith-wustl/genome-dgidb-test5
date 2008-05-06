package Genome::Model::EventWithReadSet;

use strict;
use warnings;

use above "Genome";

class Genome::Model::EventWithReadSet {
    is => 'Genome::Model::Event',
    is_abstract => 1,
    has => [         
        read_set            => { is => 'Genome::RunChunk', id_by => 'run_id', is_optional => 0, constraint_name => 'event_run' },
        read_set_id         => { via => 'run', to => 'seq_id' }, # not really the fk currently (run_id), see below...
        
        run_name            => { via => 'read_set' },
        run_short_name      => { via => 'read_set', to => 'short_name' },
        run_subset_name     => { via => 'read_set', to => 'subset_name' },
        
        library_name        => { via => 'read_set' },
        sample_name         => { via => 'read_set' },
        
        # deprecated
        run_id              => { is => 'NUMBER', len => 11, is_optional => 0, doc => 'the genome_model_run on which to operate', is_deprecated => 1 }, # don't use
        run                 => { is => 'Genome::RunChunk', id_by => 'run_id', is_deprecated => 1 }, # use read_set
    ],
};

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep {
            not (
                $_->class_name eq __PACKAGE__
                and $_->property_name !~ /(model_id|run_id)/
            )
        } shift->SUPER::_shell_args_property_meta(@_);
}

# TODO: replace with override to invalid()
sub invalid {
    my($class,%params) = @_;

    unless ($params{'model_id'} && $params{'run_id'}) {
        $class->error_message("both model_id and run_id are required params when creating a $class");
        return;
    }

    unless (Genome::Model->get(id => $params{'model_id'})) {
        $class->error_message("There is no model with id ".$params{'model_id'});
        return;
    }

    unless (Genome::RunChunk->get(id => $params{'run_id'}) ) {
        $class->error_message("There is no run with id ".$params{'run_id'});
        return;
    }

    return 1;
}

1;
