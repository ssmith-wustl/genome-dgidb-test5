package Genome::Command::Delete;

use strict;
use warnings;

use Genome;
      
require Carp;
use Data::Dumper 'Dumper';

class Genome::Command::Delete {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    doc => 'CRUD delete command class.',
};

sub _name_for_objects { Carp::confess('Please use CRUD or implement _name_for_objects in '.$_[0]->class); }
sub _name_for_objects_ub { Carp::confess('Please use CRUD or implement _name_for_objects_ub in '.$_[0]->class); }

sub sub_command_sort_position { .4 };

sub help_brief {
    return 'delete '.$_[0]->_name_for_objects;
}

sub help_detail {
    return 'HELP IN PROGRESS';
}

sub execute {
    my $self = shift;

    $self->status_message('Delete '.$self->_name_for_objects);

    my $name_for_objects_ub = $self->_name_for_objects_ub;
    my @objects = $self->$name_for_objects_ub;
    my @errors;
    for my $obj ( @objects ) {
        my $transaction = UR::Context::Transaction->begin();
        my $name = $obj->__display_name__;
        my $deleted = eval{ $obj->delete; };
        if ( $deleted ) {
            if ($transaction->commit) {
                $self->status_message("Deleted $name");
            }
        }
        else {
            push @errors, "Failed to delete $name";
            $transaction->rollback;
        }
    }

    $self->display_summary_report(scalar(@objects), @errors);

    return 1; 
}

1;

