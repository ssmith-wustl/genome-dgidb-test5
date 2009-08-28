package Genome::Model::Tools::AmpliconAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AmpliconAssembly {
    is => 'Command',
    is_abstract => 1,
    has => [
    Genome::AmpliconAssembly->attributes, 
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
        $self->error_message("Can't get amplicon assembly with given parameters. See above error.");
        return;
    }

    return $self;
}

#< AA >#
sub amplicon_assembly {
    my $self = shift;

    unless ( $self->{_amplicon_assembly} ) {
        my $amplicon_assembly = Genome::AmpliconAssembly->create(
            directory => $self->directory,
            sequencing_center => $self->sequencing_center,
            sequencing_platform => $self->sequencing_platform,
            subject_name => $self->subject_name,
        ) or return;
        $amplicon_assembly->create_directory_structure
            or return;
        $self->{_amplicon_assembly} = $amplicon_assembly;
    }

    return $self->{_amplicon_assembly};
}

1;

#$HeadURL$
#$Id$
