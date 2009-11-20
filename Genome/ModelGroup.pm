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

# { calculate => q( return map {$_->model} $self->model_bridges ) },
# TODO: write method to expect array of models, set them to this group

sub assign_models {

    my ($self, @models) = @_;

    for my $m (@models) {

        my $bridge = Genome::ModelGroupBridge->create(
            model_group_id => $self->id,
            model_id       => $m->genome_model_id,
        );
    }

}

1;
