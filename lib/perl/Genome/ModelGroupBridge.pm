package Genome::ModelGroupBridge;

use strict;
use warnings;

use Genome;
use Mail::Sendmail;

class Genome::ModelGroupBridge {
    type_name  => 'genome model group bridge',
    table_name => 'GENOME_MODEL_GROUP',
    er_role    => 'bridge',
    id_by      => [
        model_group_id => { is => 'NUMBER', len => 11 },
        model_id       => { is => 'NUMBER', len => 11 },
    ],
    has => [
        model => {
            is              => 'Genome::Model',
            id_by           => 'model_id',
            constraint_name => 'GMG_GM_FK'
        },
        model_group => {
            is              => 'Genome::ModelGroup',
            id_by           => 'model_group_id',
            constraint_name => 'GMG_MG_FK'
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $self = (shift)->SUPER::create(@_);
    if ($self->model_group_id == 6574){
        my $msg = Carp::longmess;
        $msg .= "\nHostname\n";
        $msg .= Sys::Hostname::hostname;
        $msg .= "\nPID\n";
        $msg .= $$;
        $msg .= "\nusername\n";
        $msg .= Genome::Sys->username;
        $msg .= "\nsudo_username\n";
        $msg .= Genome::Sys->sudo_username;
        $msg .= "\ngroup id\n";
        $msg .= $self->model_group_id;

        Mail::Sendmail::sendmail(
            To => 'jkoval@genome.wustl.edu',
            From => 'apipe-builder@genome.wustl.edu',
            Subject => 'Model group is having yet another model added to it',
            Message => $msg,
        );
    }
    return $self;
}

1;
