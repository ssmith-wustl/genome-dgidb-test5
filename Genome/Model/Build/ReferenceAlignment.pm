package Genome::Model::Build::ReferenceAlignment;

#REVIEW fdu
#Looks ok to me except for two ideas:
#1. can accumulated_alignment be renamed to dedup ?
#2. can eviscerate method be pulled out to base class G::M::Build so other types of builds besides ref-align can use it too ?


use strict;
use warnings;

use Genome;
use File::Path 'rmtree';

class Genome::Model::Build::ReferenceAlignment {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    has => [],
};

sub accumulated_alignments_directory {
    my $self = shift;
    return $self->data_directory . '/alignments';
}

sub accumulated_alignments_disk_allocation {
    my $self = shift;

    my $dedup_event = Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries->get(model_id=>$self->model->id,
                                                                                                   build_id=>$self->build_id);

    return if (!$dedup_event);
    
    my $disk_allocation = Genome::Disk::Allocation->get(owner_class_name=>ref($dedup_event), owner_id=>$dedup_event->id);
    
    return $disk_allocation;
}

sub variants_directory {
    my $self = shift;
    return $self->data_directory . '/variants';
}

sub delete {
    my $self = shift;
    
    # if we have an alignments directory, nuke it first since it has its own allocation
    if (-e $self->accumulated_alignments_directory) {
        unless($self->eviscerate()) {
            my $eviscerate_error = $self->error_mesage();
            $self->error_message("Eviscerate failed: $eviscerate_error");
            return;
        };
    }
    
    $self->SUPER::delete(@_);
}

# nuke the accumulated alignment directory
sub eviscerate {
    my $self = shift;
    
    $self->status_message('Entering eviscerate for build:' . $self->id);
    
    my $alignment_alloc = $self->accumulated_alignments_disk_allocation;
    my $alignment_path = ($alignment_alloc ? $alignment_alloc->absolute_path :  $self->accumulated_alignments_directory);
    
    if (!-d $alignment_path && !-l $self->accumulated_alignments_directory) {
        $self->status_message("Nothing to do, alignment path doesn't exist and this build has no alignments symlink.  Skipping out.");
        return;
    }

    $self->status_message("Removing tree $alignment_path");
    if (-d $alignment_path) {
        rmtree($alignment_path);
        if (-d $alignment_path) {
            $self->error_message("alignment path $alignment_path still exists after evisceration attempt, something went wrong.");
            return;
        }
    }
    
    if ($alignment_alloc) {
        unless ($alignment_alloc->deallocate) {
            $self->error_message("could not deallocate the alignment allocation.");
            return;
        }
    }

    if (-l $self->accumulated_alignments_directory && readlink($self->accumulated_alignments_directory) eq $alignment_path ) {
        $self->status_message("Unlinking symlink: " . $self->accumulated_alignments_directory);
        unless(unlink($self->accumulated_alignments_directory)) {
            $self->error_message("could not remove symlink to deallocated accumulated alignments path");
            return;
        }
    }

    return 1;
}

sub _resolve_subclass_name {
    my $class = shift;

    my $sequencing_platform;
    if (ref($_[0])) {
        if ($_[0]->isa(__PACKAGE__) || $_[0]->can('model')) {
            $sequencing_platform = $_[0]->model->sequencing_platform;
        }
    } else {
        my %params = @_;
        my $model_id = $params{model_id};
        my $model = Genome::Model->get($model_id);
        $sequencing_platform = $model->sequencing_platform;
    }

    unless ( $sequencing_platform ) {
        my $rule = $class->get_rule_for_params(@_);
        $sequencing_platform = $rule->specified_value_for_property_name('sequencing_platform');
    }

    return ( defined $sequencing_platform ) 
        ? $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform)
            : undef;
}

sub _resolve_subclass_name_for_sequencing_platform {
    my ($class,$sequencing_platform) = @_;
    my @type_parts = split(' ',$sequencing_platform);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::Model::Build::ReferenceAlignment' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::Model::Build::ReferenceAlignment::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $sequencing_platform = lc(join(" ", @words));
    return $sequencing_platform;
}


1;

