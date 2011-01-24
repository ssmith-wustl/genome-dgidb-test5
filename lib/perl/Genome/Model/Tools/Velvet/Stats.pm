package Genome::Model::Tools::Velvet::Stats;

use strict;
use warnings;

use Genome;
use Cwd;
use Data::Dumper;

class Genome::Model::Tools::Velvet::Stats {
    is => ['Genome::Model::Tools::Assembly::Stats'],
    has => [
	first_tier => {
	    type => 'int non_neg',
	    is_optional => 1,
	    doc => "first tier value",
	},
	second_tier => {
	    type => 'int non_neg',
	    is_optional => 1,
	    doc => "second tier value",
	},
	assembly_directory => {
	    type => 'Text',
	    is_optional => 1,
	    doc => "path to assembly",
	},
	major_contig_length => {
	    type => 'int non_neg',
	    is_optional => 1,
	    default_value => 500,
	    doc => "Major contig length cutoff",
	},
	out_file => { #TODO - rename this output_file
	    type => 'Text',
	    is_optional => 1,
	    is_mutable => 1,
	    doc => "Stats output file name",
	},
	no_print_to_screen => {
	    is => 'Boolean',
	    is_optional => 1,
	    default_value => 0,
	    doc => 'Prevent printing of stats to screen',
	},
	msi_assembly => {
	    is => 'Boolean',
	    is_optional => 1,
	    default_value => 0,
	    doc => 'Denote msi assemblies',
	},
	report_core_gene_survey => {
	    is => 'Boolean',
	    is_optional => 1,
	    default_value => 0,
	    doc => 'Reports core gene survey results',
	},
    ],
};

sub help_brief {
    'Run stats on velvet assemblies'
}

sub help_detail {
    return <<"EOS"
gmt assemby stats velvet --assembly-directory /gscmnt/sata910/assembly/Escherichia_coli_HMPREF9530-1.0_100416.vel
gmt assemby stats velvet --assembly-directory /gscmnt/sata910/assembly/Escherichia_coli_HMPREF9530-1.0_100416.vel --out-file stats.txt --no-print-to-screen
gmt assemby stats velvet --assembly-directory /gscmnt/sata910/assembly/Escherichia_coli_HMPREF9530-1.0_100416.vel --out-file stats.txt --first-tier 1000000 --second-tier 1200000 --major-contig-length 2000
EOS
}

sub execute {
    my $self = shift;

    my $stats; #holds streams of incoming stats text

    unless ( $self->create_edit_dir ) {
	$self->error_message("Failed to create edit_dir in assembly directory");
	return;
    }

    unless ( $self->check_existing_post_asm_files ) {
	$self->error_message("Failed to create necessary files to run stats");
	return;
    }

    unless ($self->validate_assembly_out_files) {
	$self->error_message("Failed to validate assembly out files");
	return;
    }

    unless ($self->validate_velvet_assembly_files) {
	$self->error_message("Failed to validate velvet assembly files");
	return;
    }

    #SIMPLE READ STATS
    my ($s_stats, $five_k_stats, $content_stats) = $self->get_simple_read_stats();
    $stats .= $s_stats;
    print $s_stats unless $self->no_print_to_screen;

    #CONTIGUITY STATS
    my $contiguity_stats = $self->get_contiguity_stats;
    $stats .= $contiguity_stats;
    print $contiguity_stats unless $self->no_print_to_screen;

    #CONSTRAINT STATS
    my $constraint_stats = $self->get_constraint_stats();
    $stats .= $constraint_stats;
    print $constraint_stats unless $self->no_print_to_screen;

    #GENOME CONTENTS
    $stats .= $content_stats;
    print $content_stats unless $self->no_print_to_screen;

    #GENE CORE SURVEY STATS - This is optional
    if ($self->report_core_gene_survey) {
	my $core_survey = $self->get_core_gene_survey_results();
	$stats .= $core_survey;
	print $core_survey unless $self->no_print_to_screen;
    }

    #READ DEPTH STATS
    my $depth_stats = $self->get_read_depth_stats_from_afg();
    $stats .= $depth_stats;
    print $depth_stats unless $self->no_print_to_screen;

    #FIVE KB CONTIG STATS
      $stats .= $five_k_stats;
    print $five_k_stats unless $self->no_print_to_screen;

    unless ($self->out_file) {
	$self->out_file($self->assembly_directory.'/edit_dir/stats.txt');
    }

    if ($self->out_file) {
	my $out_file = $self->out_file;
	unlink $self->out_file;
	my $fh = Genome::Sys->open_file_for_writing($self->out_file) ||
	    return;
	$fh->print($stats);
	$fh->close;
    }

    print "############\n##  DONE  ##\n############\n" unless $self->no_print_to_screen;

    return 1;
}

sub check_existing_post_asm_files {
    my $self = shift;

    my $dir = $self->assembly_directory.'/edit_dir';

    #input qual file
    unless ( $self->get_input_qual_files ) {
	my $tool = Genome::Model::Tools::Assembly::CreateOutputFiles::InputFromFastq->create(
	    directory => $self->assembly_directory,
	    fastq_file => $self->_get_input_fastq_file,
	    );
	unless ( $tool->execute ) {
	    $self->error_message("Failed to create fasta/qual files from input fastq for stats");
	    return;
	}
    }
    #contigs files
    unless ( -s $dir.'/contigs.bases' and -s $dir.'/contigs.quals' ) {
	my $tool = Genome::Model::Tools::Velvet::CreateContigsFiles->create(
	    assembly_directory => $self->assembly_directory,
	    );
	unless( $tool->execute ) {
	    $self->error_message("Failed to create contigs bases/quals files for stats");
	    return;
	}
    }
    #gap file
    unless ( -e $dir.'/gap.txt' ) {
	my $tool = Genome::Model::Tools::Velvet::CreateGapFile->create(
	    assembly_directory => $self->assembly_directory,
	    );
	unless( $tool->execute ) {
	    $self->error_message("Failed to create gap.txt file for stats");
	    return;
	}
    }
    #reads files
    unless ( -s $dir.'/readinfo.txt' and -s $dir.'/reads.placed' ) {
	my $tool = Genome::Model::Tools::Velvet::CreateReadsFiles->create(
	    assembly_directory => $self->assembly_directory,
	    );
	unless( $tool->execute ) {
	    $self->error_message("Failed to create readinfo and reads.placed files for stats");
	    return;
	}
    }
    

    return 1;
}

sub _get_input_fastq_file {
    my $self = shift;

    my @fastq = glob( $self->assembly_directory."/*fastq" );

    unless( @fastq == 1 ) {
	$self->error_message("Expected 1 input fastq file but got: ".scalar @fastq." @fastq");
	return;
    }

    return $fastq[0];
}

1;
