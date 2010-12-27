package Genome::Model::Tools::Soap::StandardOutputs;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Soap::StandardOutputs {
    is => 'Genome::Model::Tools::Soap',
    has => [
	assembly_directory => {
	    is => 'Text',
	    doc => 'Input assembly directory',
	},
    ],
};

sub help_brief {
    'Tool to create default post assembly output files, including contigs.bases, supercontigs.fasta, supercontigs.agp and stats.txt files';
}

sub help_detail {
    return <<"EOS"
gmt soap standard-outputs --assembly-directory /gscmnt/111/soap_assembly
EOS
}

sub execute {
    my $self = shift;

    #create edit_dir to place output files
    Genome::Utility::FileSystem->create_directory($self->assembly_directory.'/edit_dir') unless
	-d $self->assembly_directory.'/edit_dir';

    #create contigs files
    $self->status_message("Creating contigs fasta file");
    my $contigs = Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
	scaffold_fasta_file => $self->assembly_scaffold_fasta_file,
        assembly_directory => $self->assembly_directory,
    );
    unless ($contigs->execute) {
        $self->error_message("Failed to successfully execute creating contigs fasta file");
        return;
    }
    $self->status_message("Finished creating contigs fasta file");
    

    #create scaffold fasta file
    $self->status_message("Creating supercontigs fasta file");
    my $supercontigs = Genome::Model::Tools::Soap::CreateSupercontigsFastaFile->create(
	scaffold_fasta_file => $self->assembly_scaffold_fasta_file,
        assembly_directory => $self->assembly_directory,
    );
    unless ($supercontigs->execute) {
        $self->error_message("Failed to successfully execute creating scaffolds fasta file");
        return;
    }
    $self->status_message("Finished creating scaffolds fasta file");


    #create scaffold agp file
    $self->status_message("Creating supercontigs agp file");
    my $agp = Genome::Model::Tools::Soap::CreateSupercontigsAgpFile->create(
	scaffold_fasta_file => $self->assembly_scaffold_fasta_file,
        assembly_directory => $self->assembly_directory,
    );
    unless ($agp->execute) {
        $self->error_message("Failed to successfully execute creating agp file");
        return;
    }
    $self->status_message("Finished creating agp file");


    #create stats
    $self->status_message("Creating stats.txt file");
    my $stats = Genome::Model::Tools::Soap::Stats->create(
        assembly_directory => $self->assembly_directory,
	input_fastq_files => $self->assembly_input_fastq_files,
	contigs_bases_file => $self->contigs_bases_file,
	);
    unless ($stats->execute) {
        $self->error_message("Failed to run stats successfully");
        return;
    }
    $self->status_message("Finished creating stats.txt file");
    
    return 1;
}

1;
