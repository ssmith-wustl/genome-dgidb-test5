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
        merging_strategy => {
            via => 'processing_profile',
            to => 'merging_strategy',
        },
        contamination_screen_reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            is_mutable => 1,
            via => 'inputs',
            to => 'value',
            where => [name => 'contamination_screen_reference', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence'],
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

    $class->status_message("Beginning creation of metagenomic-composition-shotgun model");

    my %params = @_;
    my $contamination_screen_reference = delete $params{contamination_screen_reference};
    my $metagenomic_references = delete $params{metagenomic_references};

    my $self = $class->SUPER::create(%params);
    return unless $self;

    $self->contamination_screen_reference($contamination_screen_reference);
    for my $metagenomic_reference (@$metagenomic_references) {
        $self->add_metagenomic_reference($metagenomic_reference);
    }
    my $contamination_screen_model = $self->_create_underlying_contamination_screen_model();
    unless ($contamination_screen_model) {
        $self->error_message("Error creating contamination screening model!");
        $self->delete;
        return;
    }

    my @metagenomic_models = $self->_create_underlying_metagenomic_models();
    my @metagenomic_references = $self->metagenomic_references;
    unless (@metagenomic_models == @metagenomic_references) {
        $self->error_message("Error creating metagenomic models!" . scalar(@metagenomic_models) . " " . scalar(@metagenomic_references));
        $self->delete;
        return;
    }

    $self->status_message("Metagenomic composition shotgun model ".$self->name." created successfully");
    return $self;
}


sub _create_underlying_contamination_screen_model {
    my $self = shift;

    #CREATE UNDERLYING REFERENCE ALIGNMENT MODELS
    my %contamination_screen_model_params = (
        processing_profile => $self->contamination_screen_pp,
        subject_name => $self->subject_name,
        name => $self->name.".contamination screen alignment model",
        reference_sequence_build=>$self->contamination_screen_reference
    );
    my $contamination_screen_model = Genome::Model::ReferenceAlignment->create( %contamination_screen_model_params );

    unless ($contamination_screen_model){
        $self->error_message("Couldn't create contamination screen model with params ".join(", ", map {$_ ."=>". $contamination_screen_model_params{$_}} keys %contamination_screen_model_params) );
        return;
    }

    if ($contamination_screen_model->reference_sequence_build($self->contamination_screen_reference)){
        $self->status_message("updated reference sequence build on contamination model ".$contamination_screen_model->name);
    }else{
        $self->error_message("failed to update reference sequence build on contamination model ".$contamination_screen_model->name);
        return;
    }

    $self->add_from_model(from_model=> $contamination_screen_model, role=>'contamination_screen_alignment_model');
    $self->status_message("Created contamination screen alignment model ".$contamination_screen_model->name);

    return $contamination_screen_model
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
        $self->status_message("Created metagenomic alignment model ".$metagenomic_alignment_model->name);
    }

    return @new_objects;
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/MetagenomicComposition16s.pm $
#$Id: MetagenomicComposition16s.pm 56090 2010-03-03 23:57:25Z ebelter $
