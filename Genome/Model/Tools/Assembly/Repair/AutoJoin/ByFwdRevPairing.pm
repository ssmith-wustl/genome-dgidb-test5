package Genome::Model::Tools::Assembly::Repair::AutoJoin::ByFwdRevPairing;

use strict;
use warnings;
use Genome;

use Data::Dumper;
use Cwd;

use Finishing::Assembly::Factory;
use Finishing::Assembly::ContigTools;

use Sort::Naturally;

class Genome::Model::Tools::Assembly::Repair::AutoJoin::ByFwdRevPairing
{
    is => ['Genome::Model::Tools::Assembly::Repair::AutoJoin'],
    has => [ 
	     ace => {
		 type => 'String',
		 is_optional => 0,
		 doc => "input ace file name"        
		 },
	     dir => {
		 type => 'String',
		 is_optional => 1,
		 doc => "path to data if specified otherwise cwd"
		 },
	     min_length => {
		 type => 'String',
		 is_optional => 1,
		 doc => "minimum match length"        
		 }, 
	     max_length => {
		 type => 'String',
		 is_optional => 1,
		 doc => "maximum crossmatch length"        
		 },
	     min_read_num => {
		 type => 'String',
		 is_optional => 1,
		 doc => "minimum number of reads to support joins"        
		 },
	     cm_fasta_length => {
		 type => 'String',
		 is_optional => 1,
		 doc => "Length of sequences at each ends to run cross match"        
		 },
	     cm_min_match => {
		 type => 'String',
		 is_optional => 1,
		 doc => "Minimum length of cross match to consider for join"        
		 },
	     ],
};

sub help_brief {
    'Align contigs by fwd/rev pairing then autojoin'
}

sub help_detail {
    return <<"EOS"
	Align contigs by fwd/rev pairing
EOS
}

sub execute {
    my ($self) = @_;

    #RESOLVE PATH TO DATA
    if ($self->dir)
    {
	my $dir = $self->dir;
	$self->error_message("Path must be edit_dir") and return
	    unless $dir =~ /edit_dir$/;
	$self->error_message("Invalid dir path: $dir") and return
	    unless -d $dir;
	chdir ("$dir");
    }
    else
    {
	my $dir = cwd();
	$self->error_message("You must be in edit_dir") and return
	    unless $dir =~ /edit_dir$/;
    }

    #ACE FILE
    my $ace_in = $self->ace;

    #CHECK TO MAKE SURE ACE FILE EXISTS
    unless (-s $ace_in)
    {
	$self->error_message("Invalid ace file: $ace_in");
	return;
    }

    #CAT ALL PHDBALL FILES TOGETHER IF PRESENT SINCE PHDBALL FACTORY ONLY
    #WORK WITH SINGLE PHDBALL FILE
    #TODO - FIX THIS IN PHDBALL FACTORY
    unless ($self->cat_all_phdball_files)
    {
	$self->error_message("Cound not resolve phdball issues");
	return;
    }

    #DS LINE IN 454 ACE FILES HAS TO HAVE PHD_FILE: TRACE_NAME TO WORK W CONTIGTOOLS
    #THIS CREATES A NEW ACE FILE: $ace_in.DS_Line_fixed;
    #TODO - FIX THIS IN CONTIG TOOLS
    my $new_ace;
    unless ($new_ace = $self->add_phd_to_ace_DS_line ($ace_in))
    {
	$self->error_message("Cound not add PHD_FILE: READ_NAME to ace DS line");
	return;
    }

    #LOAD ACE OBJECT
    my ($ace_obj, $contig_tool);
    unless (($ace_obj, $contig_tool) = $self->_load_ace_obj ($new_ace))
    {
	$self->error_message("Unable to load ace object");
	return;
    }

    #GET GENERAL CONTIG INFO
    my $scaffolds;
    unless ($scaffolds = $self->get_contigs_info_from_ace ($ace_obj))
    {
	$self->error_message("Could not get contig info from ace");
	return;
    }

    #RUN CROSS MATCH
    unless ($self->_run_cross_match)
    {
	$self->error_message("Could not run cross_match");
	return;
    }

    print Dumper $scaffolds;

    #PRINT CONTIG END SEQUENCES TO RUN CROSS MATCH
    unless ($self->_print_contig_ends ($ace_obj, $scaffolds))
    {
	$self->error_message("Could not print contig ends for cross_match");
	return;
    } 

    my $reads_hash;
    unless ($reads_hash = $self->_get_reads($ace_obj))
    {
	$self->error_message("Could not get reads hash");
	return;
    }

    print Dumper $reads_hash;

    return 1;
}

sub _run_cross_match
{
    my ($self) = @_;

    my $min_match = 25;

    $min_match = $self->cm_min_match if $self->cm_min_match;
    
    return unless ($self->run_cross_match ($min_match));

    return 1;
}

sub _load_ace_obj
{
    my ($self, $ace) = @_;

    my $tool = Finishing::Assembly::ContigTools->new;

    my $fo = Finishing::Assembly::Factory->connect('ace', $ace);

    return $fo->get_assembly, $tool;
}

sub _print_contig_ends
{
    my ($self, $ao, $scaf_contigs) = @_;

    my $length = 500;

    $length = $self->cm_fasta_length if $self->cm_fasta_length;

    unless ($self->print_contig_ends ($ao, $scaf_contigs, $length))
    {
	$self->error_message("Failed to print contig ends for cross_match");
	return;
    }

    return 1;
}

sub _get_reads
{
    my ($self, $ace_obj) = @_;

    my $h = {}; #ALL READS HASH

    #TODO WE ONLY HAVE TO CARE ABOUT PAIRED READS

    foreach my $contig ($ace_obj->contigs->all)
    {
	print $contig->name."\n";
	my $reads = $contig->assembled_reads;
	my $read_count = 0;
	foreach my $read ($reads->all)
	{
	    $read_count++;
	    my $name = $read->name;

	    next unless $name =~ /\.[bg]\d+$/ or $name =~ /_[left|right]$/;

	    $h->{$name}->{name} = $name;
	    $h->{$name}->{contig} = $contig->name;
	    $h->{$name}->{contig_length} = $contig->length; #NOT NEEDED .. NO SCREENING CTGS OUT
	    $h->{$name}->{contig_read_count} = $read_count; #LIKE WISE
	    $h->{$name}->{read_pos} = $read->start;

	    my $c_or_u = ($read->complemented)? 'C' : 'U';
	}
    }

    return $h;
}

sub _get_contig_end_reads
{
    my ($self, $reads_hash) = @_;
    
    
}

1;
