package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
};

sub execute {
    my $self = shift;
    
    #create contigs.bases file
    $self->status_message("Creating contigs.bases file. TIME: ".UR::Time->now);
    my $contigs = Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to successfully execute creating contigs.bases file");
	return;
    }
    $self->status_message("Finished creating contigs.bases file. TIME: ".UR::Time->now);


    #create supercontigs.fasta file
    $self->status_message("Creating supercontigs.fasta file. TIME: ".UR::Time->now);
    my $supercontigs = Genome::Model::Tools::Soap::CreateSupercontigsFastaFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed to successfully execute creating supercontigs.fasta file");
	return;
    }
    $self->status_message("Finished creating supercontigs.fasta file. TIME: ".UR::Time->now);


    #create supercontigs.agp file
    $self->status_message("Creating supercontigs.agp file. TIME: ".UR::Time->now);
    my $agp = Genome::Model::Tools::Soap::CreateSupercontigsAgpFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($agp->execute) {
	$self->error_message("Failed to successfully execute creating supercontigs.agp file");
	return;
    }
    $self->status_message("Finished creating supercontigs.agp file. TIME: ".UR::Time->now);

    return 1;
}

1;
