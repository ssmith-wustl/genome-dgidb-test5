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

sub __display_name__ {
    my $self = shift;
    return $self->name.' ('.$self->id.')';
}

sub create {
    my $class = shift;
    my ($bx,%params) = $class->define_boolexpr(@_);
    
    my %convergence_model_params = ();
    if(exists $params{convergence_model_params}) {
        %convergence_model_params = %{ delete $params{convergence_model_params} };
    } 
    
    my $self = $class->SUPER::create($bx);
    
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

    $self->schedule_convergence_rebuild;
    
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

    $self->schedule_convergence_rebuild;

    return 1;
}

sub schedule_convergence_rebuild {
    my $self = shift;
    
    if (defined $self->convergence_model) {
        $self->status_message("Trying rebuild of associated convergence model.");
        unless($self->convergence_model->schedule_rebuild) {
            $self->error_message($self->convergence_model->error_message);
            die $self->error_message;
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

sub delete {
    my $self = shift;

    # unassign existing models
    my @models = $self->models;
    if (@models) {
        $self->status_message("Unassigning " . @models . " models from " . $self->__display_name__ . ".");
        $self->status_message("Removed convergence model.");
    }
    else {
        $self->unassign_models(@models);
    }

    # delete convergence model (and indirectly its builds)
    my $convergence_model = $self->convergence_model;
    if ($convergence_model) {
        my $deleted_model = eval {
            $convergence_model->delete;
        };
        if ($deleted_model) {
            $self->status_message("Removed convergence model.");
        }
        else {
            $self->error_message("Failed to remove convergence model (" . $convergence_model->__display_name__ . "), please investigate and remove manually.");
        }
    }

    # delete self
    return $self->SUPER::delete;
}

1;



