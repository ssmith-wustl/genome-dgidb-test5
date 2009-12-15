package Genome::Model::Command::Build::ViromeScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ViromeScreen {
    is => 'Genome::Model::Command::Build::Start',
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
    ],
    doc => "custom launcher for virome screening builds (454)"
};

sub sub_command_sort_position { 99 }

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


sub help_synopsis {
    return <<"EOS"
genome-model build virome-screen --model-id 12345 --barcode-file /my/file --log-file /my/bad/idea
EOS
}

sub help_detail {
    return <<"EOS"
Normally to build a genome model, you just run "genome model build".  The virome screening pipeline requires custom parameters to be supplied at execution time, so it has a special build command.

When this is fixed, this command will go away.
EOS
}

1;
