package Genome::Model::Command::Build::ReferenceAlignment::PostDedupReallocate;

use strict;
use warnings;

use Genome;
use Command; 

class Genome::Model::Command::Build::ReferenceAlignment::PostDedupReallocate {
    is => ['Genome::Model::Event'],
};

sub sub_command_sort_position { 52}

sub help_brief {
    "Recover disk allocations made to allow extra space for deduplication, and add a safety margin for downstream steps"
}

sub help_synopsis {
    return <<"EOS"
    genome-model build reference-alignment post-dedup-reallocate --model-id 5  --build-id 123 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<"EOS"
This command is launched automatically by the workflow process

EOS
}

sub execute {
    my $self = shift;
    my $build = $self->build;

    my $allocation = $build->disk_allocation;

    unless ($allocation) {
        $self->status_message("No allocation found, nothing to reallocate.  Shortcutting out.");
        return 1; 
    }

    my $actual_allocated_space = $allocation->get_actual_disk_usage;
    my $new_reallocation_request = $actual_allocated_space + 30000000;

    $self->status_message("Now reallocating down to $new_reallocation_request kb");
    unless ($allocation->reallocate(kilobytes_requested => $new_reallocation_request)) {
        $self->error_message("Reallocation request failed!  Exiting");
        return 0;
    }
    
    return 1;
}
  
1;

