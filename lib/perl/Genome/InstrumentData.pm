package Genome::InstrumentData;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData {
    is => 'Genome::Notable',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        id => { is => 'Text' },
    ],
    has => [
        seq_id => { calculate_from => [ 'id' ], calculate => q{ return $id }, },
        subclass_name => { is => 'Text' },
        sequencing_platform => {
            calculate_from => 'subclass_name',
            calculate => q{
                my ($platform) = $subclass_name =~ /::(\w+)$/;
                return lc $platform;
            },
        },
        library_id => { is => 'Number' },
        library => { is => 'Genome::Library', id_by => 'library_id' },
        library_name => { via => 'library', to => 'name' },
        sample_id => { is => 'Number', via => 'library' },
        sample => { is => 'Genome::Sample', id_by => 'sample_id' },
        sample_name => { via => 'sample', to => 'name' },
    ],
    has_optional => [
        run_name => { is => 'Text' },
        subset_name => { is => 'Text' },
        full_name => { 
            calculate_from => ['run_name','subset_name'], 
            calculate => q|"$run_name/$subset_name"|, 
        },        
        full_path => {
            is => 'Text',
            via => 'attributes',
            to => 'attribute_value',
            is_mutable => 1,
            where => [ attribute_label => 'full_path' ],
        },
        sample_source_id => { via => 'sample', to => 'id' },
        sample_source => { via => 'sample', to => 'source' },
        sample_source_name => { via => 'sample_source', to => 'name' },
        taxon => { is => 'Genome::Taxon', via => 'sample' },
        species_name => { via => 'taxon' },
    ],
    has_many_optional => [
        attributes => {
            is => 'Genome::InstrumentDataAttribute',
            reverse_as => 'instrument_data',
        },
        events => { 
            is => 'Genome::Model::Event', 
            reverse_id_by => "instrument_data"
        },
        allocations => { 
            is => 'Genome::Disk::Allocation',
            calculate_from => ['subclass_name', 'id'],
            calculate => q{ return Genome::Disk::Alocation->get(owner_class_name => $subclass_name, owner_id => $id); },
        },
    ],
    table_name => 'INSTRUMENT_DATA',
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'Contains information common to all types of instrument data',
};

# TODO Need to also find and abandon any builds that used this instrument data, remove instrument
# data assignments, etc
sub delete {
    my $self = shift;

    for my $attr ( $self->attributes ) {
        $attr->delete;
    }
    $self->SUPER::delete;

    return $self;
}

sub create {
    my $class = shift;
    my %params = @_;

    # Attempting to create attributes with an undef value causes problems
    for my $name (sort keys %params) {
        delete $params{$name} unless exists $params{$name} and defined $params{$name};
    }

    my $self = $class->SUPER::create(%params);
    Carp::confess "Could not create new instrument data objects with params " . Data::Dumper::Dumper(\%params) unless $self;
    return $self;
}

sub calculate_alignment_estimated_kb_usage {
    my $self = shift;
    Carp::confess "calculate_alignment_estimated_kb_usage not overridden in instrument data subclass " . $self->class;
}

sub sample_type {
    my $self = shift;
    my $sample_extraction_type = $self->sample->extraction_type;
    return unless defined $sample_extraction_type;
    
    if ($sample_extraction_type eq 'genomic_dna' or $sample_extraction_type eq 'pooled dna') {
        return 'dna';
    }
    elsif ($sample_extraction_type eq 'rna') {
        return 'rna';
    }
    return;
}

sub create_mock {
    my $class = shift;
    return $class->SUPER::create_mock(subclass_name => 'Genome::InstrumentData', @_);
}

sub run_identifier  {
    die "run_identifier not defined in instrument data subclass.  please define this. this method should " . 
         "provide a unique identifier for the experiment/run (eg flow_cell_id, ptp barcode, etc).";
}

sub dump_fastqs_from_bam {
    my $self = shift;
    my %p = @_;

    die "cannot call bam path" if (!$self->can('bam_path'));
    
    unless (-e $self->bam_path) {
	$self->error_message("Attempted to dump a bam but the path does not exist:" . $self->bam_path);
	die $self->error_message;
    }
    
    my $directory = delete $p{directory};
    $directory ||= Genome::Sys->create_temp_directory('unpacked_bam');

    my $subset = (defined $self->subset_name ? $self->subset_name : 0);

    my %read_group_params;

    if (defined $p{read_group_id}) {
        $read_group_params{read_group_id} = delete $p{read_group_id};
        $self->status_message("Using read group id " . $read_group_params{read_group_id});
    } 

    my $fwd_file = sprintf("%s/s_%s_1_sequence.txt", $directory, $subset);
    my $rev_file = sprintf("%s/s_%s_2_sequence.txt", $directory, $subset);
    my $fragment_file = sprintf("%s/s_%s_sequence.txt", $directory, $subset);
    my $cmd = Genome::Model::Tools::Picard::SamToFastq->create(input=>$self->bam_path, fastq=>$fwd_file, fastq2=>$rev_file, fragment_fastq=>$fragment_file, no_orphans=>1, %read_group_params);
    unless ($cmd->execute()) {
        die $cmd->error_message;
    }

    if ((-s $fwd_file && !-s $rev_file) ||
        (!-s $fwd_file && -s $rev_file)) {
        $self->error_message("Fwd & Rev files are lopsided; one has content and the other doesn't. Can't proceed"); 
        die $self->error_message;
    }

    my @files;
    if (-s $fwd_file && -s $rev_file) { 
        push @files, ($fwd_file, $rev_file);
    }
    if (-s $fragment_file) {
        push @files, $fragment_file;
    }
   
    return @files; 
}

sub lane_qc_model {
    my $self = shift;
    my $instrument_data_id = $self->id;

    my @inputs = Genome::Model::Input->get(value_id => $instrument_data_id);
    my @inputs_models = map { $_->model } @inputs;
    my ($qc_model) = grep { $_->processing_profile_name eq 'february 2011 illumina lane qc' } @inputs_models;

    return $qc_model;
}

sub lane_qc_build {
    my $self = shift;
    my $qc_model = $self->lane_qc_model;
    if ($qc_model) {
        return $qc_model->last_succeeded_build;
    }
    else {
        return;
    }
}

sub lane_qc_dir {
    my $self = shift;
    my $qc_build = $self->lane_qc_build;
    return unless ($qc_build);
    my $qc_dir = $qc_build->data_directory . "/qc";
    if (-d $qc_dir) {
        return $qc_dir;
    }
    else {
        return;
    }
}

1;
