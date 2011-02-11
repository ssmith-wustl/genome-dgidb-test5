package Genome::Disk::Allocation::Command::Reallocate;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Disk::Allocation::Command::Reallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [
        allocations => {
            is => 'Genome::Disk::Allocation',
            shell_args_position => 1,
            doc => 'allocation(s) to reallocate, resolved by Genome::Command::Base',
            is_many => 1,
        },
    ],
    has_optional => [
        kilobytes_requested => {
            is => 'Number',
            doc => 'Number of kilobytes that target allocation should reserve, if not ' .
                'provided then the current size of the allocation is used',
        },
    ],
    doc => 'This command changes the requested kilobytes for a target allocation',
};

sub help_brief {
    return 'Changes the requested kilobytes field on the target allocation';
}

sub help_synopsis { 
    return 'Changes the requested kilobytes field on the target allocation';
}

sub help_detail {
    return <<EOS
Changes the requested kilobytes field on the target allocation. If no value
is supplied to this command, the field is set to the current size of the
allocation.
EOS
}

sub execute {
    my $self = shift;

    my @allocations = $self->allocations;
    
    my @errors;
    for my $allocation (@allocations) {
        my %params;
        $params{allocation_id} = $allocation->id;
        $params{kilobytes_requested} = $self->kilobytes_requested if defined $self->kilobytes_requested;

        my $transaction = UR::Context::Transaction->begin();
        my $successful = Genome::Disk::Allocation->reallocate(%params);
        
        if ($successful) {
            $self->status_message("Successfully reallocated (" . $allocation->__display_name__ . ").");
            $transaction->commit();
        }
        else {
            push @errors, "Failed to reallocate (" . $allocation->__display_name__ . "): $@.";
            $transaction->rollback();
        }
    }

    $self->display_summary_report(scalar(@allocations), @errors);

    return !scalar(@errors);
}

1;
