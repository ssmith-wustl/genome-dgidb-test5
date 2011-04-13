
package Genome::Model::ReferenceAlignment;

#:eclark 11/18/2009 Code review.

# I'm not sure that we need to have all these via properties.  Does it really gain us that much code clarity?
# Some of the other properties seem generic enough to be part of Genome::Model, not this subclass.
# The entire set of _calculcute* methods could be refactored away.
# Several deprecated/todo comments scattered in the code below that should either be removed or implemented.
# Most of the methods at the bottom are for reading/writing of a gold_snp_file, this should be implemented as
# part of Genome/Utility/IO

use strict;
use warnings;

use Genome;
use Term::ANSIColor;
use File::Path;
use File::Basename;
use IO::File;
use Sort::Naturally;
use Data::Dumper;

my %DEPENDENT_PROPERTIES = (
    # dbsnp_build and annotation depend on reference_sequence_build
    'reference_sequence_build' => [
        'dbsnp_build',
        'annotation_reference_transcripts',
    ],
);

class Genome::Model::ReferenceAlignment {
    is => 'Genome::Model',
    has => [
        align_dist_threshold         => { via => 'processing_profile'},
        dna_type                     => { via => 'processing_profile'},
        picard_version               => { via => 'processing_profile'},
        samtools_version             => { via => 'processing_profile'},
        merger_name                  => { via => 'processing_profile'},
        merger_version               => { via => 'processing_profile'},
        merger_params                => { via => 'processing_profile'},
        duplication_handler_name     => { via => 'processing_profile'},
        duplication_handler_version  => { via => 'processing_profile'},
        duplication_handler_params   => { via => 'processing_profile'},
        snv_detection_strategy       => { via => 'processing_profile'},
        indel_detection_strategy     => { via => 'processing_profile'},
        sv_detection_strategy        => { via => 'processing_profile'},
        cnv_detection_strategy       => { via => 'processing_profile'},
        snv_detector_name            => { via => 'processing_profile'},
        snv_detector_version         => { via => 'processing_profile'},
        snv_detector_params          => { via => 'processing_profile'},
        indel_detector_name          => { via => 'processing_profile'},
        indel_detector_version       => { via => 'processing_profile'},
        indel_detector_params        => { via => 'processing_profile'},
        transcript_variant_annotator_version => { via => 'processing_profile' },
        transcript_variant_annotator_filter => { via => 'processing_profile' },
        transcript_variant_annotator_accept_reference_IUB_codes => {via => 'processing_profile'},
        multi_read_fragment_strategy => { via => 'processing_profile'},
        prior_ref_seq                => { via => 'processing_profile'},
        read_aligner_name => {
            calculate_from => 'processing_profile',
            calculate => q|
                my $read_aligner_name = $processing_profile->read_aligner_name;
                if ($read_aligner_name =~ /^maq/) {
                    return 'maq';
                }
                return $read_aligner_name;
            |,
        },
        read_aligner_version         => { via => 'processing_profile'},
        read_aligner_params          => { via => 'processing_profile'},
        read_trimmer_name            => { via => 'processing_profile'},
        read_trimmer_version         => { via => 'processing_profile'},
        read_trimmer_params          => { via => 'processing_profile'},
        force_fragment               => { via => 'processing_profile'},
        read_calibrator_name         => { via => 'processing_profile'},
        read_calibrator_params       => { via => 'processing_profile'},
        reference_sequence_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'reference_sequence_build', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence' ],
            is_many => 0,
            is_mutable => 1, # TODO: make this non-optional once backfilling is complete and reference placeholder is deleted
            is_optional => 1,
            doc => 'reference sequence to align against'
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'reference_sequence_build_id',
        },
        dbsnp_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'dbsnp_build', value_class_name => 'Genome::Model::Build::ImportedVariationList' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'dbsnp build to compare against'
        },
        dbsnp_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            id_by => 'dbsnp_build_id',
        },
        dbsnp_model => {
            via => 'dbsnp_build',
            to => 'model',
        },
        genotype_microarray_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'genotype_microarray_build', 'value_class_name' => 'Genome::Model::Build::GenotypeMicroarray', ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'Genotype Microarray build used for QC and Gold SNP Concordance report',
        },
        genotype_microarray_build => {
            is => 'Genome::Model::Build::GenotypeMicroarray',
            id_by => 'genotype_microarray_build_id',
        },
        annotation_reference_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'annotation_reference_build', 'value_class_name' => 'Genome::Model::Build::ImportedAnnotation' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'The reference build used for variant annotation',
        },
        annotation_reference_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            calculate_from => ['annotation_reference_build_id', 'annotation_reference_transcripts'],
            calculate => q|
                if ($annotation_reference_build_id) {
                    my $b = Genome::Model::Build::ImportedAnnotation->get($annotation_reference_build_id);
                    Carp::confess("Failed to find imported annotation build id '$annotation_reference_build_id'") unless $b;
                    return $b;
                }
                my $art = $annotation_reference_transcripts;
                return unless $art;
                my ($model_name, $ver) = split('/', $art);
                Carp::confess("Unable to determine model and build version from annotation transcripts string '$art'") unless $model_name and $ver;
                my $b = Genome::Model::Build::ImportedAnnotation->get(model_name => $model_name, version => $ver);
                Carp::confess("Failed to find annotation build version='$ver' for model_name='$model_name'") unless $b;
                return $b;
            |,
        },
        reference_sequence_name      => { via => 'reference_sequence_build', to => 'name' },
        annotation_reference_name    => { via => 'annotation_reference_build', to => 'name' },
        coverage_stats_params        => { via => 'processing_profile'},
        annotation_reference_transcripts => { via => 'processing_profile'},
        assignment_events => {
            is => 'Genome::Model::Event::Build::ReferenceAlignment::AssignRun',
            is_many => 1,
            reverse_id_by => 'model',
            doc => 'each case of an instrument data being assigned to the model',
        },
        alignment_events => {
            is => 'Genome::Model::Event::Build::ReferenceAlignment::AlignReads',
            is_many => 1,
            reverse_id_by => 'model',
            doc => 'each case of a read set being aligned to the model\'s reference sequence(s), possibly including multiple actual aligner executions',
        },
        #this is to get the SNP statistics...
        filter_variation_events => {
            is => 'Genome::Model::Event::Build::ReferenceAlignment::FilterVariations',
            is_many => 1,
            reverse_id_by => 'model',
            doc => 'each case of variations filtered per chromosome',
        },
        alignment_file_paths => { via => 'alignment_events' },
        has_all_alignment_metrics => { via => 'alignment_events', to => 'has_all_metrics' },
        has_all_filter_variation_metrics => { via => 'filter_variation_events', to => 'has_all_metrics' },
        build_events  => {
            is => 'Genome::Model::Event::Build',
            reverse_id_by => 'model',
            is_many => 1,
            where => [
                parent_event_id => undef,
            ]
        },
        latest_build_event => {
            calculate_from => ['build_event_arrayref'],
            calculate => q|
                my @e = sort { $a->id cmp $b->id } @$build_event_arrayref;
                my $e = $e[-1];
                return $e;
            |,
        },
        running_build_event => {
            calculate_from => ['latest_build_event'],
            calculate => q|
                # TODO: we don't currently have this event complete when child events are done.
                #return if $latest_build_event->event_status('Succeeded');
                return $latest_build_event;
            |,
        },
        filter_ruleset_name   => { via => 'processing_profile' },
        filter_ruleset_params => { via => 'processing_profile' },
        target_region_set_value     => { is_many => 1, is_mutable => 1, is => 'UR::Value', via => 'inputs', to => 'value', where => [ name => 'target_region_set_name'] },
        target_region_set_name      => { via => 'target_region_set_value', to => 'id', },
    ],
    doc => 'A genome model produced by aligning DNA reads to a reference sequence.' 
};

sub create {
    my $class = shift;

    # This is a temporary hack to allow annotation_reference_build (currently calculated) to be
    # passed in as an object. Once the transition to using model inputs for this parameter vs
    # processing profile params, annotation_reference_build can work like reference_sequence_build
    # and this code can go away.
    my @args = @_;
    if (scalar(@_) % 2 == 0) {
        my %args = @args;
        if (defined $args{annotation_reference_build}) {
            $args{annotation_reference_build_id} = (delete $args{annotation_reference_build})->id;
            @args = %args;
        }
    }


    my $self = $class->SUPER::create(@args)
        or return;

    unless ( $self->reference_sequence_build ) {
        $self->error_message("Missing needed reference sequence build during reference alignment model creation.");
        $self->delete;
        return;
    }

    if ($self->read_aligner_name and $self->read_aligner_name eq 'newbler') {
        my $new_mapping = Genome::Model::Tools::454::Newbler::NewMapping->create(
            dir => $self->alignments_directory,
        );
        unless ($self->new_mapping) {
            $self->error_message('Could not setup newMapping for newbler in directory '. $self->alignments_directory);
            return;
        }
        my @fasta_files = grep {$_ !~ /all_sequences/} $self->get_subreference_paths(reference_extension => 'fasta');
        my $set_ref = Genome::Model::Tools::454::Newbler::SetRef->create(
                                                                    dir => $self->alignments_directory,
                                                                    reference_fasta_files => \@fasta_files,
                                                                );
        unless ($set_ref->execute) {
            $self->error_message('Could not set refrence setRef for newbler in directory '. $self->alignments_directory);
            return;
        }
    }
    return $self;
}

sub __errors__ {
    my ($self) = shift;

    my @tags = $self->SUPER::__errors__(@_);

    my $arb = $self->annotation_reference_build;
    my $rsb = $self->reference_sequence_build;
    if ($arb and !$arb->is_compatible_with_reference_sequence_build($rsb)) {
        push @tags, UR::Object::Tag->create(
            type => 'invalid',
            properties => ['reference_sequence_name', 'annotation_reference_transcripts'],
            desc => "reference sequence: " . $rsb->name . " is incompatible with annotation reference transcripts: " . $arb->name,
        );
    }

    my $dbsnp = $self->dbsnp_build;
    if (defined $dbsnp) {
        if (!defined $dbsnp->reference) {
            push @tags, UR::Object::Tag->create(
                type => 'invalid',
                properties => 'dbsnp_build',
                desc => "Supplied dbsnp build " . $dbsnp->__display_name__ . " does not specify a reference sequence");
        }

        if (!$rsb->is_compatible_with($dbsnp->reference)) {
            push @tags, UR::Object::Tag->create(
                type => 'invalid',
                properties => 'dbsnp_build',
                desc => "Supplied dbsnp build " . $dbsnp->__display_name__ . " specifies incompatible reference sequence " .
                $dbsnp->reference->__display_name__);
        }
    }

    return @tags;
}

sub libraries {
    my $self = shift;
    my %libraries = map {$_->library_name => 1} $self->instrument_data;
    my @distinct_libraries = keys %libraries;
    if ($self->name =~ /v0b/) {
        warn "removing any *d libraries from v0b models.  temp hack for AML v0b models.";
        @distinct_libraries = grep { $_ !~ /d$/ } @distinct_libraries;
    }
    return @distinct_libraries;
}

sub _calculate_library_count {
    my $self = shift;
    return scalar($self->libraries);
}

sub complete_build_directory {
    my $self=shift;
    if (defined $self->last_complete_build) {
        return $self->last_complete_build->data_directory;
    }
    else
    {
        return; 
    }
}


sub run_names {
    my $self = shift;
    my %distinct_run_names = map { $_->run_name => 1}  $self->instrument_data;
    my @distinct_run_names = keys %distinct_run_names;
    return @distinct_run_names;
}

sub _calculate_run_count {
    my $self = shift;
    return scalar($self->run_names);
}


sub region_of_interest_set {
    my $self = shift;

    my $name = $self->region_of_interest_set_name;
    return unless $name;
    my $roi_set = Genome::FeatureList->get(name => $name);
    unless ($roi_set) {
        die('Failed to find feature-list with name: '. $name);
    }
    return $roi_set;
}

sub accumulated_alignments_directory {
    my $self = shift;
    return $self->complete_build_directory . '/alignments';
}

sub is_eliminate_all_duplicates {
    my $self = shift;

    if ($self->multi_read_fragment_strategy and
        $self->multi_read_fragment_strategy eq 'EliminateAllDuplicates') {
        1;
    } else {
        0;
    }
}

sub gold_snp_build {
    my $self = shift;

    my $subject_name = $self->subject_name;
    if ($self->subject_type eq 'library_name') {
        my $subject = $self->subject;
        $subject_name = $self->sample_name;
    }

    my @genotype_models = Genome::Model::GenotypeMicroarray->get(
        subject_id => $self->subject_id,
        processing_profile_name => 'infinium wugc', # only grab internal genotype
    );
    @genotype_models = grep {
        my $gm_rsb = $_->reference_sequence_build;
        $gm_rsb->is_compatible_with($self->reference_sequence_build);
    } @genotype_models;
    unless (@genotype_models) {
        $self->error_message("No genotype microarray model defined for $subject_name");
        return;
    }

    my $build;
    for my $gold_model (reverse @genotype_models) {
        $build = $gold_model->last_succeeded_build;
        last if $build;
    }

    unless ($build) {
        $self->error_message("Found no successful genotype microarray build for $subject_name");
        return;
    }

    return $build;
}

sub gold_snp_path {
    my $self = shift;

    my $geno_micro_build; 
    if ($self->genotype_microarray_build_id) {
        $geno_micro_build = $self->genotype_microarray_build;
    }
    else {
        $geno_micro_build = $self->gold_snp_build;
    }

    $self->status_message("model::gold_snp_path: Using Genotype Microarray build " . $geno_micro_build->id . ".") if $geno_micro_build;
    return ($geno_micro_build ? $geno_micro_build->formatted_genotype_file_path : undef);
}


sub build_subclass_name {
    return 'reference alignment';
}

sub inputs_necessary_for_copy {
    my $self = shift;

    my %exclude = (
        'reference_sequence_build' => 1,
        'annotation_reference_build' => 1,
        'dbsnp_build' => 1,
    );
    my @inputs = grep { !exists $exclude{$_->name} } $self->SUPER::inputs_necessary_for_copy;
    return @inputs;
}

sub dependent_properties {
    my ($self, $property_name) = @_;
    return @{$DEPENDENT_PROPERTIES{$property_name}} if exists $DEPENDENT_PROPERTIES{$property_name};
    return;
}


1;
