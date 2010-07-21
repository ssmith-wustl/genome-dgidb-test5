package Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch;

use strict;
use warnings;
use Genome;

use Data::Dumper;
use Cwd;

use Sort::Naturally;

class Genome::Model::Tools::Assembly::AutoJoin::ByCrossMatch
{
    is => ['Genome::Model::Tools::Assembly::AutoJoin'],
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
		default => 500,
		doc => "Length of sequences at each ends to run cross match"        
		},
	    cm_min_match => {
		type => 'String',
		is_optional => 1,
		default => 25,
		doc => "Minimum length of cross match to consider for join"        
		},
	    report_only => {
		type => 'Boolean',
		is_optional => 1,
		default => 0,
		doc => "Option to print joins the program finds but not make the joins",
	        },
	    ],
};

sub help_brief {
    'Align and join contigs based on cross_match matches'
}

sub help_detail {
    return <<"EOS"
Align and join contigs based on cross_match matches
EOS
}

sub execute {
    my ($self) = @_;

    my $orig_dir = cwd();

    #RETURNS CROSS_MATCH ALIGNMENTS, ACE OBJ AND CTG TOOL
    my ($cm_aligns, $ao, $ct, $scafs);
    unless (($cm_aligns, $ao, $ct, $scafs) = $self->create_alignments() ) {
	$self->error_message("Could not create alignments");
	return;
    }

    my $new_scaffolds =[];
    unless ($new_scaffolds = $self->_build_scaffold_by_cm_alignments ($cm_aligns)) {
	$self->error_message("Build new scaffolds by cm alignments failed");
	return;
    }

    my $merged_ace;
    unless ($merged_ace = $self->make_joins($new_scaffolds, $ao, $ct)) {
	$self->error_message("Make joins failed");
	return;
    }

    #CLEAN UP
    unless ($self->clean_up_merged_ace ($merged_ace)) {
	$self->error_message("Unable to clean up merged ace file");
	return;
    }

    chdir ("$orig_dir");

    return 1;
}

sub _build_scaffold_by_cm_alignments
{
    my ($self, $cm_aligns) = @_;

    #GET A LIST OF CONTIGS IN CM ALIGNMENT HASH
    my @new_scaffolds;
    my @align_contigs = map {$_} keys %$cm_aligns;
    
    #KEEP TRACK OF CONTIGS THAT WILL MERGE INTO SCAFFOLDS SO
    #WE DON'T TRY TO START A NEW SCAFFOLD WITH THAT CONTIG
    my $merged_contigs = {};

    #SCAFFOLDS LINES SHOULD LOOK LIKE THIS:
    #0.3 <-184-> 1.1 <-244-> 1.2 <-43-> (1.3)

    foreach my $source_contig (@align_contigs) {
	next if exists $merged_contigs->{$source_contig};
	next unless exists $cm_aligns->{$source_contig};

	my $extending_end_dir;
	my $target_contig;
	my $target_contig_dir;
	my $target_contig_overlap;
	my $source_contig_dir;
	my $scaffold;
	my $scaffold_start_contig = $source_contig;
	my $change_extend_dir = 0;
	my $prev_contig_comp = 0;

	while (1) {
	    $extending_end_dir = 'left' unless $extending_end_dir;
	    $source_contig_dir = 'left' unless $source_contig_dir;
	    if ($change_extend_dir == 1) {
		$source_contig = $scaffold_start_contig;
		$source_contig_dir = 'right';
		$change_extend_dir = 0;
		$prev_contig_comp = 0;
	    }

	    #LOOK AT SOURCE CONTIG AND DETERMINE WHAT TARGET CONTIG WILL BE
	    if (exists $cm_aligns->{$source_contig}->{$source_contig_dir}) {
		my ($source_contig_num) = $source_contig =~ /Contig(\S+)/;

		$scaffold = " $source_contig_num" unless $scaffold;
		my $tmp = $cm_aligns->{$source_contig}->{$source_contig_dir};

		#FIND THE CONTIG WITH THE GREATEST OVERLAP
		my $biggest_overlap = 0;
		foreach my $ctg (keys %$tmp) {
		    my $overlap = $tmp->{$ctg}->{bases_overlap};
		    if ($overlap > $biggest_overlap) {
			$target_contig = $ctg;
			$target_contig_dir = $tmp->{$ctg}->{l_or_r};
			$target_contig_overlap = $tmp->{$ctg}->{bases_overlap};
		    }
		}

		#CHECK TO MAKE SURE TARGET CONTIG IS THERE AND THAT IT'S NOT
		#HITTING CONTIGS THAT HAS ALREADY BEEN ADDED

		if (! exists $cm_aligns->{$target_contig}->{$target_contig_dir}) {
		    if ($extending_end_dir eq 'right') {
			#START BUILDING THE NEXT SCAFFOLD
			last;
		    }
		    else {
			#START EXTENDING THE RIGHT END
			$extending_end_dir = 'right';
			$change_extend_dir = 1;
			next;
		    }
		}

		my ($target_contig_num) = $target_contig =~ /Contig(\S+)/;

		#TELL JOINING METHOD TO COMPLEMENT THE CONTIG BY WRAPPING IT IN ();
		#L TO R OR R TO L JOIN  W/ PREV CTG COMPLEMENTED - D/ COMP NEXT CONTIG
		#L TO R OR R TO L JOIN  W/O PREV CTG COMPLEMENTED - D/N COMP NEXT CONTIG
		#L TO L OR R TO R JOIN  W/ PREV CTG COMPLEMENTED - D/N COMP NEXT CONTIG
		#L TO L OR R TO R JOIN  W/O PREV CTG COMPLEMENTED - D/ COMP NEXT CONTIG

		if ($source_contig_dir eq $target_contig_dir) {
		    if ($prev_contig_comp == 0) {
			$target_contig_num = '('.$target_contig_num.')';
			$prev_contig_comp = 1;
		    }
		    else {
			$prev_contig_comp = 0;
		    }
		}
		else {
		    if ($prev_contig_comp == 1) {
			$target_contig_num = '('.$target_contig_num.')';
			$prev_contig_comp = 1;
		    }
		    else {
			$prev_contig_comp = 0;
		    }
		}
		
		#FOR EXTENDING LEFT END OF SCAFFOLD, APPEND NEW CONTIG TO LEFT
		if ($extending_end_dir eq 'left') {
		     $scaffold = " $target_contig_num".' <-'.$target_contig_overlap.'->'.$scaffold;
		}
		else {
		    $scaffold = $scaffold.' <-'.$target_contig_overlap.'-> '.$target_contig_num;
		}

		#REMOVE MERGED CONTIGS FROM HASH OF CROSS_MATCH ALIGNEMENTS
		if (exists $cm_aligns->{$target_contig}->{$target_contig_dir}) {
		    print "Deleting $target_contig $target_contig_dir\n";
		    delete $cm_aligns->{$target_contig}->{$target_contig_dir};
		}
		if (exists $cm_aligns->{$source_contig}->{$source_contig_dir}) {
		    print "Deleting $source_contig $source_contig_dir\n";
		    delete $cm_aligns->{$source_contig}->{$source_contig_dir};
		}

		#ADD SOURCE AND TARGET CONTIGS TO MERGED CONTIGS HAST SO THEY
		#DON'T GET PROCESSED AGAIN
		$merged_contigs->{$source_contig} = 1;
		$merged_contigs->{$target_contig} = 1;
		#ASSIGN WHICH SOURCE CONTIG END TO EXTEND .. JUST OPPOSITE OF CURRENT 
		$source_contig_dir = 'left';
		$source_contig_dir = 'right' if $target_contig_dir eq 'left';
		#ASSIGN TARGET CONTIG AS THE NEXT SOURCE CONTIG
		$source_contig = $target_contig;
	    }
	    else {
		if ($extending_end_dir eq 'left') {
		    $extending_end_dir = 'right';
		    $change_extend_dir = 1;
		}
		else {
		    last;
		}
	    }
	    
	}
	#PREPEND SCAFFOLDS LINES TO LOOK LIKE THIS
	#New scaffold: 0.3 0.3 <-184-> 1.1 <-244-> 1.2 <-43-> (1.3)

	$scaffold =~ s/^\s+//;
	my ($first_contig) = $scaffold =~ /^(\S+)/;
        #IF FIRST CONTIG LOOKS LIKE THIS: (0.2) .. STRIP ( AND ) OFF
	if ($first_contig =~ /\(\S+\)/) {
	    $first_contig =~ s/\(//;
	    $first_contig =~ s/\)//;
	}
	$scaffold = "New scaffold: $first_contig ".$scaffold;
	push @new_scaffolds, $scaffold;
    }
    return \@new_scaffolds;
}

1;
