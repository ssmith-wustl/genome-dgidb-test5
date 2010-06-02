package Genome::Model::Tools::Assembly::Stats::Velvet;

use strict;
use warnings;

use Genome;
use Cwd;
use Data::Dumper;

class Genome::Model::Tools::Assembly::Stats::Velvet {
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
	    doc => "Major contig length cutoff",
	},
	out_file => { #TODO - rename this output_file
	    type => 'Text',
	    is_optional => 1,
	    doc => "Stats output file name",
	},
	no_print_to_screen => {
	    is => 'Boolean',
	    is_optional => 1,
	    default_value => 0,
	    doc => 'Prevent printing of stats to screen',
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
    my ($self) = @_;
    my $stats;

    #TODO - just have one print and one print to stats file statement

    #TODO - fix so this doesn't run in edit_dir .. tests can not clean up
    my $dir = cwd();

    unless ($self->resolve_data_directory()) {
	$self->error_message("Unable to resolve data directory");
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

    #GENE CORE SURVEY STATS
    #my $core_survey = $self->get_core_gene_survey_results();
    #$stats .= $core_survey;
    #print $core_survey unless $self->no_print_to_screen;

    #READ DEPTH STATS
    my $ace = `ls -t velvet_asm.ace* | grep -v base_depth | head -1`;
    chomp $ace;
    unless ($ace) {
	$self->error_message("Can not find any velvet_asm.ace ace files");
	return;
    }
    my $depth_stats = $self->get_read_depth_stats($ace);
    $stats .= $depth_stats;
    print $depth_stats unless $self->no_print_to_screen;

    #FIVE KB CONTIG STATS
    $stats .= $five_k_stats;
    print $five_k_stats unless $self->no_print_to_screen;

    if ($self->out_file) {
	my $out_file = $self->out_file;
	my $fh = IO::File->new(">$out_file") || die;
	$fh->print($stats);
	$fh->close;
    }

    print "############\n##  DONE  ##\n############\n" unless $self->no_print_to_screen;

    #returning to original dir so tests can clean up
    chdir $dir;

    return 1;
}

1;
