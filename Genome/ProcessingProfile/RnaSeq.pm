package Genome::ProcessingProfile::RnaSeq;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::RnaSeq {
    is => 'Genome::ProcessingProfile::Staged',
    sub_classification_method_name => '_resolve_subclass_name',
    has_param => [
        sequencing_platform => {
            doc => 'The sequencing platform from whence the model data was generated',
            valid_values => ['454', 'solexa'],
        },
        dna_type => {
            doc => 'the type of dna used in the reads for this model',
            valid_values => ['cdna']
        },
        merge_software => {
            doc => 'picard or samtools for merging',
            valid_values => ['picard','samtools'],
            is_optional => 1,
        },
        merge_version => {
            doc => 'picard version for MarkDuplicates, MergeSamfiles, CreateSequenceDictionary...',
            is_optional => 1,
        },
        dedup_name => {
            doc => 'dedup tool used for this model',
            is_optional => 1,
        },
        dedup_version => {
            doc => 'dedup tool version used for this model',
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
        expression_name => {
            doc => 'algorithm used to detect expression levels',
            is_optional => 1,
        },
        expression_version => {
            doc => 'the expression detection version used for this model',
            is_optional => 1,
        },
        expression_params => {
            doc => 'the expression detection params used for this model',
            is_optional => 1,
        },
        force_fragment => {
            is => 'Integer',
            #This doesn't seem to work yet because of the create code, can't the valid values logic be removed from create???
            #default_value => '0',
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
        reference_sequence_name => {
            doc => 'identifies the reference sequence used in the model(required if no prior_ref_seq)',
            is_optional => 1,
        },
        annotation_reference_transcripts => {
            doc => 'The reference transcript set used for splice junction annotation',
            is_optional => 1,
        },
    ],
};

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
	
    my $class_name = join('::', 'Genome::ProcessingProfile::RnaSeq' , $subclass);
    return $class_name;
}

sub _resolve_sequencing_platform_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::ProcessingProfile::RnaSeq::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));
    
    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

1;
