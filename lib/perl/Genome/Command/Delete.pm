package Genome::Command::Delete;

use strict;
use warnings;

use Genome;
      
require Carp;
use Data::Dumper 'Dumper';
require Lingua::EN::Inflect;

class Genome::Command::Delete {
    is => 'Command::V2',
    is_abstract => 1,
    doc => 'CRUD delete command class.',
};

sub _target_name { Carp::confess('Please use CRUD or implement _target_name in '.$_[0]->class); }
sub _target_name_pl { Carp::confess('Please use CRUD or implement _target_name_pl in '.$_[0]->class); }
sub _target_name_pl_ub { my $target_name_pl = $_[0]->_target_name_pl; $target_name_pl =~ s/ /\_/g; return $target_name_pl; }

sub sub_command_sort_position { .4 };

sub help_brief {
    return 'delete '.Lingua::EN::Inflect::PL($_[0]->_target_name);
}

sub help_detail {
    my $class = shift;
    my $target_name_pl = $class->_target_name_pl;
    return "This command deletes $target_name_pl resolved via text string.";
}

sub execute {
    my $self = shift;

    $self->status_message('Delete '.$self->_target_name_pl);

    my $target_name_pl_ub = $self->_target_name_pl_ub;
    my @objects = $self->$target_name_pl_ub;
    my %errors;
    for my $obj ( @objects ) {
        $self->_total_command_count($self->_total_command_count + 1);
        my $transaction = UR::Context::Transaction->begin();
        my $display_name = $self->display_name_for_value($obj);
        my $deleted = eval{ $obj->delete };
        if ($deleted and $transaction->commit) {
            $self->status_message("Deleted $display_name");
        }
        else {
            $self->append_error($display_name, "Failed to delete $display_name");
            $transaction->rollback;
        }
    }

    $self->display_command_summary_report();

    return 1; 
}

1;

