package Genome::Model::Tools::Velvet::StandardOutputs;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Velvet::StandardOutputs {
    is => 'Genome::Model::Tools::Velvet',
    has => [
	assembly_directory => {
	    is => 'Text',
	    doc => 'Directory where the assembly is located',
	},
    ],
};


sub help_brief {
    "Tool to create default post assembly output files for velvet assembly";
}

sub help_detail {
    return <<"EOS"
gmt velvet standard-outputs --assembly-directory /gscmnt/111/velvet_assembly
EOS
}

sub execute {
    my $self = shift;

    unless ( -d $self->assembly_directory ) {
	$self->error_message("Failed to find assembly directory: ".$self->assembly_directory);
	return;
    }

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir");
	return;
    }

    #create gap.txt file
    $self->status_message("Creating gap.txt file");
    my $gap = Genome::Model::Tools::Velvet::CreateGapFile->create(
        assembly_directory => $self->assembly_directory,
        );
    unless ($gap->execute) {
        $self->error_message("Execute failed to to create gap.txt file");
        return;
    }
    $self->status_message("Completed creating gap.txt file");

    #create input fasta and qual files #TODO - move this to tools/velvet
    $self->status_message("Creating fasta and qual files from input fastq");
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
	fastq_file => $self->input_collated_fastq_file,
        directory => $self->assembly_directory,
        );
    unless ($inputs->execute) {
        $self->error_message("Execute failed to create input files");
        return;
    }
    $self->status_message("Completed creating fasta/qual from input fastq");


    #create contigs.bases and contigs.quals files
    $self->status_message("Creating contigs.bases and contigs.quals files");
    my $contigs = Genome::Model::Tools::Velvet::CreateContigsFiles->create (
	assembly_directory => $self->assembly_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to execute creating contigs.bases and quals files");
	return;
    }
    $self->status_message("Completed creating contigs.bases and contigs.qual files");
    

    #create reads.placed and readinfo.txt files
    $self->status_message("Creating reads.placed and readinfo files");
    my $reads = Genome::Model::Tools::Velvet::CreateReadsFiles->create (
	assembly_directory => $self->assembly_directory,
	);
    unless ($reads->execute) {
	$self->error_message("Failed to execute creating reads files");
	return;
    }
    $self->status_message("Completed creating reads.placed and readinfo files");


    #create reads.unplaced and reads.unplaced.fasta files
    $self->status_message("Creating reads.unplaced and reads.unplaced.fasta files");
    my $unplaced = Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles->create (
	assembly_directory => $self->assembly_directory,
	);
    unless ($unplaced->execute) {
	$self->error_message("Failed to execute creating reads.unplaced files");
	return;
    }
    $self->status_message("Completed creating reads.unplaced and reads.unplaced.fasta files");


    #create supercontigs.fasta and supercontigs.agp file
    $self->status_message("Creating supercontigs fasta and agp files");
    my $supercontigs = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
	assembly_directory => $self->assembly_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed execute creating of supercontigs files");
	return;
    }
    $self->status_message("Completed creating supercontigs.fasta and agp files");

    return 1;
}

1;
