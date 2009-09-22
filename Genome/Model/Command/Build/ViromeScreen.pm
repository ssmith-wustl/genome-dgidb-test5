package Genome::Model::Command::Build::ViromeScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ViromeScreen {
    is => 'Genome::Model::Command::Build',
    has => [
	barcode_file => {
	    doc => 'Barcode file that contains sequences to filter reads by',
	    is => 'String',
	    is_optional => 1,
	},
	log_file => {
	    doc => 'Log file to keep track of virome screen run ',
	    is => 'String',
	    is_optional => 1,
	},
    ]
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    #SHOULD BE DONE IN BUILD
    unless (-s $self->barcode_file) {
	$self->error_message("Error: Uable to open file: ".$self->barcode_file);
	return;
    }

    $self->build->barcode_file($self->barcode_file);
    $self->build->log_file($self->log_file);

    return $self;
}

sub help_brief {
    "Run virome screening on a 454 run"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

1;
