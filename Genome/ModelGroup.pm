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
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};


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



