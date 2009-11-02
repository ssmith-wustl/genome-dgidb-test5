package Genome::Model::Tools::Assembly::MergeContigs;

#usage cmt.pl infile.ace ContigName ContigName2

use above 'Genome';
use strict;
use warnings;
use Genome::Assembly::Pcap::ContigTools;
use Genome::Assembly::Pcap::Ace;
use Cwd;

class Genome::Model::Tools::Assembly::MergeContigs
{
    is => 'Command',
    has => 
    [
        contigs => {
            type => "String",
            optional => 0,
            doc => "This is the list of input Contigs, in the format:\n --contigs 'ace_file.ace Contig1 ace_file.ace Contig2 ace_file2.ace Contig6'\n it is required that an ace file is listed before each contig, even in the case where all contigs are in the same ace file"
        }, 
        o => {
            type => "String",
            optional => 1,
            doc => "If this optional argument is set, the contig is written to the designated output file",
        },
	    gext => {
            type => "String",
            optional => 1,
		    doc => "gap extension penalty",
            default_value => 1,
	    },
	    gopen => {
            type => "String",
            optional => 1,
		    doc => "gap open penalty",
            default_value => 1,
	    },
	    ggext => {
            type => "String",
            optional => 1,
		    doc => "global gap extension penalty",
            default_value => 15,
	    },
	    ggopen => {
            type => "String",
            optional => 1,
		    doc => "global gap open penalty",
            default_value => 15,
	    },
	    ug => {
            type => "String",
            optional => 1,
		    doc => "use global alignment",
            default_value => 0,
	    },
	    q => {
            type => "Boolean",
            optional => 1,
		    doc => "quiet mode (no stats info)",
            default_value => 0,
	    },
	    'hq_percent_identity' => {
            type => "String",
            optional => 1,
		    doc => "high quality percent identity cutoff",
	    },
	    'hq_mismatch' => {
            type => "String",
            optional => 1,
		    doc => "high quality mismatch cutoff",
	    },
	    'percent_identity' => {
            type => "String",
            optional => 1,
		    doc => "percent identity cutoff",
	    },
	    mismatch => {
            type => "String",
            optional => 1,
		    doc => "mismatch cutoff",
	    },
	    'length' => {
            type => "String",
            optional => 1,
		    doc => "alignment region length cutoff",
	    },
        cc => {
            type => "Boolean",
            optional => 1,
            doc => "set this to 1 if you wish to rebuild the .db cache for each ace file"
        }
    ]
};

sub help_brief {
    ""
}

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    merge-contigs --contigs 'acefile1.ace contig1 acefile1.ace contig2 acefile2.ace contig3' --o output.ace
    merge-contigs --contigs 'acefile1.ace contig1 acefile1.ace contig2 acefile2.ace contig3'    
EOS
}

sub execute
{
    my $self = shift;
    my %cutoffs;
    $cutoffs{hq_percent_identity} = $self->hq_percent_identity if defined $self->hq_percent_identity;
    $cutoffs{hq_mismatch} = $self->hq_mismatch if defined $self->hq_mismatch;
    $cutoffs{percent_identity} = $self->percent_identity if defined $self->percent_identity;
    $cutoffs{mismatch} = $self->mismatch if defined $self->mismatch; 
    $cutoffs{length} = $self->length if defined $self->length;
    
    my %params = (gap_ext_penalty => $self->gext,
			      gap_open_penalty => $self->gopen,
			      glob_gap_ext_penalty => $self->ggext,
			      glob_gap_open_penalty => $self->ggopen,
			      use_global_align => $self->ug,
			      quiet => $self->q,
			      cutoffs => \%cutoffs);
    my $output_file_name = $self->o;
    
    my $contigs = $self->contigs;
    my @contig_urls = split /\s+/,$contigs;
    for (my $i=0;$i<@contig_urls;$i+=2)
    {
        $self->error_message("contig_urls[$i] is not a valide ace file, contig string $contigs is not formatted properly, there needs to be a valid ace file specified before each contig. i.e.\n merge-contigs -contigs 'acefile1.ace contig acefile2.ace'\n")
        and return unless (-e $contig_urls[$i]);
        unlink $contig_urls[$i].'.db' if defined $self->cc;
    }

    my $cwd = cwd();
    my $ao = Genome::Assembly::Pcap::Ace->new(input_file => $contig_urls[0], using_db => 1);
    my $phd_object;
    if(-e "../phdball_dir/phd.ball.1")
    {
        $phd_object = Genome::Assembly::Pcap::Phd->new(input_file => "../phdball_dir/phd.ball.1");
    }
    elsif(-e "../phd_dir/")
    {
        $phd_object = Genome::Assembly::Pcap::Phd->new(input_directory => "../phd_dir/");
    }
    else
    {
        $self->error_message("Need to either have a ../phd_dir or a phdball file named ../phdball_dir/phd.ball.1") and return;
    }    
    my $ct = Genome::Assembly::Pcap::ContigTools->new;

    my $merge_contig = $ao->get_contig($contig_urls[1],1);

    for(my $i=2;$i<@contig_urls;$i+=2)
    {
	    my $temp_ao = Genome::Assembly::Pcap::Ace->new(input_file => $contig_urls[$i],using_db => 1);
	    my $next_contig = $temp_ao->get_contig($contig_urls[$i+1],1);
        $temp_ao->remove_contig($contig_urls[$i+1]);
	    $merge_contig = $ct->merge($merge_contig, $next_contig, $phd_object, %params);	

    }

    $ao->add_contig($merge_contig);
    if(defined $output_file_name)
    {
        print "Writing to output file: $output_file_name\n";
        $ao->write_file(output_file => $output_file_name);
    }
    return 1;
}
=head1 NAME

cmt : Contig Merging Tool

=head1 SYNOPSIS

cmt inputacefile leftcontig rightcontig [options]

=head1 DESCRIPTION

The cmt takes a single ace file, the name of the "left" contig and "right" contig, and produces an output ace file that
is specified by the user.  

In order for the cmt to work properly it needs quality information for the reads contained in the contigs, either
in the form of phd files, OR in the of fasta.qual files.  If using phd files, they need to be in a directory named
phd_dir that is one level below the current directory (just like consed). If using qual files, the cmt expects to 
find them in a directory named Input.  i.e.

	project_directory/edit_dir/(this is where are ace file are located)
	project_directory/phd_dir/(this directory contains phd information)
	project_directory/Input/(this directory contains qual and tabl files)

The cmt should be run from the directory that contains ace files, in this case edit_dir.  The directory containing ace files does not necesarily need to be called edit_dir.  However,
it is very important that the directory containing phd files is named phd_dir and the directory containing qual files is named
Input.  

If using fasta.qual files to obtain read quality information, it is highly recommended to build a tab file first.
The tab file should be placed in the Input directory.  For more information on how to build .tab files, please
see the man page for buildtab.

=head1 OPTIONS

=head2 -gext gap-ext-penalty

Set the gap extension penalty for the local alignment algorithm.  The cmt uses a local alignment algorithm to line up the merges.  Increasing the gap extension penalty discourages the cmt from adding gaps when performing alignments.  The default value for the gap extension penalty is 1.

=head2 -gopen gap-open-penalty

Set the gap open penalty for the local alignment algorithm.   The cmt uses a local alignment algorithm to line up the merges.  Increasing the gap open penalty discourages the cmt from adding additional gaps (pads) after inserting a first gap.  The default value for gap open penalty is 1.

=head2 -ggext global-gap-open-penalty

Set the gap extension penalty for the global alignment algorithm.  The cmt uses a global alignment algorithm to line up the merges.  Increasing the gap extension penalty discourages the cmt from adding gaps when performing alignments.  The default value for global gap extension penalty is 15.

=head2 -ggopen global-gap-ext-penalty

Set the gap open penalty for the global alignment algorithm.   The cmt uses a global alignment algorithm to line parts of the Contigs that are excluded from the initial local alignment.  Increasing the gap open penalty discourages the cmt from adding additional gaps (pads) after inserting a first gap.  The default value for global gap open penalty is 15.

=head2 -ug use-global-align

Specifying this option will tell the merging tool to use global alignment to line up overlapping consensus that occurs outside the merge region.  By default this is off, since alignment of sequence outside the merge region has not been tested extensively.

=head2 -o outfilename

This option allows the user to specify the outfile name.  Otherwise the cmt will produce an output ace file that contains the input ace file plus a number.  
i.e. If our input ace file is named testin.ace then our output ace file would be testin.ace.1.

=head1 AUTHOR

The cmt was written and is maintained by Jon Schindler <jschindl@wugsc.wustl.edu>.  It is part of the contig merging and splitting toolkit.  

=head1 SEE ALSO

cst, cet, cvt, cct, ctf, cpf, cmtparse

=cut

1;





