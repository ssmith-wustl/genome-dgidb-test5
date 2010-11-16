package Genome::Model::Tools::Velvet::StandardOutputs;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Tools::Velvet::StandardOutputs {
    is => 'Command',
    has => [
	assembly_directory => {
	    is => 'Text',
	    doc => 'Directory where the assembly is located',
	},
    ],
    has_optional_transient => [
	_afg_file            => { is => 'Text', },
	_contigs_fasta_file  => { is => 'Text', },
	_collated_fastq_file => { is => 'Text', },
	_sequences_file      => { is => 'Text', },
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

    unless ( $self->_verify_assembly_files_exist_and_set_transient_params ) {
	$self->error_message("Failed to validate that assembly files exist");
	return;
    }

    unless ( $self->_create_output_files ) {
	$self->error_messag("Failed to create output files");
	return;
    }

    return 1;
}

sub _verify_assembly_files_exist_and_set_transient_params {
    my $self = shift;

    for my $method ( $self->_file_set_methods ) {
	unless ( $self->$method ) {
	    $self->error_message("Failed to run method, $method, to validate assembly files");
	    return;
	}
    }

    return 1;
}

sub _file_set_methods {
    return qw/ 
               _set_assembly_afg_file
               _set_contigs_fasta_file
               _set_collated_fastq_file
               _set_sequences_file
            /;
}

sub _set_assembly_afg_file {
    my $self = shift;

    return unless -s $self->assembly_directory.'/velvet_asm.afg';

    $self->_afg_file( $self->assembly_directory.'/velvet_asm.afg' );

    return 1;
}

sub _set_contigs_fasta_file {
    my $self = shift;

    return unless -s $self->assembly_directory.'/contigs.fa';

    $self->_contigs_fasta_file( $self->assembly_directory.'/contigs.fa');

    return 1;
}

sub _set_collated_fastq_file {
    my $self = shift;

    my @files = glob( $self->assembly_directory."/*collated.fastq" );
    unless ( @files == 1 ) {
	$self->error_message("Found multiple input collated.fastq files .. expected one");
	return;
    }

    $self->_collated_fastq_file( $files[0] );

    return 1;
}

sub _set_sequences_file {
    my $self = shift;

    return unless -s $self->assembly_directory.'/Sequences';

    $self->_sequences_file( $self->assembly_directory.'/Sequences');

    return 1;
}

sub _create_output_files {
    my $self = shift;

    unless ( -d $self->assembly_directory.'/edit_dir' ) {
	Genome::Utility::FileSystem->create_directory( $self->assembly_directory.'/edit_dir' );
    }

    #create gap.txt file
    $self->status_message("Creating gap.txt file");
    my $gap = Genome::Model::Tools::Velvet::CreateGapFile->create(
	contigs_fasta_file => $self->_contigs_fasta_file,
        directory => $self->assembly_directory,
        );
    unless ($gap->execute) {
        $self->error_message("Execute failed to to create gap.txt file");
        return;
    }
    $self->status_message("Completed creating gap.txt file");


    #create input fasta and qual files #TODO - move this to tools/velvet
    $self->status_message("Creating fasta and qual files from input fastq");
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
        fastq_file => $self->_collated_fastq_file,
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
	afg_file => $self->_afg_file,
	directory => $self->assembly_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to execute creating contigs.bases and quals files");
	return;
    }
    $self->status_message("Completed creating contigs.bases and contigs.qual files");
    

    #create reads.placed and readinfo.txt files
    $self->status_message("Creating reads.placed and readinfo files");
    my $reads = Genome::Model::Tools::Velvet::CreateReadsFiles->create (
	sequences_file => $self->_sequences_file,
	afg_file => $self->_afg_file,
	directory => $self->assembly_directory,
	);
    unless ($reads->execute) {
	$self->error_message("Failed to execute creating reads files");
	return;
    }
    $self->status_message("Completed creating reads.placed and readinfo files");


    #create reads.unplaced and reads.unplaced.fasta files
    $self->status_message("Creating reads.unplaced and reads.unplaced.fasta files");
    my $unplaced = Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles->create (
   	sequences_file => $self->_sequences_file,
	afg_file => $self->_afg_file,
	directory => $self->assembly_directory,
	);
    unless ($unplaced->execute) {
	$self->error_message("Failed to execute creating reads.unplaced files");
	return;
    }
    $self->status_message("Completed creating reads.unplaced and reads.unplaced.fasta files");


    #create supercontigs.fasta and supercontigs.agp file
    $self->status_message("Creating supercontigs fasta and agp files");
    my $supercontigs = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
	contigs_fasta_file => $self->_contigs_fasta_file,
	directory => $self->assembly_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed execute creating of supercontigs files");
	return;
    }
    $self->status_message("Completed creating supercontigs.fasta and agp files");


    #create stats;
    $self->status_message("Creating stats");
    my $stats = Genome::Model::Tools::Assembly::Stats::Velvet->execute (
	assembly_directory => $self->assembly_directory,
        no_print_to_screen => 1,
        );
    unless ($stats) {
        $self->error_message("Failed to create stats");
        return;
    }
    $self->status_message("Completed creating stats");

    return 1;
}

1;
