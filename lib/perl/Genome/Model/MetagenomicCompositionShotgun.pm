package Genome::Model::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;

class Genome::Model::MetagenomicCompositionShotgun {
    is => 'Genome::Model',
    has => [
        contamination_screen_pp => {
            via => 'processing_profile',
            to => '_contamination_screen_pp',
        },
        contamination_screen_pp_id => {
            via => 'processing_profile',
            to => 'contamination_screen_pp_id',
        },
        metagenomic_alignment_pp => {
            via => 'processing_profile',
            to => '_metagenomic_alignment_pp',
        },
        metagenomic_alignment_pp_id => {
            via => 'processing_profile',
            to => 'metagenomic_alignment_pp_id',
        },
        unaligned_metagenomic_alignment_pp => {
            via => 'processing_profile',
            to => '_unaligned_metagenomic_alignment_pp',
        },
        unaligned_metagenomic_alignment_pp_id => {
            via => 'processing_profile',
            to => 'unaligned_metagenomic_alignment_pp_id',
        },
        first_viral_verification_alignment_pp => {
            via => 'processing_profile',
            to => '_first_viral_verification_alignment_pp',
        },
        first_viral_verification_alignment_pp_id => {
            via => 'processing_profile',
            to => 'first_viral_verification_alignment_pp_id',
        },
        second_viral_verification_alignment_pp => {
            via => 'processing_profile',
            to => '_second_viral_verification_alignment_pp',
        },
        second_viral_verification_alignment_pp_id => {
            via => 'processing_profile',
            to => 'second_viral_verification_alignment_pp_id',
        },
        merging_strategy => {
            via => 'processing_profile',
            to => 'merging_strategy',
        },
        contamination_screen_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            is_optional => 1,
            is_many => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'contamination_screen_reference', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
        },
        unaligned_metagenomic_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'unaligned_metagenomic_alignment_reference ', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
        },
        first_viral_verification_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            is_optional => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'first_viral_verification_alignment_reference ', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
        },
        second_viral_verification_alignment_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            is_optional => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'second_viral_verification_alignment_reference ', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
        },
        metagenomic_references => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            is_many => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'metagenomic_alignment_reference', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
        },
        _contamination_screen_alignment_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_optional => 1,
            via => 'from_model_links',
            to => 'from_model',
            where => [role => 'contamination_screen_alignment_model'],
        },
        _metagenomic_alignment_models => {
            is => 'Genome::Model::ReferenceAlignment',
            is_many => 1,
            via => 'from_model_links', 
            to => 'from_model',
            where => [role => 'metagenomic_alignment_model'],
        },
        _unaligned_metagenomic_alignment_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_optional => 1,
            via => 'from_model_links',
            to => 'from_model',
            where => [role => 'unaligned_metagenomic_alignment_model'],
        },
        _first_viral_verification_alignment_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_optional => 1, 
            via => 'from_model_links',
            to => 'from_model',
            where => [role => 'first_viral_verification_alignment_model'],
        },
        _second_viral_verification_alignment_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_optional => 1, 
            via => 'from_model_links',
            to => 'from_model',
            where => [role => 'second_viral_verification_alignment_model'],
        },
    ],
};

sub build_subclass_name {
    return 'metagenomic-composition-shotgun';
}

sub delete {
    my $self = shift;
    for my $sub_model ($self->_contamination_screen_alignment_model, $self->_metagenomic_alignment_models) {
        next unless $sub_model;
        $sub_model->delete;
    }
    return $self->SUPER::delete(@_);
}

sub create{
    my $class = shift;

    my %params = @_;
    my $self = $class->SUPER::create(%params);
    return unless $self;

    if($self->contamination_screen_pp) {
        my $contamination_screen_model = $self->_create_underlying_contamination_screen_model();
        unless ($contamination_screen_model) {
            $self->error_message("Error creating contamination screening model!");
            $self->delete;
            return;
        }
    }

    my @metagenomic_models = $self->_create_underlying_metagenomic_models();
    my @metagenomic_references = $self->metagenomic_references;
    unless (@metagenomic_models == @metagenomic_references) {
        $self->error_message("Error creating metagenomic models!" . scalar(@metagenomic_models) . " " . scalar(@metagenomic_references));
        $self->delete;
        return;
    }

    if ($self->unaligned_metagenomic_alignment_pp) {
        my $unaligned_metagenomic_alignment_model = $self->_create_unaligned_metagenomic_alignment_model();
        unless ($unaligned_metagenomic_alignment_model) {
            $self->error_message("Error creating unaligned metagenomic alignment model!");
            $self->delete;
            return;
        }
    }

    if ($self->first_viral_verification_alignment_pp) {
        my $first_viral_verification_alignment_model = $self->_create_first_viral_verification_alignment_model();
        unless ($first_viral_verification_alignment_model) {
            $self->error_message("Error creating first viral verification alignment model!");
            $self->delete;
            return;
        }
    }

    if ($self->second_viral_verification_alignment_pp) {
        my $second_viral_verification_alignment_model = $self->_create_second_viral_verification_alignment_model();
        unless ($second_viral_verification_alignment_model) {
            $self->error_message("Error creating second viral verification alignment model!");
            $self->delete;
            return;
        }
    }

    return $self;
}

sub _create_underlying_contamination_screen_model {
    my $self = shift;
    return $self->_create_model_for_type("contamination_screen");
}

sub _create_underlying_metagenomic_models {
    my $self = shift;

    my @new_objects;
    my $metagenomic_counter = 0;
    for my $metagenomic_reference ($self->metagenomic_references){ 
        $metagenomic_counter++;

        my %metagenomic_alignment_model_params = (
            processing_profile => $self->metagenomic_alignment_pp,
            subject_name => $self->subject_name, 
            name => $self->name.".metagenomic alignment model $metagenomic_counter",
            reference_sequence_build => $metagenomic_reference
        );
        my $metagenomic_alignment_model = Genome::Model::ReferenceAlignment->create( %metagenomic_alignment_model_params );

        unless ($metagenomic_alignment_model){
            $self->error_message("Couldn't create metagenomic reference model with params ".join(", " , map {$_ ."=>". $metagenomic_alignment_model_params{$_}} keys %metagenomic_alignment_model_params) );
            for (@new_objects){
                $_->delete;
            }
            return;
        }

        if ($metagenomic_alignment_model->reference_sequence_build($metagenomic_reference)){
            $self->status_message("updated reference sequence build on metagenomic alignment model ".$metagenomic_alignment_model->name);
        }else{
            $self->error_message("failed to update reference sequence build on metagenomic alignment model ".$metagenomic_alignment_model->name);
            for (@new_objects){
                $_->delete;
            }
            return;
        }

        push @new_objects, $metagenomic_alignment_model;
        $self->add_from_model(from_model=>$metagenomic_alignment_model, role=>'metagenomic_alignment_model');
        $self->status_message("Created metagenomic alignment model ".$metagenomic_alignment_model->__display_name__);
    }

    return @new_objects;
}

sub _create_unaligned_metagenomic_alignment_model {
    my $self = shift;
    return $self->_create_model_for_type("unaligned_metagenomic_alignment");
}

sub _create_first_viral_verification_alignment_model {
    my $self = shift;
    return $self->_create_model_for_type("first_viral_verification_alignment");
}

sub _create_second_viral_verification_alignment_model {
    my $self = shift;
    return $self->_create_model_for_type("second_viral_verification_alignment");
}

sub _create_model_for_type {
    my $self = shift;
    my $type = shift;

    #CREATE UNDERLYING REFERENCE ALIGNMENT MODELS
    my $pp_accessor = $type."_pp";
    my $reference_accessor = $type."_reference";
    my %model_params = (
        processing_profile => $self->$pp_accessor,
        subject_name => $self->subject_name,
        name => $self->name.".$type model",
        reference_sequence_build=>$self->$reference_accessor,
    );
    my $model = Genome::Model::ReferenceAlignment->create( %model_params );

    unless ($model){
        $self->error_message("Couldn't create contamination screen model with params ".join(", ", map {$_ ."=>". $model_params{$_}} keys %model_params) );
        return;
    }

    if ($model->reference_sequence_build($self->$reference_accessor)){
        $self->status_message("updated reference sequence build on $type model ".$model->name);
    }else{
        $self->error_message("failed to update reference sequence build on $type model ".$model->name);
        return;
    }

    $self->add_from_model(from_model=> $model, role=>$type.'_alignment_model');
    $self->status_message("Created $type model ".$model->__display_name__);

    return $model;
}

1;
