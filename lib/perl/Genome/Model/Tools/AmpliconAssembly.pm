package Genome::Model::Tools::AmpliconAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AmpliconAssembly {
    is => 'Command',
    is_abstract => 1,
    has => [
    directory => {
        is => 'Text',
        doc => 'Base directory for the amplicon assembly.  It is required that the amplicon assembly have been previously created, saving it\'s properties.  See the "create" command.',
    },
    map( { $_ => { via => 'amplicon_assembly' } } Genome::AmpliconAssembly->helpful_methods ),
    ],
};

#< Helps >#
sub help_brief {
    return ucfirst(join(' ', split('-', $_[0]->command_name_brief))).' amplicon assemblies';
}

sub help_synopsis {
};

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->amplicon_assembly ) {
        $self->error_message("Can't get amplicon assembly with given parameters. There maybe an error, or it might just needs to be created first.");
        return;
    }

    return $self;
}

#< AA >#
sub amplicon_assembly {
    my $self = shift;

    unless ( $self->{_amplicon_assembly} ) {
        #$self->{_amplicon_assembly} = Genome::AmpliconAssembly->create(
        $self->{_amplicon_assembly} = Genome::AmpliconAssembly->get(
            directory => $self->directory,
        );
    }

    return $self->{_amplicon_assembly};
}

1;

#$HeadURL$
#$Id$
