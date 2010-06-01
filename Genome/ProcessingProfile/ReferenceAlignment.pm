package Genome::ProcessingProfile::ReferenceAlignment;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ReferenceAlignment {
    is => 'Genome::ProcessingProfile::Staged',
    sub_classification_method_name => '_resolve_subclass_name',
    has_param => [
        sequencing_platform => {
            doc => 'The sequencing platform from whence the model data was generated',
            valid_values => ['454', 'solexa', '3730'],
        },
        dna_type => {
            doc => 'the type of dna used in the reads for this model',
            valid_values => ['genomic dna', 'cdna']
        },
        snp_detector_name => {
            doc => 'Name of the snp detector',
            is_optional => 1,
        },
        snp_detector_version => {
            doc => 'version of the snp detector',
            is_optional => 1,
        },
        snp_detector_params => {
            doc => 'command line args used for the snp detector',  
            is_optional => 1,
        },
        indel_detector_name => {
            doc => 'Name of the indel detector',
            is_optional => 1,
        },
        indel_detector_version => {
            doc => 'version of the indel detector',
            is_optional => 1,
        },
        indel_detector_params => {
            doc => 'command line args used for the indel detector',  
            is_optional => 1,
        },
        genotyper_name => {
            doc => 'name of the genotyper for this model... deprecated',
            is_optional => 1,
        },
        genotyper_version => {
            doc => 'version of the genotyper for this model... deprecated',
            is_optional => 1,
        },
        genotyper_params => {
            doc => 'command line args used for the genotyper... deprecated',
            is_optional => 1,
        },
        indel_finder_name => {
            doc => 'name of the indel finder for this model... deprecated',
            is_optional => 1,
        },
        indel_finder_version => {
            doc => 'version of the indel finder for this model... deprecated',
            is_optional => 1,
        },
        indel_finder_params => {
            doc => 'command line args for the indel finder... deprecated',
            is_optional => 1,
        },
        variant_filter => {
            doc => 'variant filter type: VarFilter or SnpFilter... deprecated',
            is_optional => 1,
        },
        multi_read_fragment_strategy => {
            doc => '',
            is_optional => 1,
        },
        merge_software => {
            doc => 'picard or samtools for merging',
            is_optional => 1,
        },
        picard_version => {
            doc => 'picard version for MarkDuplicates, MergeSamfiles, CreateSequenceDictionary...',
            is_optional => 1,
        },
        samtools_version => {
            doc => 'samtools version for SamToBam, samtools merge, etc...',
            is_optional => 1,
        },
        rmdup_name => {
            doc => 'rmdup tool used for this model',
            is_optional => 1,
                          },
        rmdup_version => {
            doc => 'rmdup tool version used for this model',
            is_optional => 1,
        },
        read_aligner_name => {
            doc => 'alignment algorithm/software used for this model',
        },
        read_aligner_version => {
            doc => 'the aligner version used for this model',
            is_optional => 1,
        },
        read_aligner_params => {
            doc => 'command line args for the aligner',
            is_optional => 1,
        },
        force_fragment => {
            is => 'Integer',
            #This doesn't seem to work yet because of the create code, can't the valid values logic be removed from create???
            default_value => '0',
            #valid_values => ['0', '1'],
            doc => 'force all alignments as fragment reads',
            is_optional => 1,
        },
        read_trimmer_name => {
            doc => 'trimmer algorithm/software used for this model',
            is_optional => 1,
        },
        read_trimmer_version => {
            doc => 'the trimmer version used for this model',
            is_optional => 1,
        },
        read_trimmer_params => {
            doc => 'command line args for the trimmer',
            is_optional => 1,
        },
        read_calibrator_name => {
            doc => '',
            is_optional => 1,
        },
        read_calibrator_params => {
            doc => '',
            is_optional => 1,
        },
        coverage_stats_params => {
            doc => 'parameters necessary for generating reference coverage in the form of two comma delimited lists split by a colon like 1,5,10,15,20:0,200,500',
            is_optional => 1,
        },
        prior_ref_seq => {
            doc => '',
            is_optional => 1,
        },
        reference_sequence_name => {
            doc => 'identifies the reference sequence used in the model(required if no prior_ref_seq)',
            is_optional => 1,
        },
        capture_set_name => {
            doc => 'The name of the capture set to evaluate coverage and limit variant calls to within the defined target regions',
            is_optional => 1,
            is_deprecated => 1,
        },
        align_dist_threshold => {
            doc => '',
            is_optional => 1,
        },
        annotation_reference_transcripts => {
            doc => 'The reference transcript set used for variant annotation',
            is_optional => 1,
        },
    ],
};

# get alignments (generic name)
sub results_for_instrument_data_assignment {
    my $self = shift;
    my $assignment = shift;
    my $build = shift;
    #return if $build and $build->id < $assignment->first_build_id;
    return $self->_fetch_alignment_sets($assignment,'get');
}

# create alignments (called by Genome::Model::Event::Build::ReferenceAlignment::AlignReads for now...
sub generate_results_for_instrument_data_assignment {
    my $self = shift;
    my $assignment = shift;
    my $build = shift;
    #return if $build and $build->id < $assignment->first_build_id;
    return $self->_fetch_alignment_sets($assignment,'get_or_create');
}

sub _fetch_alignment_sets {
    my $self = shift;
    my $assignment = shift;
    my $mode = shift;

    my $model = $assignment->model;

    my @param_sets = $self->params_for_alignment($assignment);
    unless (@param_sets) {
        $self->error_message('Could not get alignment parameters for this instrument data assignment');
        return;
    }
    my @alignments;    
    for (@param_sets)  {
        $DB::single = 1;
        my $alignment = Genome::InstrumentData::AlignmentResult->$mode(%$_);
        unless ($alignment) {
             #$self->error_message("Failed to $mode an alignment object");
             return;
         }
        push @alignments, $alignment;
    }
    return @alignments;
}

sub params_for_alignment {
    my $self = shift;
    my $assignment = shift;

    my $model = $assignment->model;
    my $reference_sequence_name = $model->reference_sequence_name;

    unless ($self->type_name eq 'reference alignment') {
        $self->error_message('Can not create an alignment object for model type '. $self->type_name);
        return;
    }

    my %params = (
                    instrument_data_id => $assignment->instrument_data_id || undef,
                    aligner_name => $self->read_aligner_name || undef,
                    reference_name => $reference_sequence_name || undef,
                    aligner_version => $self->read_aligner_version || undef,
                    aligner_params => $self->read_aligner_params || undef,
                    force_fragment => $self->force_fragment || undef,
                    trimmer_name => $self->read_trimmer_name || undef,
                    trimmer_version => $self->read_trimmer_version || undef,
                    trimmer_params => $self->read_trimmer_params || undef,
                    picard_version => $self->picard_version || undef,
                    samtools_version => $self->samtools_version || undef,
                    filter_name => $assignment->filter_desc || undef
                );

    #print Data::Dumper::Dumper(\%params);

    my @param_set = (\%params);
    return @param_set;
}


# TODO: remove
sub prior {
    my $self = shift;
    warn("For now prior has been replaced with the actual column name prior_ref_seq");
    if (@_) {
        die("Method prior() is read-only since it's deprecated");
    }
    return $self->prior_ref_seq();
}

# TODO: remove
sub filter_ruleset_name {
    #TODO: move into the db so it's not constant
    'basic'
}

# TODO: remove
sub filter_ruleset_params {
    ''
}


#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;

    my $sequencing_platform;
    if ( ref($_[0]) and $_[0]->can('params') ) {
        my @params = $_[0]->params;
        my @seq_plat_param = grep { $_->name eq 'sequencing_platform' } @params;
        if (scalar(@seq_plat_param) == 1) {
            $sequencing_platform = $seq_plat_param[0]->value;
        }

    }  else {
        my %params = @_;
        $sequencing_platform = $params{sequencing_platform};
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
	
    my $class_name = join('::', 'Genome::ProcessingProfile::ReferenceAlignment' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::ProcessingProfile::ReferenceAlignment::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));
    
    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

1;
