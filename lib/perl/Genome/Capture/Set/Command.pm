package Genome::Capture::Set::Command;

use strict;
use warnings;

use Genome;
      
class Genome::Capture::Set::Command {
    is => 'Command',
    is_abstract => 1,
    has => [
        capture_set => {is => 'Genome::Capture::Set',id_by => 'capture_set_id'},
        capture_set_id => { is => 'Integer', doc => 'identifies the capture set by id' },
    ],
    doc => 'work with capture set',
};

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome capture set';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'capture set';
}

############################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    unless ( $self->capture_set) {
        $self->error_message("A capture set must be specified by id for this command");
        return;
    }

    return $self;
}

1;
