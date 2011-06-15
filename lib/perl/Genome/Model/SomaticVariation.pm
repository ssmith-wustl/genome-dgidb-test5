package Genome::Model::SomaticVariation;
#:adukes short term, keep_n_most_recent_builds shouldn't have to be overridden like this here.  If this kind of default behavior is acceptable, it belongs in the base class

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticVariation {
    is  => 'Genome::Model',
    has => [
        snv_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        sv_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        indel_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        cnv_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        tiering_version => {
            is => 'Text',
            via => 'processing_profile',
            is_optional => 1,
        },
        loh_version => {
            is => 'Text',
            via => 'processing_profile',
            is_optional => 1,
        },
       tumor_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'tumor_model', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 0,
            doc => 'tumor model for somatic analysis'
        },
        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'tumor_model_id',
        },
        tumor_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'tumor_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment'],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'last complete tumor build, updated when a new SomaticVariation build is created',
        },
        tumor_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'tumor_build_id',
        },
        normal_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'normal_model', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 0,
            doc => 'normal model for somatic analysis'
        },
        normal_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'normal_model_id',
        },
        normal_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'normal_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment'],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'last complete normal build, updated when a new SomaticVariation build is created',
        },
        normal_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'normal_build_id',
        },
        annotation_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'annotation_build', value_class_name => 'Genome::Model::Build::ImportedAnnotation' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 0,
            doc => 'annotation build for fast tiering'
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            id_by => 'annotation_build_id',
        },
        previously_discovered_variations_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'previously_discovered_variations', value_class_name => "Genome::Model::Build::ImportedVariationList"],
            is_many => 0,
            is_mutable => 1,
            is_optional => 0,
            doc => 'previous variants genome feature set to screen somatic mutations against',
        },
        previously_discovered_variations_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            id_by => 'previously_discovered_variations_build_id',
        },
        force => {
            is => 'Boolean',
            is_optional => 1,
            is_many => 0,
            default => 0,
            doc => 'Allow creation of somatic variation models where --tumor_model and --normal_model do not have matching Genome::Individuals',
        },
    ],
};

sub create {
    my $class = shift;
    my %params = @_;

    $DB::single = 1;

    my $tumor_model = $params{tumor_model} || Genome::Model->get($params{tumor_model_id});
    my $normal_model =  $params{normal_model}  || Genome::Model->get($params{normal_model_id});;
    my $annotation_build = $params{annotation_build} || Genome::Model::Build->get($params{annotation_build_id});
    my $previously_discovered_variations_build = $params{previously_discovered_variations_build} || Genome::Model::Build->get($params{previously_discovered_variations_build_id});

    unless($tumor_model) {
        $class->error_message('No tumor model provided.' );
        return;
    }

    unless($normal_model) {
        $class->error_message('No normal model provided.');
        return;
    }

    unless($annotation_build) {
        $class->error_message('No annotation build provided.' );
        return;
    }

    unless($previously_discovered_variations_build) {
        $class->error_message('No previous variants build provided.');
        return;
    }

    my $tumor_subject = $tumor_model->subject;
    my $normal_subject = $normal_model->subject;

    if($tumor_subject->can('source') and $normal_subject->can('source')) {

        my $tumor_source = $tumor_subject->source;
        my $normal_source = $normal_subject->source;

        unless ($tumor_source eq $normal_source) {
            my $tumor_common_name = $tumor_source->common_name || "unknown";
            my $normal_common_name = $normal_source->common_name || "unknown";
            my $message = "Tumor model and normal model samples do not come from the same individual.  Tumor common name is $tumor_common_name. Normal common name is $normal_common_name.";
            if (defined $params{force} and $params{force} == 1){
                $class->warning_message($message);
            }
            else{
                die $class->error_message($message . " Use --force to allow this anyway.");
            }
        }
        $params{subject_id} = $tumor_subject->id;
        $params{subject_class_name} = $tumor_subject->class;
        $params{subject_name} = $tumor_subject->common_name || $tumor_subject->name;

    } else {
        $class->error_message('Unexpected subject for tumor or normal model!');
        return;
    }

    my $self = $class->SUPER::create(%params);

    unless ($self){
        $class->error_message('Error in model creation');
        return;
    }

    unless($self->tumor_model) {
        $self->error_message('No tumor model on model!' );
        return;
    }

    unless($self->normal_model) {
        $self->error_message('No normal model on model!');
        return;
    }

    unless($self->annotation_build) {
        $self->error_message('No annotation build on model!' );
        return;
    }

    unless($self->previously_discovered_variations_build) {
        $self->error_message('No previous variants build on model!');
        return;
    }

    return $self;
}

sub update_tumor_and_normal_build_inputs {
    my $self = shift;
    
    my $tumor_model = $self->tumor_model;
    my $tumor_build = $tumor_model->last_complete_build;
    $self->tumor_build_id($tumor_build->id) if $tumor_build and $self->tumor_build_id ne $tumor_build->id; 

    my $normal_model = $self->normal_model;
    my $normal_build = $normal_model->last_complete_build;
    $self->normal_build_id($normal_build->id) if $normal_build and $self->normal_build_id ne $normal_build->id; 

    return 1;
}

sub _input_differences_are_ok {
    my $self = shift;
    my @inputs_not_found = @{shift()};
    my @build_inputs_not_found = @{shift()};

    return unless scalar(@inputs_not_found) == 2 and scalar(@build_inputs_not_found) == 2;

    my $input_sorter = sub { $a->name cmp $b->name };

    @inputs_not_found = sort $input_sorter @inputs_not_found;
    @build_inputs_not_found = sort $input_sorter @build_inputs_not_found;

    #these are expected to differ and no new build is needed as long as the build pointed to is the latest for the model
    for(0..$#inputs_not_found) {
        return unless $inputs_not_found[$_]->value && $inputs_not_found[$_]->value->isa('Genome::Model');
        return unless $inputs_not_found[$_]->value->last_complete_build eq $build_inputs_not_found[$_]->value;
    }

    return 1;
}

1;
