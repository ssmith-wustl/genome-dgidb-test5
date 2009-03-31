package Genome::Model::Command::Build::AmpliconAssembly::Assemble;

use strict;
use warnings;

use Genome;

require Genome::Model::Tools::PhredPhrap::ScfFile;

class Genome::Model::Command::Build::AmpliconAssembly::Assemble{
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons
        or return;

    for my $amplicon ( @$amplicons ) {
        $self->_assemble_amplicon($amplicon)
            or return;
    }

    #print $self->build->data_directory,"\n"; <STDIN>;

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
    my $command = Genome::Model::Tools::PhredPhrap::ScfFile->create(
        directory => $self->build->data_directory,
        assembly_name => $amplicon->get_name,
        scf_file => $scf_file,
    );
    #eval{ # if this fatals, we still want to go on
    $command->execute;
    #};
    #TODO write file for failed assemblies

    return 1;
}

1;

#$HeadURL$
#$Id$
