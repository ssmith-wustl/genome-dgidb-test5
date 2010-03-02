#:boberkfe this should be able to de-assign a model from a group too


package Genome::ModelGroup;

use strict;
use warnings;

use Genome;
class Genome::ModelGroup {
    type_name  => 'model group',
    table_name => 'MODEL_GROUP',
    id_by      => [ id => { is => 'NUMBER', len => 11 }, ],
    has        => [
        name          => { is => 'VARCHAR2', len => 50 },
        model_bridges => {
            is         => 'Genome::ModelGroupBridge',
            reverse_as => 'model_group',
            is_many    => 1
        },
        models => {
            is      => 'Genome::Model',
            is_many => 1,
            via     => 'model_bridges',
            to      => 'model'
        },
        convergence_model => {
            is          => 'Genome::Model::Convergence',
            is_many => 1, # We really should only have 1 here, however reverse_as requires this
            reverse_as  => 'group',
            doc         => 'The auto-generated Convergence Model summarizing knowledge about this model group',
            is_optional => 1, 
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my %params = @_;
    
    my %convergence_model_params = ();
    if(exists $params{convergence_model_params}) {
        %convergence_model_params = %{ delete $params{convergence_model_params} };
    } 
    
    my $self = $class->SUPER::create(%params);
    
    my $define_command = Genome::Model::Command::Define::Convergence->create(
        %convergence_model_params,
        model_group_id => $self->id
    );

    unless ($define_command->execute == 1) {
        $self->error_message("Failed to create convergence model associated with this model group");
        die;
    }
    
    return $self;
}


sub assign_models {

    my ($self, @models) = @_;

    for my $m (@models) {

        if(grep($_->id eq $m->id, $self->models)) {
            die('Model ' . $m->id . ' already in ModelGroup ' . $self->id);
        }
        
        my $bridge = Genome::ModelGroupBridge->create(
            model_group_id => $self->id,
            model_id       => $m->genome_model_id,
        );
    }

    $self->launch_convergence_rebuild;
    
    return 1;
}

sub unassign_models {

    my ($self, @models) = @_;

    for my $m (@models) {

        my $bridge = Genome::ModelGroupBridge->get(
            model_group_id => $self->id,
            model_id       => $m->genome_model_id,
        );
        
        unless($bridge){
            die('Model ' . $m->id . ' not found in ModelGroup ' . $self->id);
        }
        
        $bridge->delete();
    }

    $self->launch_convergence_rebuild;

    return 1;
}

sub launch_convergence_rebuild {
    my $self = shift;
    
    if (defined $self->convergence_model) {
        $self->status_message("Trying rebuild of associated convergence model.");
        unless($self->convergence_model->launch_rebuild) {
            $self->error_message($self->convergence_model->error_message);
            die;
        }
    }
    
    return 1;
}

sub map_builds {

    my ($self, $func) = @_;
    my @result;

    my @models = $self->models();

    for my $model (@models) {

        my $build = $model->last_complete_build();
        my $value = $func->($model, $build); # even if $build is undef
    
        push @result,
            {
            'model'    => $model,
            'model_id' => $model->id,
            'build'    => $build,
            'value'    => $value
            };
    }

    return @result;
}

sub reduce_builds {

    # apply $reduce function on results of $map or list 
    # of builds for this model group
    
    my ($self, $reduce, $map) = @_;
    my @b;

    if ($map) {
        @b = $self->map_builds($map);
    } else {
        @b = $self->builds();
    }

    my $result = $reduce->(@b);
    return $result;
}

sub builds {

    my ($self) = @_;
    my @models = $self->models();
    my @builds;

    for my $model (@models) {
        my $build = $model->last_complete_build();
        next if !$build;
        push @builds, $build;
    }

    return @builds;
}

1;



