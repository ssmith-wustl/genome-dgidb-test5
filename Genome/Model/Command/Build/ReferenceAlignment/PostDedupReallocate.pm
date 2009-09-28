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

    my $allocation = $build->accumulated_alignments_disk_allocation;
    
    unless ($allocation) {
        $self->status_message("No allocation found, nothing to reallocate.  Shortcutting out.");
        return 1; 
    }

    $self->status_message("Now reallocating the deduplicated library allocation down to actual usage...");
    $self->status_message("Current allocation (KB): " . $allocation->kilobytes_requested);
    unless ($allocation->reallocate()) {
        $self->error_message("Reallocation request failed!  Exiting");
        return 0;
    }
    $self->status_message("New allocation (KB): " . $allocation->kilobytes_requested);
    
    return 1;
}
  
1;

