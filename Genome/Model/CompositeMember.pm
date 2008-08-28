package Genome::Model::CompositeMember;

use strict;
use warnings;

use Genome;
class Genome::Model::CompositeMember {
    type_name => 'genome model composite member',
    table_name => 'GENOME_MODEL_COMPOSITE_MEMBER',
    er_role => 'bridge',
    id_by => [ 'member_id', 'composite_id'
    ],
    has => [
        composite_id           => { is => 'NUMBER', len => 11 },
        genome_model_composite => { is => 'Genome::Model', id_by => 'composite_id', constraint_name => 'GMCP_GM1_FK' },
        genome_model_member    => { is => 'Genome::Model', id_by => 'member_id', constraint_name => 'GMCP_GM2_FK' },
        member_id              => { is => 'NUMBER', len => 11 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'For composite genome models this will bridge the composite
models to the member models',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    return $self;
}
1;
