package Genome::Model::Tools::AmpliconAssembly::Assemble;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::AmpliconAssembly::Assemble{
    is => 'Genome::Model::Tools::AmpliconAssembly',
    has_optional => [ Genome::Model::Tools::PhredPhrap->properties_hash ],
};

sub execute {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    for my $amplicon ( @$amplicons ) {
        $self->_assemble_amplicon($amplicon)
            or return;
    }

    return 1;
}

sub _assemble_amplicon {
    my ($self, $amplicon) = @_;

    # Create SCF file
    my $scf_file = $amplicon->create_scfs_file;
    unless ( $scf_file ) {
        $self->error_message("Error creating SCF file ($scf_file)");
        return;
    }

    # Create and run the Command
    my $phrap = Genome::Model::Tools::PhredPhrap::ScfFile->create(
        directory => $self->directory,
        assembly_name => $amplicon->get_name,
        scf_file => $scf_file,
        $self->_get_phred_phrap_params,
    );
    unless ( $phrap ) { # bad
        $self->error_message("Can't create phrap command.");
        return;
    }
    #eval{ # if this fatals, we still want to go on
    $phrap->execute;
    #};
    #TODO write file for failed assemblies

    return 1;
}

sub _get_phred_phrap_params {
    my $self = shift;

    my %phred_phrap_props = Genome::Model::Tools::PhredPhrap->properties_hash;
    my %params;
    for my $attr ( keys %phred_phrap_props ) {
        my $value = $self->$attr;
        next unless defined $value;
        $params{$attr} = $value;
    }
    
    return %params;
}

1;

#$HeadURL$
#$Id$
