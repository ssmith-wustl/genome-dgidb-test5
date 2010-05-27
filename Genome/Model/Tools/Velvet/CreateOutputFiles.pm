package Genome::Model::Tools::Velvet::CreateOutputFiles;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Velvet::CreateOutputFiles {
    is => 'Command',
    has => [
	directory => {
	    is => 'Text',
	    doc => 'Assembly directory',
	},
	input_fastq_file => {
	    is => 'Text',
	    doc => 'Input fastq file',
	}
    ],
};

sub help_brief {
    "Tools to create complete set of assembly output files for velvet";
}

sub help_synopsis {
    return <<"EOS"
gmt velvet create-assembly-out-files --directory /foo/bar --input-fastq-file /foo/bar/file.fastq
EOS
}

sub help_detail {
    return <<EOS
Wrapper to run tools to create standard assembly output files
EOS
}

sub execute {
    my $self = shift;

    unless (-d $self->directory) {
	$self->error_message("Invalid directory: ".$self->directory);
	return;
    }

    unless (-s $self->input_fastq_file) {
	$self->error_message("Can not find input file: ".$self->input_fastq_file);
	return;
    }

    #TODO - validate directory and input file

#    my @class_names = qw/ Gap InputFromFastq/;
#    foreach my $class_name (@class_names) {
#	my %params = (
#	    directory => $self->directory,
#	    );
	#execptions where additional params are needed;
#	if ($class_name eq 'InputFromFastq') {
#	    $params{fastq_file} = $self->input_file;
#	}
#	my $cmd = Genome::Model::Tools::Assembly::CreateOutputFiles::$class_name->create(%params);
#	unless ($cmd->execute) {
#	    $self->error_message("Execute failed to create ".$class_name." file");
#	    return;
#	}
#    }

    ##########################################################
    # each of the modules being called have individual tests #
    ##########################################################

    #create gap.txt file
    my $gap = Genome::Model::Tools::Assembly::CreateOutputFiles::Gap->create(
	directory => $self->directory,
	);
    unless ($gap->execute) {
	$self->error_message("Execute failed to to create gap.txt file");
	return;
    }

    #create input fasta and qual files
    my $inputs = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
	fastq_file => $self->input_fastq_file,
	directory => $self->directory,
	);
    unless ($inputs->execute) {
	$self->error_message("Execute failed to create input files");
	return;
    }

    #create contigs.bases and contigs.qual files
    my $contigs = Genome::Model::Tools::Assembly::CreateOutputFiles::ContigsFromAce->create(
	directory => $self->directory,
	);
    unless ($contigs->execute) {
	$self->error_message("Execute failed to create contigs files");
	return;
    }

    #create readinfo.txt file
    my $read_info = Genome::Model::Tools::Assembly::CreateOutputFiles::ReadInfo->create(
	directory => $self->directory,
	);
    unless ($read_info->execute) {
	$self->error_message("Execute failed to create readInfo.txt file");
	return;
    }

    #create reads.placed file
    my $reads_placed = Genome::Model::Tools::Assembly::CreateOutputFiles::ReadsPlaced->create(
	directory => $self->directory,
	);
    unless ($reads_placed->execute) {
	$self->error_message("Execute failed to create reads.placed file");
	return;
    }

    #create supercontigs.gap file
    my $supercontigs_agp = Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsAgp->create(
	directory => $self->directory,
	);
    unless ($supercontigs_agp->execute) {
	$self->error_message("Execute failed to create supercontigs.agp file");
	return;
    }

    #create supercontigs.fasta file
    my $supercontigs_fa = Genome::Model::Tools::Assembly::CreateOutputFiles::SupercontigsFasta->create(
	directory => $self->directory,
	);
    unless ($supercontigs_fa->execute) {
	$self->error_message("Execute failed to create supercontigs.fasta file");
	return;
    }

    #create core_gene_survey output
    #this is probably not needed for velvet assemblies .. check with requesters first

    #stats
    my $stats = Genome::Model::Tools::Assembly::Stats::Velvet->execute(
	assembly_directory => $self->directory.'/edit_dir',
	out_file => 'stats.txt',
	);
    unless ($stats) {
	$self->error_message("Failed to create stats");
	return;
    }

    return;
}

1;
