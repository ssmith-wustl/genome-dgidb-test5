package Genome::Model::Command::Update::AutoAssignInstrumentData;

class Genome::Model::Command::Update::AutoAssignInstrumentData {
    is => 'Genome::Command::Base',
    has => [
        models => {
            is => 'Genome::Model',
            is_many => 1,
            doc => 'Models for which auto_assign_inst_data will be set to the value provided. Resolved by Genome::Command::Base.',
        },
        value => {
            is => 'Text',
            valid_values => ['0', '1'],
            doc => 'Enable or disable the auto_assign_inst_data flag.',
        },
    ],
};


sub _is_hidden_in_docs { return 1; }


sub help_detail {
    return 'Set auto_assign_inst_data to the value for the models.'
}


sub execute {
    my $self = shift;

    my $user = getpwuid($<);
    my $apipe_members = (getgrnam("apipe"))[3];
    if ($apipe_members !~ /\b$user\b/) {
        print "You must be a member of APipe to use this command.\n";
        return;
    }

    my @models = $self->models;
    my $value = $self->value;

    for my $model (@models) {
        $model->auto_assign_inst_data($value);
    }

    return 1;
}

1;
