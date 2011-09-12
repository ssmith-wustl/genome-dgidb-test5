package Genome::Model::SmallRna;

use strict;
use warnings;

use Genome;

class Genome::Model::SmallRna {
    is  => 'Genome::Model',
    has => [
        
       ref_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'ref_model', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 0,
            doc => 'ref model for somatic analysis'
        },
        ref_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'ref_model_id',
        },
        ref_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'ref_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment'],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'last complete ref build, updated when a new SomaticVariation build is created',
        },
        ref_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'ref_build_id',
        },
    ],
};

sub create {
    my $class  = shift;
    my $bx = $class->define_boolexpr(@_);
    my %params = $bx->params_list;


    my $ref_model  = $params{ref_model} || Genome::Model->get($params{ref_model_id});
 
    unless($ref_model) {
        $class->error_message('No ref model provided.' );
        return;
    }

   
    my $ref_subject  = $ref_model->subject;
    
        $params{subject_id} = $ref_subject->id;
        $params{subject_class_name} = $ref_subject->class;
        $params{subject_name} = $ref_subject->common_name || $ref_subject->name;

    
    my $self = $class->SUPER::create(%params);

    unless ($self){
        $class->error_message('Error in model creation');
        return;
    }

    unless($self->ref_model) {
        $self->error_message('No smallrna ref model on model!' );
        $self->delete;
        return;
    }

    return $self;
}

sub update_build_inputs {
    my $self = shift;
    
    my $ref_model = $self->ref_model;
   # my $ref_build = $ref_model->last_complete_build;
  #  $self->ref_build_id($ref_build->id) if $ref_build and $self->ref_build_id ne $ref_build->id; 

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