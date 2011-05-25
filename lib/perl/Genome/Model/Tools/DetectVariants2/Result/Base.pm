package Genome::Model::Tools::DetectVariants2::Result::Base;

use strict;
use warnings;

use Sys::Hostname;
use File::Path 'rmtree';

use Genome;

class Genome::Model::Tools::DetectVariants2::Result::Base {
    is => ['Genome::SoftwareResult'],
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    has => [
        reference_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            id_by => 'reference_build_id',
        },
        region_of_interest => {
            is => 'Genome::FeatureList',
            is_optional => 1,
            id_by => 'region_of_interest_id',
        },
        _disk_allocation => {
            is => 'Genome::Disk::Allocation',
            is_optional => 1,
            is_many => 1,
            reverse_as => 'owner'
        },
    ],
    has_param => [
        detector_name => {
            is => 'Text',
            doc => 'The name of the detector to use',
        },
        detector_params => {
            is => 'Text',
            is_optional => 1,
            doc => 'Additional parameters to pass to the detector',
        },
        detector_version => {
            is => 'Text',
            is_optional => 1,
            doc => 'Version of the detector to use',
        },
        chromosome_list => {
            is => 'Text',
            is_optional => 1,
            doc => 'The chromosome(s) on which the detection was run',
        },
    ],
    has_input => [
        aligned_reads => {
            is => 'Text',
            doc => 'The path to the aligned reads file',
        },
        control_aligned_reads => {
            is => 'Text',
            doc => 'The path to the control aligned reads file',
            is_optional => 1,
        },
        reference_build_id => {
            is => 'Number',
            doc => 'the reference to use by id',
        },
        region_of_interest_id => {
            is => 'Text',
            doc => 'The feature-list representing the region of interest (if present, only variants in the set will be reported)',
            is_optional => 1,
        },
    ],
    has_transient_optional => [
        _instance => {
            is => 'Genome::Model::Tools::DetectVariants2::Base',
            doc => 'The instance of the entity that is creating this result',
        }
    ],
    doc => 'This class represents the result of a detect-variants operation.',
};

sub create {
    my $class = shift;

    #This will do some locking and the like for us.
    my $self = $class->SUPER::create(@_);
    return unless ($self);

    eval {
        $self->_prepare_output_directory;

        my $instance = $self->_instance;
        my $instance_output = $instance->output_directory;

        # if it's not a symlink then it was created before these became software results
        # so we should archive the directory and generate software result/symlink
        if (-e $instance_output) {
            if (not -l $instance_output and -d $instance_output) {
                my ($parent_dir, $sub_dir) = $instance_output =~ /(.*)\/(.*)/;
                die $self->error_message("Unable to determine parent directory from $instance_output.") unless $parent_dir;
                die $self->error_message("Unable to determine sub-directory from $instance_output.") unless $sub_dir;
                die $self->error_message("Parse error when determining parent directory and sub-directory from $instance_output.") unless ($instance_output eq "$parent_dir/$sub_dir");

                my $archive_name = "old_$sub_dir.tar.gz";
                die $self->error_message("Archive already exists, $parent_dir/$archive_name.") if (-e "$parent_dir/$archive_name");

                $self->status_message('Archiving old non-software-result ' . $instance_output . " to $archive_name.");
                system("cd $parent_dir && tar -zcvf $archive_name $sub_dir && rm -rf $sub_dir");
            }
            else {
                die $self->error_message('Instance output directory (' . $instance_output . ') already exists!');
            }
        }

        Genome::Sys->create_symlink($self->output_dir, $instance_output);

        $instance->_generate_result;
        $self->_set_result_file_permissions;
    };
    if($@) {
        my $error = $@;
        $self->_cleanup;
        die $error;
    }

    $self->status_message("Resizing the disk allocation...");
    if ($self->_disk_allocation) {
        unless ($self->_disk_allocation->reallocate) {
            $self->warning_message("Failed to reallocate disk allocation: " . $self->_disk_allocation->id);
        }
    }

    return $self;
}

sub _gather_params_for_get_or_create {
    my $class = shift;

    my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, @_);

    my %params = $bx->params_list;
    my %is_input;
    my %is_param;
    my $class_object = $class->__meta__;
    for my $key ($class->property_names) {
        my $meta = $class_object->property_meta_for_name($key);
        if ($meta->{is_input} && exists $params{$key}) {
            $is_input{$key} = $params{$key};
        } elsif ($meta->{is_param} && exists $params{$key}) {
            $is_param{$key} = $params{$key};
        }
    }

    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_input);
    my $params_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, %is_param);

    my $subclass_name = (exists $is_param{filter_name} ? 'Genome::Model::Tools::DetectVariants2::Result::Filter' : 'Genome::Model::Tools::DetectVariants2::Result');

    my %software_result_params = (#software_version=>$params_bx->value_for('aligner_version'),
                                  params_id=>$params_bx->id,
                                  inputs_id=>$inputs_bx->id,
                                  subclass_name=>$subclass_name);

    return {
        software_result_params => \%software_result_params,
        subclass => $class,
        inputs=>\%is_input,
        params=>\%is_param,
        _instance => (exists $params{instance} ? $params{instance} : undef),
    };
}

sub estimated_kb_usage {
    my $self = shift;

    return 10_000_000; #TODO be more dynamic about this
}

sub _resolve_subdirectory {
    my $self = shift;

    my $hostname = hostname;
    my $user = $ENV{'USER'};
    my $base_dir = sprintf("detect-variants--%s-%s-%s-%s", $hostname, $user, $$, $self->id);
    # TODO: the first subdir is actually specified by the disk management system.
    my $directory = join('/', 'build_merged_alignments', $base_dir);
    return $directory;
}

sub _prepare_output_directory {
    my $self = shift;

    return $self->output_dir if $self->output_dir;

    my $subdir = $self->_resolve_subdirectory;
    unless ($subdir) {
        $self->error_message("failed to resolve subdirectory for instrument data.  cannot proceed.");
        die $self->error_message;
    }

    my $allocation = $self->_disk_allocation;

    unless($allocation) {
        my %allocation_parameters = (
            disk_group_name => 'info_genome_models',
            allocation_path => $subdir,
            owner_class_name => $self->class,
            owner_id => $self->id,
            kilobytes_requested => $self->estimated_kb_usage,
        );

        $allocation = Genome::Disk::Allocation->allocate(%allocation_parameters);
    }

    my $output_dir = $allocation->absolute_path;
    unless (-d $output_dir) {
        $self->error_message("Allocation path $output_dir doesn't exist!");
        die $self->error_message;
    }

    $self->output_dir($output_dir);

    return $output_dir;
}

sub _cleanup {
    my $self = shift;

    my $instance = $self->_instance;
    if($instance) {
        my $instance_output = $instance->output_directory;
        if(readlink($instance_output) eq $self->output_dir) {
            unlink($instance_output);
        }
    }

    return unless $self->_disk_allocation;

    $self->status_message('Now deleting allocation with owner_id = ' . $self->id);
    my $allocation = $self->_disk_allocation;
    if ($allocation) {
        my $path = $allocation->absolute_path;
        unless (rmtree($path)) {
            $self->error_message("could not rmtree $path");
            return;
       }
       $allocation->deallocate;
    }
}

sub _resolve_subclass_name {
    my $class = shift;

    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $filter_name = $_[0]->params(name => 'filter_name');
        return $filter_name ? 'Genome::Model::Tools::DetectVariants2::Result::Filter' : 'Genome::Model::Tools::DetectVariants2::Result';
    }
    else {
        my $filter_name = $class->get_rule_for_params(@_)->specified_value_for_property_name('filter_name');
        return $filter_name ? 'Genome::Model::Tools::DetectVariants2::Result::Filter' : 'Genome::Model::Tools::DetectVariants2::Result';
    }
    return;
}

sub _set_result_file_permissions {
    my $self = shift;
    my $output_dir = $self->output_dir;

    chmod 02775, $output_dir;
    for my $subdir (grep { -d $_  } glob("$output_dir/*")) {
        chmod 02775, $subdir;
    }

    # Make everything in here read-only
    for my $file (grep { -f $_  } glob("$output_dir/*")) {
        chmod 0444, $file;
    }
}


1;
