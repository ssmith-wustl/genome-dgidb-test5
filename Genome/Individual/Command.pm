package Genome::Individual::Command;

use strict;
use warnings;

use Genome;
      
class Genome::Individual::Command {
    is => 'Command',
    is_abstract => 1,
    has => [
        individual_name => {
            is => 'Genome::Individual',
            id_by => 'individual_id',
        },
    ],
    doc => 'work with individuals',
};

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome individual';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'individual';
}

############################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    unless ( $self->individual_name) {
        $self->error_message("A individual must be specified by name for this command");
        return;
    }

    return $self;
}

1;

#$HeadURL: /gscpan/perl_modules/trunk/Genome/ProcessingProfile/Command.pm $
#$Id: /gscpan/perl_modules/trunk/Genome/ProcessingProfile/Command.pm 41270 2008-11-20T22:57:15.665824Z ebelter  $
