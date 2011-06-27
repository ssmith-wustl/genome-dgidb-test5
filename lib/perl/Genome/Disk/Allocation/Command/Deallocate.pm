package Genome::Disk::Allocation::Command::Deallocate;

use strict;
use warnings;

use Genome;
use Carp 'confess';

class Genome::Disk::Allocation::Command::Deallocate {
    is => 'Genome::Disk::Allocation::Command',
    has => [        
        allocations => {
            is => 'Genome::Disk::Allocation',
            shell_args_position => 1,
            doc => 'allocation(s) to deallocate, resolved by Genome::Command::Base',
            is_many => 1,
        },
    ],
    doc => 'Removes target allocation and deletes its directories',
};

sub help_brief {
    return 'Removes the target allocation and deletes its directories';
}

sub help_synopsis {
    return 'Removes the target allocation and deletes its directories';
}

sub help_detail {
    return 'Removes the target allocation and deletes its directories';
}

sub execute { 
    my $self = shift;

    my @allocations = $self->allocations;
    my @errors;
    for my $allocation (@allocations) {
        my $display_name = $allocation->__display_name__;
        my $transaction = UR::Context::Transaction->begin();
        my $successful = Genome::Disk::Allocation->delete(allocation_id => $allocation->id);

        if ($successful and $transaction->commit) {
            $self->status_message("Successfully deallocated ($display_name).");
        }
        else {
            push @errors, "Failed to deallocate ($display_name): $@.";  
            $transaction->rollback;
        }
    }

    $self->display_command_summary_report(scalar(@allocations), @errors);

    return !scalar(@errors);
}

    
1;
