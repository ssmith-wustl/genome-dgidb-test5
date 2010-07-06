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
    chomp (my $time = `date "+%a %b %e %T %Y"`);

    #make ace file .. 
    my $to_ace = Genome::Model::Tools::Velvet::ToAce->create(
        #these files are validated in ToAce mod
        seq_file => $self->build->sequences_file,
        afg_file => $self->build->assembly_afg_file,
        time => $time,
        out_acefile => $self->build->velvet_ace_file,
	#sqlite_yes => 1,  #<-----
    );
    unless ($to_ace->execute) {
        $self->error_message("Failed to run velvet-to-ace");
        return;
    }

    #create gap.txt file
    my $gap = Genome::Model::Tools::Velvet::CreateGapFile->create(
	contigs_fasta_file => $self->build->contigs_fasta_file,
        directory => $self->build->data_directory,
        );
    unless ($gap->execute) {
        $self->error_message("Execute failed to to create gap.txt file");
        return;
    }

    #create input fasta and qual files #TODO - move this to tools/velvet
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
        fastq_file => $self->build->collated_fastq_file,
        directory => $self->build->data_directory,
        );
    unless ($inputs->execute) {
        $self->error_message("Execute failed to create input files");
        return;
    }

    #create contigs.bases and contigs.quals files
    my $contigs = Genome::Model::Tools::Velvet::CreateContigsFiles->create (
	afg_file => $self->build->assembly_afg_file,
	directory => $self->build->data_directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Failed to execute creating contigs.bases and quals files");
	return;
    }

    #create reads.placed and readinfo.txt files
    my $reads = Genome::Model::Tools::Velvet::CreateReadsFiles->create (
	sequences_file => $self->build->sequences_file,
	afg_file => $self->build->assembly_afg_file,
	directory => $self->build->data_directory,
	);
    unless ($reads->execute) {
	$self->error_message("Failed to execute creating reads files");
	return;
    }

    #create supercontigs.fasta and supercontigs.agp file
    my $supercontigs = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
	contigs_fasta_file => $self->build->contigs_fasta_file,
	directory => $self->build->data_directory,
	);
    unless ($supercontigs->execute) {
	$self->error_message("Failed execute creating of supercontigs files");
	return;
    }

    #create stats;
    my $stats = Genome::Model::Tools::Assembly::Stats::Velvet->execute (
        assembly_directory => $self->build->data_directory.'/edit_dir',
        out_file => 'stats.txt',
        no_print_to_screen => 1,
        );
    unless ($stats) {
        $self->error_message("Failed to create stats");
        return;
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
