package Genome::ProcessingProfile::Command;

use strict;
use warnings;

use Genome;
      
class Genome::ProcessingProfile::Command {
    is => 'Command',
    is_abstract => 1,
    english_name => 'genome processing_profile command',
    has => [
    processing_profile => {
        is => 'Genome::ProcessingProfile',
        id_by => 'processing_profile_id',
        doc => 'identifies the genome processing_profile by id',
    },
    ],
};

############################################

sub help_brief {
    return 'Operations for processing profile';
}

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome processing-profile';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'processing-profile';
}

############################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    unless ( $self->processing_profile_id ) {
        $self->error_message("A processing profile by id is required for this command");
        return;
    }

    return $self;
}

1;

#$HeadURL$
#$Id$
