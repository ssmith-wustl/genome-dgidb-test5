package Genome::Taxon::Command;

use strict;
use warnings;

use Genome;
      
class Genome::Taxon::Command {
    is => 'Command',
    is_abstract => 1,
    has => [
        sample_name => {
            is => 'Genome::Taxon',
            id_by => 'tax_id',
        },
    ],
    doc => 'work with species, strains etc.',
};

############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome taxon';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'taxon';
}

############################################

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    
    unless ( $self->sample_name) {
        $self->error_message("A sample must be specified by name for this command");
        return;
    }

    return $self;
}

1;

