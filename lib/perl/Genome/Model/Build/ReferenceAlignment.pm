package Genome::Model::Build::ReferenceAlignment;

#REVIEW fdu
#Looks ok to me except for two ideas:
#1. can accumulated_alignment be renamed to dedup ?
#2. can eviscerate method be pulled out to base class G::M::Build so other types of builds besides ref-align can use it too ?


use strict;
use warnings;

use Genome;
use File::Path 'rmtree';
use Carp;

class Genome::Model::Build::ReferenceAlignment {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => { is => 'String', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                           calculate_from => ['model_id'],
                           calculate => sub {
                                            my($model_id) = @_;
                                            return unless $model_id;
                                            my $model = Genome::Model->get($model_id);
                                            Carp::croak("Can't find Genome::Model with ID $model_id while resolving subclass for Build") unless $model;
                                            my $seq_platform = $model->sequencing_platform;
                                            Carp::croak("Can't subclass Build: Genome::Model id $model_id has no sequencing_platform") unless $seq_platform;
                                            return return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($seq_platform);
                                         },
                          },
        gold_snp_path => {
            # this should be updated to have an underlying merged microarray model, which could update, and result in a new build
            via => 'model',
        }, 
    ],
};

sub start {
    my $self = shift;
    unless (defined($self->model->reference_sequence_build)) {
        my $msg = 'The model you are trying to build does not have reference_sequence_build set.  Please redefine the model or set this value manually.';
        $self->error_message($msg);
        croak $msg;
    }
    return $self->SUPER::start(@_);
}

sub accumulated_alignments_directory {
    my $self = shift;
    return $self->data_directory . '/alignments';
}

sub accumulated_alignments_disk_allocation {
    my $self = shift;

    my $dedup_event = Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries->get(model_id=>$self->model->id,
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

sub _X_resolve_subclass_name { # only temporary, subclass will soon be stored
    my $class = shift;
    return __PACKAGE__->_resolve_subclass_name_by_sequencing_platform(@_);
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

#This directory is used by both cDNA and now Capture models as well
sub reference_coverage_directory {
    my $self = shift;
    return $self->data_directory .'/reference_coverage';
}

####BEGIN REGION OF INTEREST SECTION####

sub alignment_summary_file {
    my ($self,$wingspan) = @_;
    unless (defined($wingspan)) {
        die('Must provide wingspan_value to method alignment_summary_file in '. __PACKAGE__);
    }
    my @as_files = glob($self->reference_coverage_directory .'/*wingspan_'. $wingspan .'-alignment_summary.tsv');
    unless (@as_files) {
        return;
    }
    unless (scalar(@as_files) == 1) {
        die("Found multiple stats files:\n". join("\n",@as_files));
    }
    return $as_files[0];
}

sub alignment_summary_hash_ref {
    my ($self,$wingspan) = @_;

    unless ($self->{_alignment_summary_hash_ref}) {
        my $wingspan_array_ref = $self->wingspan_values_array_ref;
        my %alignment_summary;
        for my $wingspan( @{$wingspan_array_ref}) {
            my $as_file = $self->alignment_summary_file($wingspan);
            my $reader = Genome::Utility::IO::SeparatedValueReader->create(
                separator => "\t",
                input => $as_file,
            );
            unless ($reader) {
                $self->error_message('Can not create SeparatedValueReader for input file '. $as_file);
                return;
            }
            my $data = $reader->next;
            $reader->input->close;
            
            # Calculate percentages
            
            # percent aligned
            $data->{percent_aligned} = sprintf("%.02f",(($data->{total_aligned_bp} / $data->{total_bp}) * 100));
            
            # duplication rate
            $data->{percent_duplicates} = sprintf("%.03f",(($data->{total_duplicate_bp} / $data->{total_aligned_bp}) * 100));
            
            # on-target alignment
            $data->{percent_target_aligned} = sprintf("%.02f",(($data->{total_target_aligned_bp} / $data->{total_aligned_bp}) * 100));
            
            # on-target duplicates
            $data->{percent_target_duplicates} = sprintf("%.02f",(($data->{duplicate_target_aligned_bp} / $data->{total_target_aligned_bp}) * 100));
            
            # off-target alignment
            $data->{percent_off_target_aligned} = sprintf("%.02f",(($data->{total_off_target_aligned_bp} / $data->{total_aligned_bp}) * 100));
            
            # off-target duplicates
            $data->{percent_off_target_duplicates} = sprintf("%.02f",(($data->{duplicate_off_target_aligned_bp} / $data->{total_off_target_aligned_bp}) * 100));
            
            for my $key (keys %$data) {
                my $metric_key = join('_', 'wingspan', $wingspan, $key);
                $self->set_metric($metric_key, $data->{$key});
            }
            
            $alignment_summary{$wingspan} = $data;
        }
        $self->{_alignment_summary_hash_ref} = \%alignment_summary;
    }
    return $self->{_alignment_summary_hash_ref};
}

sub coverage_stats_directory_path {
    my ($self,$wingspan) = @_;
    return $self->reference_coverage_directory .'/wingspan_'. $wingspan;
}

sub stats_file {
    my $self = shift;
    my $wingspan = shift;
    unless (defined($wingspan)) {
        die('Must provide wingspan_value to method coverage_stats_file in '. __PACKAGE__);
    }
    my $coverage_stats_directory = $self->coverage_stats_directory_path($wingspan);
    my @stats_files = glob($coverage_stats_directory.'/*STATS.tsv');
    unless (@stats_files) {
        return;
    }
    unless (scalar(@stats_files) == 1) {
        die("Found multiple stats files:\n". join("\n",@stats_files));
    }
    return $stats_files[0];
}


sub coverage_stats_hash_ref {
    my $self = shift;
    unless ($self->{_coverage_stats_hash_ref}) {
        my @headers = qw/name pc_covered length covered_bp uncovered_bp mean_depth stdev_mean_depth median_depth gaps mean_gap_length stdev_gap_length median_gap_length minimum_depth minimum_depth_discarded_bp pc_minimum_depth_discarded_bp/;

        my %stats;
        my $min_depth_array_ref = $self->minimum_depths_array_ref;
        my $wingspan_array_ref = $self->wingspan_values_array_ref;
        for my $wingspan (@{$wingspan_array_ref}) {
            my $stats_file = $self->stats_file($wingspan);
            my $reader = Genome::Utility::IO::SeparatedValueReader->create(
                separator => "\t",
                input => $stats_file,
                #TODO: Add headers to the stats file
                headers => \@headers,
            );
            unless ($reader) {
                $self->error_message('Can not create SeparatedValueReader for file '. $stats_file);
                die $self->error_message;
            }
            while (my $data = $reader->next) {
                push @{$stats{$wingspan}{$data->{name}}}, $data;
            }
            $reader->input->close;
        }
        $self->{_coverage_stats_hash_ref} = \%stats;
    }
    return $self->{_coverage_stats_hash_ref};
}

sub coverage_stats_summary_file {
    my ($self,$wingspan) = @_;
    unless (defined($wingspan)) {
        die('Must provide wingspan_value to method coverage_stats_file in '. __PACKAGE__);
    }
    my @stats_files = glob($self->coverage_stats_directory_path($wingspan) .'/*STATS.txt');
    unless (@stats_files) {
        return;
    }
    unless (scalar(@stats_files) == 1) {
        die("Found multiple stats summary files:\n". join("\n",@stats_files));
    }
    return $stats_files[0];
}

sub coverage_stats_summary_hash_ref {
    my $self = shift;
    unless ($self->{_coverage_stats_summary_hash_ref}) {
        my %stats_summary;
        my $min_depth_array_ref = $self->minimum_depths_array_ref;
        my $wingspan_array_ref = $self->wingspan_values_array_ref;
        for my $wingspan (@{$wingspan_array_ref}) {
            my $stats_summary = $self->coverage_stats_summary_file($wingspan);
            my $reader = Genome::Utility::IO::SeparatedValueReader->create(
                separator => "\t",
                input => $stats_summary,
            );
            unless ($reader) {
                $self->error_message('Can not create SeparatedValueReader for file '. $stats_summary);
                die $self->error_message;
            }
            while (my $data = $reader->next) {
                $stats_summary{$wingspan}{$data->{minimum_depth}} = $data;
                
                # record stats as build metrics
                for my $key (keys %$data) {
                    my $metric_key = join('_', 'wingspan', $wingspan, $data->{'minimum_depth'}, $key);
                    $self->set_metric($metric_key, $data->{$key});
                }
            }
            $reader->input->close;
        }
        $self->{_coverage_stats_summary_hash_ref} = \%stats_summary;
    }
    return $self->{_coverage_stats_summary_hash_ref};
}

sub region_of_interest_set_bed_file {
    my $self = shift;

    my $roi_set = $self->model->region_of_interest_set;
    return unless $roi_set;

    my $bed_file_path = $self->reference_coverage_directory .'/'. $roi_set->id .'.bed';
    unless (-e $bed_file_path) {
        unless ($roi_set->print_bed_file($bed_file_path)) {
            die('Failed to print bed file to path '. $bed_file_path);
        }
    }
    return $bed_file_path;
}

sub _resolve_coverage_stats_params {
    my $self = shift;
    my $pp = $self->processing_profile;
    my $coverage_stats_params = $pp->coverage_stats_params;
    my ($minimum_depths,$wingspan_values,$base_quality_filter,$mapping_quality_filter) = split(':',$coverage_stats_params);
    if (defined($minimum_depths) && defined($wingspan_values)) {
        $self->{_minimum_depths} = $minimum_depths;
        $self->{_wingspan_values} = $wingspan_values;
        if (defined($base_quality_filter) && ($base_quality_filter ne '')) {
            $self->{_minimum_base_quality} = $base_quality_filter;
        }
        if (defined($mapping_quality_filter) && ($mapping_quality_filter ne '')) {
            $self->{_minimum_mapping_quality} = $mapping_quality_filter;
        }
    } else {
        die('minimum_depth and wingspan_values are required values.  Failed to parse coverage_stats_params: '. $coverage_stats_params);
    }
    return 1;
}

sub minimum_depths {
    my $self = shift;
    unless ($self->{_minimum_depths}) {
        $self->_resolve_coverage_stats_params;
    }
    return $self->{_minimum_depths};
}

sub minimum_depths_array_ref {
    my $self = shift;
    my $minimum_depths = $self->minimum_depths;
    return unless $minimum_depths;
    my @min_depths = split(',',$minimum_depths);
    return \@min_depths;
}

sub wingspan_values {
    my $self = shift;
    unless ($self->{_wingspan_values}) {
        $self->_resolve_coverage_stats_params;
    }
    return $self->{_wingspan_values};
}

sub wingspan_values_array_ref {
    my $self = shift;
    my $wingspan_values = $self->wingspan_values;
    return unless defined($wingspan_values);
    my @wingspans = split(',',$wingspan_values);
    return \@wingspans;
}

sub minimum_base_quality {
    my $self = shift;
    unless ($self->{_minimum_base_quality}) {
        $self->_resolve_coverage_stats_params;
    }
    return $self->{_minimum_base_quality};
}

sub minimum_mapping_quality {
    my $self = shift;
    unless ($self->{_minimum_mapping_quality}) {
        $self->_resolve_coverage_stats_params;
    }
    return $self->{_minimum_mapping_quality};
}

####END REGION OF INTEREST SECTION####

1;

