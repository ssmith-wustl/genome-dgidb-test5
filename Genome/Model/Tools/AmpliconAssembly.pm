package Genome::Model::Tools::AmpliconAssembly;

use strict;
use warnings;

use Genome;

require Genome::AmpliconAssembly;

class Genome::Model::Tools::AmpliconAssembly {
    is => 'Command',
    is_abstract => 1,
    has => [
    Genome::AmpliconAssembly->attributes, 
    map( { $_ => { via => 'amplicon_assembly' } } amplicon_assembly_methods_to_incorporate() ),
    ],
};

#< Helps >#
sub help_brief {
    return 'Work with amplicon assemblies';
}

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    $self->amplicon_assembly
        or die;
    
    $self->amplicon_assembly->create_directory_structure
        or return;

    return $self;
}

#< AA >#
sub amplicon_assembly {
    my $self = shift;

    unless ( $self->{_amplicon_assembly} ) {
        $self->{_amplicon_assembly} = Genome::AmpliconAssembly->create(
            directory => $self->directory,
            sequencing_center => $self->sequencing_center,
        );
    }
    
    return $self->{_amplicon_assembly};
}

sub amplicon_assembly_methods_to_incorporate {
    return (qw/ 
        chromat_dir phd_dir edit_dir create_directory_structure
        get_amplicons 
        /);
}

1;

#$HeadURL$
#$Id$
