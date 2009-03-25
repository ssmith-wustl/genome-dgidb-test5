package Genome::InstrumentData;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require Genome::Utility::FileSystem;

class Genome::InstrumentData {
    id_by => ['id'],
    table_name => <<EOS
    (
        select run_name id,
                sanger.run_name,
                'sanger' sequencing_platform,
                sanger.run_name seq_id,
                'unknown' sample_name,
                1 subset_name,
                'unknown' library_name
        from gsc_run\@oltp sanger

     union all

        select to_char(seq_id) id,
                solexa.run_name,
                'solexa' sequencing_platform,
                to_char(solexa.seq_id) seq_id, 
                solexa.sample_name sample_name,
                solexa.lane subset_name,
                solexa.library_name library_name
        from solexa_lane_summary\@dw solexa
        where run_type in ('Standard','Paired End Read 2')
    
     union all

        select to_char(x454.region_id) id,
                x454.run_name,
                '454' sequencing_platform,
                to_char(x454.region_id) seq_id, 
                nvl(x454.sample_name, x454.incoming_dna_name) sample_name, 
                x454.region_number subset_name,
                x454.library_name library_name
        from run_region_454\@dw x454
        
    ) idata
EOS
    ,
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    has => [
        sequencing_platform => { is => 'VARCHAR2', len => 255 },
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        subset_name         => { is => 'VARCHAR2', len => 32, is_optional => 1, },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        #sample              => { is => 'Genome::Sample', where => [ 'sample_name' => \'sample_name' ] },
        library_name        => { is => 'VARCHAR2', len => 255, is_optional => 1 },
        seq_id => { is => 'VARCHAR2', len => 15, is_optional => 1 },
        events => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => "instrument_data" },
        full_name => { calculate_from => ['run_name','subset_name'], calculate => q|"$run_name/$subset_name"| },        
        name => {
            doc => 'This is a long version of the name which is still used in some places.  Replace with full_name.',
            is => 'String', 
            calculate_from => ['run_name','sample_name'], 
            calculate => q|$run_name. '.' . $sample_name| 
        },
    ],
    has_optional => [
        full_path => {
            via => 'attributes',
            to => 'value', 
            where => [ entity_class_name => 'Genome::InstrumentData', property_name => 'full_path' ],
            is_mutable => 1,
        },
    ],
    has_many_optional => [
        attributes => {
            is => 'Genome::MiscAttribute',
            reverse_id_by => '_instrument_data',
            where => [ entity_class_name => __PACKAGE__ ],
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

#< UR Methods >#
sub delete {
    my $self = shift;

    for my $attr ( $self->attributes ) {
        $attr->delete;
    }
    $self->SUPER::delete;

    return $self;
}

sub _resolve_subclass_name {
	my $class = shift;

	if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
		my $sequencing_platform = $_[0]->sequencing_platform;
		return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
	}
    elsif (my $sequencing_platform = $class->get_rule_for_params(@_)->specified_value_for_property_name('sequencing_platform')) {
        return $class->_resolve_subclass_name_for_sequencing_platform($sequencing_platform);
    }
	else {
		return;
	}
}

sub _resolve_subclass_name_for_sequencing_platform {
    my ($class,$sequencing_platform) = @_;
    my @type_parts = split(' ',$sequencing_platform);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::InstrumentData' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_subclass_name {
    my ($class,$subclass_name) = @_;
    my ($ext) = ($subclass_name =~ /Genome::InstrumentData::(.*)/);
    return unless ($ext);
    my @words = $ext =~ /[a-z]+|[A-Z](?:[A-Z]+|[a-z]*)(?=$|[A-Z])/g;
    my $sequencing_platform = lc(join(" ", @words));
    return $sequencing_platform;
}

#< Paths >#
sub create_data_directory_and_link {
    my $self = shift;

    my $data_path = $self->resolve_full_path;
    Genome::Utility::FileSystem->create_directory($data_path)
        or return;
    
    Genome::Utility::FileSystem->create_symlink($data_path, $self->data_link)
        or return;

    return $data_path;
}

sub _links_base_path {
    return '/gscmnt/839/info/medseq/instrument_data_links/';
}

sub data_link {
    return sprintf('%s/%s', _links_base_path(), $_[0]->id);
}

sub _data_base_path {
    return '/gscmnt/sata363/info/medseq/instrument_data/';
}

sub resolve_full_path{
    my $self = shift;

    return $self->full_path if $self->full_path;

    return $self->full_path( $self->_default_full_path );
}

sub _default_full_path {
    my $self = shift;
    sprintf('%s/%s', $self->_data_base_path, $self->id)
}

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;
    $self->warning_message("Method 'dump_data_to_file_system' not implemented");
    return 1;
}

sub allocations {
    my $self = shift;

    my @allocations = Genome::Disk::Allocation->get(
                                                    owner_class_name => $self->class,
                                                    owner_id => $self->id,
                                                );
    return @allocations;
}

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    return;
}

sub move_alignment_directory_for_aligner_and_refseq {
    my $self = shift;
    my $aligner_name = shift;
    my $reference_sequence_name = shift;
    my $reason = shift;
    unless ($reason && $reason =~ /old|bad/) {
        if ($reason) {
            die('Only two reasons are acceptable for moving alignment data: old or bad');
        }
        die('Must provide reason for moving alignment data: old or bad');
    }

    my $current_allocation = $self->alignment_allocation_for_aligner_and_refseq($aligner_name,$reference_sequence_name,check_only => 1);
    unless ($current_allocation) {
        die('No alignment allocation found for instrumen data '. $self->id .' with aligner '. $aligner_name .' and refseq '. $reference_sequence_name);
    }

    my $allocation_path = $current_allocation->allocation_path .".$reason.$$";
    my $existing_allocation = Genome::Disk::Allocation->get(
                                                            allocation_path => $allocation_path,
                                                            owner_class_name => $self->class,
                                                            owner_id => $self->id,
                                                        );
    if ($existing_allocation) {
        die('Disk allocation '. $existing_allocation->allocator_id .' already exists for path '. $allocation_path);
    }
    my $allocation_cmd = Genome::Disk::Allocation::Command::Allocate->create(
                                                                             disk_group_name => 'info_alignments',
                                                                             allocation_path => $allocation_path,
                                                                             kilobytes_requested => $current_allocation->kilobytes_requested,
                                                                             owner_class_name => $self->class,
                                                                             owner_id => $self->id,
                                                                         );
    unless ($allocation_cmd) {
        die('Failed to create command to allocate disk space for '. $allocation_path);
    }
    unless ($allocation_cmd->execute) {
        die('Failed to execute command to allocate disk space for '. $allocation_path);
    }
    my $new_allocation = $allocation_cmd->disk_allocation;
    unless ($new_allocation) {
        $self->error_message('Failed to get disk allocation for '. $allocation_cmd->allocator_id);
        die $self->error_message;
    }
    unless (rename($existing_allocation->absolute_path,$new_allocation->absolute_path)) {
        die('Failed to move '. $reason .' directory '. $existing_allocation->absolute_path .' to '. $new_allocation->absolute_path .":  $!");
    }
    return 1;
}

sub alignment_allocation_for_aligner_and_refseq {
    my $self = shift;
    my $aligner_name = shift;
    my $reference_sequence_name = shift;
    my %params = @_;

    my $allocation_path = $self->resolve_alignment_path_for_aligner_and_refseq($aligner_name,$reference_sequence_name);

    my @allocations = $self->allocations;
    my @matches = grep { $_->allocation_path eq $allocation_path } @allocations;
    unless (@matches) {
        my $kb_requested = $self->calculate_alignment_estimated_kb_usage;
        if ($kb_requested && !($params{check_only}) ) {
            my $disk_allocation = Genome::Disk::Allocation->create(
                                                                  disk_group_name => 'info_alignments',
                                                                  allocation_path => $allocation_path,
                                                                  kilobytes_requested => $kb_requested,
                                                                  owner_class_name => $self->class,
                                                                  owner_id => $self->id,
                                                              );
            unless ($disk_allocation) {
                $self->error_message('Failed to get disk allocation');
                die $self->error_message;
            }
            push @matches, $disk_allocation;
        }
    }
    if (scalar(@matches) > 1) {
        die('More than one allocation found for allocation_path: '. $allocation_path);
    }
    return $matches[0];
}

sub resolve_alignment_path_for_aligner_and_refseq {
    my $self = shift;
    my $aligner_name = shift;
    my $reference_sequence_name = shift;

    unless ($aligner_name) {
        die ('Must provide aligner name to resolve the alignment path for aligner and refseq');
    }
    unless ($reference_sequence_name ) {
        die ('Must provide reference sequence name to resolve the alignment path for aligner and refseq');
    }
    unless ($self->id) {
        die ($self->class .' is missing the id!');
    }
    unless ($self->subset_name) {
        die ($self->class .'('. $self->id .') is missing the subset_name or lane!');
    }
    if ($self->is_external) {
        return sprintf('alignment_data/%s/%s/%s/%s_%s',
                       $aligner_name,
                       $reference_sequence_name,
                       $self->id,
                       $self->subset_name,
                       $self->id
                   );
    } else {
        unless ($self->run_name) {
            die ($self->class .'('. $self->id .') is missing the run_name!');
        }
        return sprintf('alignment_data/%s/%s/%s/%s_%s',
                       $aligner_name,
                       $reference_sequence_name,
                       $self->run_name,
                       $self->subset_name,
                       $self->id
                   );
    }
}

sub alignment_directory_for_aligner_and_refseq {
    my $self = shift;
    my $aligner_name = shift;
    my $reference_sequence_name = shift;
    my %params = @_;

    my $allocation = $self->alignment_allocation_for_aligner_and_refseq($aligner_name,$reference_sequence_name,%params);
    if ($allocation) {
        return $allocation->absolute_path;
    } else {
        my $allocation_path = $self->resolve_alignment_path_for_aligner_and_refseq($aligner_name,$reference_sequence_name);
        $allocation_path =~ s/^alignment_data\///;
        return sprintf('%s/%s',
                       Genome::Config->alignment_links_directory(),
                       $allocation_path,
                   );
    }
}

sub find_or_generate_alignments_dir {
    my $self = shift;
    my %params = @_;

    my $aligner_name = delete $params{aligner_name};

    # delegate to the correct module by aligner name
    my $aligner_ext = ucfirst($aligner_name);
    my $cmd = "Genome::InstrumentData::Command::Align::$aligner_ext";
    my $align_cmd = $cmd->create(%params, instrument_data => $self);
    unless ($align_cmd) {
        $self->error_message('Failed to create align command '. $cmd);
        return;
    }
    unless ($align_cmd->execute) {
        $self->error_message('Failed to execute align command '. $align_cmd->command_name);
        return;
    }
    my $aligner_label = $align_cmd->version;
    $aligner_label =~ s/\./_/g;
    $aligner_label = $aligner_name . $aligner_label;

    my $dir = $self->alignment_directory_for_aligner_and_refseq(
                                                                $aligner_label,
                                                                $align_cmd->reference_name,
                                                                %params,
                                                            );
    unless (-d $dir) {
        die "no directory $dir found!"
    }
    return $dir;
}

######
# Needed??
# WHY NOT USE RUN_NAME FROM THE DB????
sub old_name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\/?$/);
    if (!$name) {
	   $name = "run_" . $self->id;
    }
    return $name;
}

1;

#$HeadURL$
#$Id$
