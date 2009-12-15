package Genome::Model::Event::Build::ReferenceAlignment::PostDedupReallocate;

#REVIEW fdu 11/19/2009
#Can this step be moved to G::M::C::B::R::DeduplicateLibraries as a
#method and make each dedup subclass calling this method at the end of
#dedup process ?

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::PostDedupReallocate {
    is => ['Genome::Model::Event'],
};

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

