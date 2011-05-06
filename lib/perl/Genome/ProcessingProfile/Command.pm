package Genome::ProcessingProfile::Command;

#REVIEW fdu 11/20/2009
#OK

use strict;
use warnings;

use Genome;
      
use Regexp::Common;

class Genome::ProcessingProfile::Command {
    is => 'Command',
    is_abstract => 1,
    english_name => 'genome processing_profile command',
    has => [
        processing_profile => {
            is => 'Genome::ProcessingProfile',
            id_by => 'processing_profile_id',
        },
        processing_profile_id => {
            is => 'Integer',
            shell_args_position => 1,
            doc => 'Identifies the genome processing profile by id',
        },
    ],
    doc => 'work with processing profiles.',
};

############################################

sub help_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->__meta__->doc if not $class or $class eq __PACKAGE__;
    my ($func) = $class =~ /::(\w+)$/;
    return sprintf('%s a processing profile', ucfirst($func));
}

sub help_detail {
    return help_brief(@_);
}

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

sub _verify_processing_profile {
    my $self = shift;

    unless ( $self->processing_profile_id ) {
        $self->error_message("No processing profile id given");
        return;
    }

    unless ( $self->processing_profile_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Processing profile id given (%s) is not an integer', $self->processing_profile_id) );
        return;
    }

    unless ( $self->processing_profile ) {
        $self->error_message( sprintf('Can\'t get processing profile for id (%s) ', $self->processing_profile_id) );
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
