package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Soap {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
};

sub execute {
    my $self = shift;

    #create edit_dir for post assemble files
    Genome::Utility::FileSystem->create_directory($self->build->edit_dir);

    #create contigs.bases file
    $self->status_message("Creating contigs.bases file");
    my $contigs = Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to successfully execute creating contigs.bases file");
	return;
    }
    $self->status_message("Finished creating contigs.bases file");


    #create supercontigs.fasta file
    $self->status_message("Creating supercontigs.fasta file");
    my $supercontigs = Genome::Model::Tools::Soap::CreateSupercontigsFastaFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed to successfully execute creating supercontigs.fasta file");
	return;
    }
    $self->status_message("Finished creating supercontigs.fasta file");


    #create supercontigs.agp file
    $self->status_message("Creating supercontigs.agp file");
    my $agp = Genome::Model::Tools::Soap::CreateSupercontigsAgpFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	);
    unless ($agp->execute) {
	$self->error_message("Failed to successfully execute creating supercontigs.agp file");
	return;
    }
    $self->status_message("Finished creating supercontigs.agp file");

    #TODO - need a method to grab these when there will be more than just these two
    my @input_fastqs = ($self->build->end_one_fastq_file, $self->build->end_two_fastq_file);

    #create stats
    $self->status_message("Creating stats.txt file");
    my $stats = Genome::Model::Tools::Soap::Stats->create(
	assembly_directory => $self->build->data_directory,
	input_fastq_files => \@input_fastqs,
	);
    unless ($stats->execute) {
	$self->error_message("Failed to run stats successfully");
	return;
    }
    $self->status_message("Finished creating stats.txt file");

    return 1;
}

1;
