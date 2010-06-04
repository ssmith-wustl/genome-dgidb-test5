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
            is_many => 1,
            is_mutable => 1,
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

my $default_contamination_screen_reference_name = "contamination-human";
my @default_metagenomic_reference_names = ('microbial reference part 1 of 2', 'microbial reference part 2 of 2');

sub build_subclass_name {
    return 'metagenomic-composition-shotgun';
}

sub create{
    my $class = shift;
    
    $class->status_message("Beginning creation of metagenomic-composition-shotgun model");
    
    my @new_objects;
   
    my $self = $class->SUPER::create(@_); 
    
    
    #DETECT OR SET REFERENCE DEFAULTS
    unless($self->contamination_screen_reference){
        my $contamination_screen_reference = Genome::Model->get(name => $default_contamination_screen_reference_name);
        unless ($contamination_screen_reference){
            $self->error_message("Couldn't grab imported-reference-sequence model $default_contamination_screen_reference_name to set default contamination_screen_reference");
            $self->cleanup(@new_objects);
            return;
        }
        my $build = $contamination_screen_reference->last_complete_build;
        unless($build){
            $self->error_message("Couldn't grab latest complete build from $default_contamination_screen_reference_name the default contamination_screen_reference");
            $self->cleanup(@new_objects);
            return;
        }
        $self->contamination_screen_reference($build);
        $self->status_message("Set contamination_reference build to $default_contamination_screen_reference_name model's latest build");
    }
    
    unless($self->metagenomic_references){
        my @metagenomic_references = map {Genome::Model->get(name => $_) } @default_metagenomic_reference_names;
        unless ( (scalar @default_metagenomic_reference_names) == grep { $_->isa('Genome::Model::ImportedReferenceSequence') }@metagenomic_references ){
            $self->error_message("Couldn't grab imported-reference-sequence models (".join(",", @default_metagenomic_reference_names).") to set default metagenomic_screen_references");
            $self->cleanup(@new_objects);
            return;
        }
        my @builds = map { $_->last_complete_build } @metagenomic_references;
        unless ( (scalar @default_metagenomic_reference_names) == grep { $_->isa('Genome::Model::Build::ImportedReferenceSequence') } @builds){
            $self->error_message("Couldn't grab imported-reference-sequence builds (".join(",", @default_metagenomic_reference_names).") to set default metagenomic_screen_references");
            $self->cleanup(@new_objects);
            return;
        }
        for (@builds){
            $self->add_metagenomic_reference($_);
        }
        $self->status_message("Set metagenomic reference builds to ".join(", ", @default_metagenomic_reference_names)." models latest builds");
    }

    #CREATE UNDERLYING REFERENCE ALIGNMENT MODELS
    my %contamination_screen_model_params = (
        processing_profile => $self->contamination_screen_pp,
        subject_name => $self->subject_name,
        name => $self->name.".contamination screen alignment model",
    );
    my $contamination_screen_model = Genome::Model::ReferenceAlignment->create( %contamination_screen_model_params );

    unless ($contamination_screen_model){
        $self->error_message("Couldn't create contamination screen model with params ".join(", ", map {$_ ."=>". $contamination_screen_model_params{$_}} keys %contamination_screen_model_params) );
        $self->cleanup(@new_objects);
        return;
    }
    
    if ($contamination_screen_model->reference_sequence_build($self->contamination_screen_reference)){
        $self->status_message("updated reference sequence build on contamination model ".$contamination_screen_model->name);
    }else{
        $self->error_message("failed to update reference sequence build on contamination model ".$contamination_screen_model->name);
        $self->cleanup(@new_objects);
        return;
    }

    push @new_objects, $contamination_screen_model;
    $self->add_from_model(from_model=> $contamination_screen_model, role=>'contamination_screen_alignment_model');
    $self->status_message("Created contamination screen alignment model ".$contamination_screen_model->name);

    my $metagenomic_counter = 0;
    for my $metagenomic_reference ($self->metagenomic_references){ 
        $metagenomic_counter++;
        
        my %metagenomic_alignment_model_params = (
            processing_profile => $self->metagenomic_alignment_pp,
            subject_name => $self->subject_name, 
            name => $self->name.".metagenomic alignment model $metagenomic_counter",
        );
        my $metagenomic_alignment_model = Genome::Model::ReferenceAlignment->create( %metagenomic_alignment_model_params );
     
        unless ($metagenomic_alignment_model){
            $self->error_message("Couldn't create metagenomic reference model with params ".join(", " , map {$_ ."=>". $metagenomic_alignment_model_params{$_}} keys %metagenomic_alignment_model_params) );
            $self->cleanup(@new_objects);
            return;
        }
    
        if ($metagenomic_alignment_model->reference_sequence_build($metagenomic_reference)){
            $self->status_message("updated reference sequence build on metagenomic alignment model ".$metagenomic_alignment_model->name);
        }else{
            $self->error_message("failed to update reference sequence build on metagenomic alignment model ".$metagenomic_alignment_model->name);
            $self->cleanup(@new_objects);
            return;
        }

        push @new_objects, $metagenomic_alignment_model;
        $self->add_from_model(from_model=>$metagenomic_alignment_model, role=>'metagenomic_alignment_model');
        $self->status_message("Created metagenomic alignment model ".$metagenomic_alignment_model->name);
    }

    $self->status_message("Metagenomic composition shotgun model ".$self->name." created successfully");
    return $self;
}

sub cleanup{
    my ($self, @objs_to_delete) = @_;
    for (@objs_to_delete){
        $_->delete;
    }
}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/MetagenomicComposition16s.pm $
#$Id: MetagenomicComposition16s.pm 56090 2010-03-03 23:57:25Z ebelter $
