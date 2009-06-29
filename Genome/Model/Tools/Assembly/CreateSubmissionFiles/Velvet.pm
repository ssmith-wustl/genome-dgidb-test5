package Genome::Model::Tools::Assembly::CreateSubmissionFiles::Velvet;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Assembly::CreateSubmissionFiles::Velvet {
    is => 'Genome::Model::Tools::Assembly::CreateSubmissionFiles',
    has => [
	    directory => {
		is => 'String',
		doc => 'path to velvet assembly main directory or current directory',
		is_optional => 1,
	    },
	    fastq_file => {
		is => 'String',
		doc => 'full path to velvet assembly fastq file',
		is_optional => 0,
	    },
	    ace => {
		is => 'String',
		doc => 'Input velvet ace file',
		is_optional => 1,
	    },
	    gap_file => {
		is => 'String',
		doc => 'Updated gap file',
		is_optional => 1,
	    },
	    archaea => {
		is => 'Boolean',
		doc => 'Core gene survey -arachaea option',
		is_optional => 1,
	    },
     ],
};

sub help_brief {
    'Tool to create pcap-like submission files from velvet assembly'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly create-submission-files velvet
EOS
}

sub help_detail {
    return <<EOS
Tool to create pcap-like submission files from velvet assembly
EOS
}

sub execute {
    my $self = shift;

    unless ($self->change_to_assembly_dir()) {
	$self->error_message("Failed to change to assembly directory");
	return;
    }

    my $ace_file;
    unless ($ace_file = $self->_resolve_ace_to_use()) {
	$self->error_message("Failed to resolve which ace file to use");
	return;
    }

    my $ace_obj;
    unless ($ace_obj = $self->get_ace_obj($ace_file)) {
	$self->error_message("Failed to get ace object");
	return;
    }

    unless ($self->create_contigs_files($ace_obj)) {
	$self->error_message("Failed to create contigs files");
	return;
    }

    my $gap_file;
    unless ($gap_file = $self->_resolve_gap_file_to_use()) {
	$self->error_message("Failed to resolve which gap file to use");
	return;
    }

    #CREATES READS.PLACED AND READINFO.TXT FILES
    unless ($self->create_read_info_files($ace_obj, $gap_file)) {
	$self->error_message("Failed to create reads info files");
	return;
    }

    unless (-s $self->fastq_file) {
	$self->error_message("Failed to find fastq file");
	return;
    }
    #CREATES INPUT FASTA AND QUAL AND READS.UNPLACED.FASTA AND READS.UNPLACED.FOF
    unless ($self->create_input_from_fastq($self->fastq_file)) {
	$self->error_message("Failed to create input files from fastq");
	return;
    }

    unless ($self->create_supercontigs_agp_file($gap_file)) {
	$self->error_message("Failed to create supercontigs.agp file");
	return;
    }

    unless ($self->create_supercontigs_fa_file()) {
	$self->error_message("Failed to create supercontigs.fasta file");
	return;
    }

    my $survey_option = ($self->archaea) ? '-arachaea' : '-bact' ;

    unless($self->run_core_gene_survey($survey_option)) {
	$self->error_message("Failed to run core gene survey");
	return;
    }

    return 1;
}


sub _resolve_ace_to_use {
    my $self = shift;
    my $ace = ($self->ace) ? $self->ace : 'velvet_asm.ace';
    unless (-s $ace) {
	$self->error_message("Unable to find ace file: $ace");
	    return;
    }
    return $ace;
}

sub _resolve_gap_file_to_use {
    my $self = shift;
    my $gap_file = ($self->gap_file) ? $self->gap_file : 'velvet.gap.txt';
    unless (-s $gap_file) {
	$self->error_message("Unable to find gap file: $gap_file");
	return;
    }
    return $gap_file;
}

1;
