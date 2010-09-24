package Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PostAssemble::Velvet {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PostAssemble',
};

sub execute {
    my $self = shift;

    #this is probably not necessary to do here
    unless (-d $self->build->data_directory) {
        $self->error_message("Invalid build data directory: ".$self->build->data_directory);
        return;
    }

    Genome::Utility::FileSystem->create_directory($self->build->edit_dir);
    #chomp (my $time = `date "+%a %b %e %T %Y"`);

    #create gap.txt file
    $self->status_message("Creating gap.txt file");
    my $gap = Genome::Model::Tools::Velvet::CreateGapFile->create(
	contigs_fasta_file => $self->build->contigs_fasta_file,
        directory => $self->build->data_directory,
        );
    unless ($gap->execute) {
        $self->error_message("Execute failed to to create gap.txt file");
        return;
    }
    $self->status_message("Completed creating gap.txt file");


    #create input fasta and qual files #TODO - move this to tools/velvet
    $self->status_message("Creating fasta and qual files from input fastq");
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
        fastq_file => $self->build->collated_fastq_file,
        directory => $self->build->data_directory,
        );
    unless ($inputs->execute) {
        $self->error_message("Execute failed to create input files");
        return;
    }
    $self->status_message("Completed creating fasta/qual from input fastq");


    #create contigs.bases and contigs.quals files
    $self->status_message("Creating contigs.bases and contigs.quals files");
    my $contigs = Genome::Model::Tools::Velvet::CreateContigsFiles->create (
	afg_file => $self->build->assembly_afg_file,
	directory => $self->build->data_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to execute creating contigs.bases and quals files");
	return;
    }
    $self->status_message("Completed creating contigs.bases and contigs.qual files");
    

    #create reads.placed and readinfo.txt files
    $self->status_message("Creating reads.placed and readinfo files");
    my $reads = Genome::Model::Tools::Velvet::CreateReadsFiles->create (
	sequences_file => $self->build->sequences_file,
	afg_file => $self->build->assembly_afg_file,
	directory => $self->build->data_directory,
	);
    unless ($reads->execute) {
	$self->error_message("Failed to execute creating reads files");
	return;
    }
    $self->status_message("Completed creating reads.placed and readinfo files");


    #create reads.unplaced and reads.unplaced.fasta files
    $self->status_message("Creating reads.unplaced and reads.unplaced.fasta files");
    my $unplaced = Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles->create (
   	sequences_file => $self->build->sequences_file,
	afg_file => $self->build->assembly_afg_file,
	directory => $self->build->data_directory,
	);
    unless ($unplaced->execute) {
	$self->error_message("Failed to execute creating reads.unplaced files");
	return;
    }
    $self->status_message("Completed creating reads.unplaced and reads.unplaced.fasta files");


    #create supercontigs.fasta and supercontigs.agp file
    $self->status_message("Creating supercontigs fasta and agp files");
    my $supercontigs = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
	contigs_fasta_file => $self->build->contigs_fasta_file,
	directory => $self->build->data_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed execute creating of supercontigs files");
	return;
    }
    $self->status_message("Completed creating supercontigs.fasta and agp files");


    #create stats;
    $self->status_message("Creating stats");
    my $stats = Genome::Model::Tools::Assembly::Stats::Velvet->execute (
	assembly_directory => $self->build->data_directory,
        no_print_to_screen => 1,
        );
    unless ($stats) {
        $self->error_message("Failed to create stats");
        return;
    }
    $self->status_message("Completed creating stats");

    #ACE FILES NO LONGER WANTED

    #make ace file .. 
    #$self->status_message("Writing ace file");
    #eval {
	#my $to_ace = Genome::Model::Tools::Velvet::ToAce->create(
	    #these files are validated in ToAce mod
	    #seq_file => $self->build->sequences_file,
	    #afg_file => $self->build->assembly_afg_file,
	    #time => $time,
	    #out_acefile => $self->build->velvet_ace_file,
	    #sqlite_yes => 1,  #<----- can't do if # reads gt 2,500,000
	    #);
	#unless ($to_ace->execute) {
	    #$self->error_message("Failed to run velvet-to-ace");
	    #return;
	#}
    #};
    #if ($@) {
	#$self->error_message("Failed to create ace file .. probably ran out of memory");
	#return;
    #} else {
	#$self->status_message("Completed writing ace file");
    #}

    return 1;
}

1;

#$HeadURL$
#$Id$
