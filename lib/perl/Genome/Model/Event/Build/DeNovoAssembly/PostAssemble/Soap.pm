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
    my $root_file_name = $self->build->instrument_data->sample_name.'_'.$self->build->center_name;

    $self->status_message("Creating contigs fasta file");
    my $contigs = Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	output_file => $self->build->data_directory.'/edit_dir/'.$root_file_name.'.contigs.fa',
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to successfully execute creating contigs fasta file");
	return;
    }
    $self->status_message("Finished creating contigs fasta file");


    #create supercontigs.fasta file
    $self->status_message("Creating supercontigs fasta file");
    my $supercontigs = Genome::Model::Tools::Soap::CreateSupercontigsFastaFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	output_file => $self->build->data_directory.'/edit_dir/'.$root_file_name.'.scaffolds.fa',
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed to successfully execute creating scaffolds fasta file");
	return;
    }
    $self->status_message("Finished creating scaffolds fasta file");


    #create supercontigs.agp file
    $self->status_message("Creating  agp file");
    my $agp = Genome::Model::Tools::Soap::CreateSupercontigsAgpFile->create(
	scaffold_fasta_file => $self->build->soap_scaffold_sequence_file,
	assembly_directory => $self->build->data_directory,
	output_file => $self->build->data_directory.'/edit_dir/'.$root_file_name.'.agp',
	);
    unless ($agp->execute) {
	$self->error_message("Failed to successfully execute creating agp file");
	return;
    }
    $self->status_message("Finished creating agp file");

    #TODO - need a method to grab these when there will be more than just these two
    my @input_fastqs = ($self->build->end_one_fastq_file, $self->build->end_two_fastq_file);

    #create stats
    $self->status_message("Creating stats.txt file");
    my $stats = Genome::Model::Tools::Soap::Stats->create(
	assembly_directory => $self->build->data_directory,
	input_fastq_files => \@input_fastqs,
	contigs_bases_file => $self->build->data_directory.'/edit_dir/'.$root_file_name.'.contigs.fa',
	);
    unless ($stats->execute) {
	$self->error_message("Failed to run stats successfully");
	return;
    }
    $self->status_message("Finished creating stats.txt file");

    return 1;
}

1;
