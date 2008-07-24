package Genome::Model::Command::MaqSubclasser;

use strict;
use warnings;


use above "Genome";
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    is_abstract => 1,
    doc => 'A helper abstract class used by command modules that need to run different version of maq based on a property of the model',
    has => [
        model_id => { is => 'Integer', doc => 'Identifies the Genome::Model by id' },
        model => { is => 'Genome::Model', id_by => 'model_id', },
    ],
);

sub aligner_path {
    shift->proper_maq_pathname(@_);
}

sub proper_maq_pathname {
    my($self,$model_param_name) = @_;

    my $param_value = $self->model->$model_param_name;
    if ($param_value eq 'maq0_6_3') {
        return '/gsc/pkg/bio/maq/maq-0.6.3_x86_64-linux/maq';
    } elsif ($param_value eq 'maq0_6_4') {
        return '/gsc/pkg/bio/maq/maq-0.6.4_x86_64-linux/maq';
    } elsif ($param_value eq 'maq0_6_5') {
        return '/gsc/pkg/bio/maq/maq-0.6.5_x86_64-linux/maq';
    } elsif ($param_value eq 'maq') {
        return 'maq';
    } else {
        $self->error_message("Couldn't determine maq pathname for the model's $model_param_name param $param_value");
        return;
    }
}

# There's a perl script that's a frontend for some 
# extra maq functionality.  Assumme it's in the same
# location as the maq binary, with a ".pl" extention
sub proper_maq_pl_pathname {
    my($self, $model_param_name) = @_;

    my $path = $self->proper_maq_pathname($model_param_name);

    return $path . '.pl';
}


1;

