package Genome::Model::Tools::Velvet::CreateStdoutFiles;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Velvet::CreateStdoutFiles {
    is => 'Command',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
	input_fastq_file => {
	    is => 'Text',
	    doc => 'Input fastq file',
	},
	queue => {
	    is => 'Boolean',
	    doc => 'Submits job to lsf queue',
	    is_optional => 1,
	},
    ],
};

sub help_brief {
    "Tools to create complete set of assembly output files for velvet";
}

sub help_synopsis {
    return <<"EOS"
gmt velvet create-stdout-files --directory /foo/bar --input-fastq-file /foo/bar/file.fastq
EOS
}

sub help_detail {
    return <<EOS
Wrapper to run tools to create standard assembly output files
EOS
}

sub execute {
    my $self = shift;

    #check input directory and velvet output files
    unless ($self->_validate_assembly()) {
	$self->error_message("Failed to validate input assembly");
	return;
    }

    if ($self->queue) {
	unless ($self->_submit_to_lsf) {
	    $self->error_message("Failed to submit job to lsf queue");
	    return;
	}
	return 1;
    }


    #check for gap.txt which maybe be there with ace file
    unless (-s $self->directory.'/edit_dir/gap.txt') {
	my $gap = Genome::Model::Tools::Assembly::CreateOutputFiles::Gap->create(
	    directory => $self->directory,
	    );
	unless ($gap->execute) {
	    $self->error_message("Execute failed to to create gap.txt file");
	    return;
	}
    }

    #create input fasta and qual files #TODO - move this to tools/velvet
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
        fastq_file => $self->input_fastq_file,
        directory => $self->directory,
        );
    unless ($inputs->execute) {
        $self->error_message("Execute failed to create input files");
        return;
    }

    #create contigs.bases and contigs.quals files
    my $contigs = Genome::Model::Tools::Velvet::CreateContigsFiles->create (
        afg_file => $self->directory.'/velvet_asm.afg',
        directory => $self->directory,
        );
    unless ($contigs->execute) {
        $self->error_message("Failed to execute creating contigs.bases and quals files");
        return;
    }

    #create reads.placed and readinfo.txt files
    my $reads = Genome::Model::Tools::Velvet::CreateReadsFiles->create (
        sequences_file => $self->directory.'/Sequences',
        afg_file => $self->directory.'/velvet_asm.afg',
        directory => $self->directory,
        );
    unless ($reads->execute) {
        $self->error_message("Failed to execute creating reads files");
        return;
    }

    #create reads.unplaced and reads.unplaced.fasta files
    my $unplaced = Genome::Model::Tools::Velvet::CreateUnplacedReadsFiles->create (
	sequences_file => $self->directory.'/Sequences',
	afg_file => $self->directory.'/velvet_asm.afg',
	directory => $self->directory,
	);
    unless ($unplaced->execute) {
	$self->error_message("Failed to execute creating unplaced reads files");
	return;
    }

    #create supercontigs.fasta and supercontigs.agp file
    my $supercontigs = Genome::Model::Tools::Velvet::CreateSupercontigsFiles->create (
        contigs_fasta_file => $self->directory.'/contigs.fa',
        directory => $self->directory,
        );
    unless ($supercontigs->execute) {
        $self->error_message("Failed execute creating of supercontigs files");
        return;
    }

    #create stats;
    my $stats = Genome::Model::Tools::Assembly::Stats::Velvet->create (
	assembly_directory => $self->directory,
        no_print_to_screen => 1,
        );
    unless ($stats->execute) {
        $self->error_message("Failed to create stats");
        return;
    }

    #check for ace file .. it not run velvet to-ace
    chomp (my $time = `date "+%a %b %e %T %Y"`);
    unless (-s $self->directory.'/edit_dir/velvet_asm.ace') {
	$self->status_message("Running velvet to ace to create ace file");
	my $to_ace = Genome::Model::Tools::Velvet::ToAce->create(
	    #these files are validated in ToAce mod
	    seq_file => $self->directory.'/Sequences',
	    afg_file => $self->directory.'/velvet_asm.afg',
	    time => $time,
	    out_acefile => $self->directory.'/edit_dir/velvet_asm.ace',
	    # sqlite_yes => 1,  #<----- #will cause it to fail if # reads > 2.5 million
	    );
	unless ($to_ace->execute) {
	    $self->error_message("Failed to run velvet-to-ace");
	    return;
	}
    }

    return 1;
}

sub _submit_to_lsf {
    my $self = shift;

    my $input_fastq = $self->input_fastq_file;
    my $directory = $self->directory;

    my $job = PP::LSF->run (
        pp_type => "lsf",
        command => "gmt velvet create-stdout-files --input-fastq-file $input_fastq --directory $directory",
        J => 'Velvet_std_out',
	R => "'select[type==LINUX64] span[hosts=1]'",
	u => $ENV{USER}.'@watson.wustl.edu',
	);
    unless ($job) {
	return;
    }

    return 1;
}

sub _validate_assembly {
    my $self = shift;

    unless (-d $self->directory) {
	$self->error_message("Invalid input assembly directory: ".$self->directory);
	return;
    }
    unless (-s $self->input_fastq_file) {
	$self->error_message("Can't find input fastq file: ".$self->input_fastq_file);
	return;
    }
    #make sure all necessary velvet output files are 
    foreach (qw/ velvet_asm.afg contigs.fa Sequences /) {
	unless (-s $self->directory."/$_") {
	    $self->error_message("Failed to find velvet output file: ".$self->directory."/$_");
	    return;
	}
    }
    #make edit_dir if it doesn't exist
    unless (-d $self->directory.'/edit_dir') {
	Genome::Utility::FileSystem->create_directory($self->directory.'/edit_dir') ||
	    return;
    }
    return 1;
}

1;
