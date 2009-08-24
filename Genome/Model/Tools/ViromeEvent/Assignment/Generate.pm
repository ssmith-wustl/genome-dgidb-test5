
package Genome::Model::Tools::ViromeEvent::Assignment::Generate;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use Switch;
use Bio::SearchIO;

class Genome::Model::Tools::ViromeEvent::Assignment::Generate{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    "gzhao's reporting for virome"
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute
{
    my $self = shift;
    my $dir = $self->dir;

    $self->log_event("Assignment Generate begun");

    my @temp = split("/", $dir);
    my $run_name = pop @temp;
    my $outFile = $dir."/Analysis_Report_".$run_name;
    open (OUT, ">$outFile") or die "can not open file $outFile!\n";

    my $c = "**********************************************************************************************";

    print OUT "How to read this file:\n";
    print OUT "For the summary section:\n";
    print OUT "column 1: sample number and name\n";
    print OUT "column 2: sample description\n";
    print OUT "column 3: total number of sequences obtained for this sample\n\n";

    print OUT "If there is any viral sequence identified in this sample, it will show up under the information \n";
    print OUT "of this sample. There are 3 columns to describe the viral reads identified in this sample:\n";
    print OUT "column 1: number of viral reads\n";
    print OUT "column 2: range of percentage identity to blast hits. Some times one sequence can hit multiple \n";
    print OUT "sequence in the nt database and gives a range of percent identity.\n";
    print OUT "column 3: name of the virus\n\n";
 
    print OUT "For the sequence report section:\n";
    print OUT "column 1: sample number and name\n";
    print OUT "column 2: total number of reads obtained for this sample\n";
    print OUT "column 3: number of unique reads after removing redundancy\n";
    print OUT "column 4: percentage of unique reads (unique reads divided by total number of reads)\n";
    print OUT "column 5: number of Filtered reads (after repeat masking, reads does not have at least 50bp \n";
    print OUT "consecutive sequence without N)\n";
    print OUT "column 6: percentage of Filtered reads (Filtered reads divided by total number of reads)\n";
    print OUT "column 7: number of good reads\n";
    print OUT "column 8: percentage of good reads\n";
    print OUT "column 9: number of reads assigned by blastn (BNassign)\n";
    print OUT "column 10: percentage of reads assigned by blastn\n";
    print OUT "column 11: number of reads goes to TBLASTX\n";
    print OUT "column 12: percentage of sequences goes to TBLASTX\n\n";
 
    print OUT "For the Assignment in each sample section:\n";
    print OUT "Describes the number of sequences assigned to each category.\n\n";

    print OUT "If there is a Interesting read section, following are the description of the fields:\n";
    print OUT "Sample number and name\n";
    print OUT "Viral lineage\n";
    print OUT "Description of the reads and the top hit (the fields are: QueryName, Querylength, HitName, HitLen, \n";
    print OUT "HitDesc, Alignment Length, percent Identity, HitStart, HitEnd, e value)\n";
    print OUT "Sequence of the reads\n\n";

    print OUT "*The criteria for a viral lineage to appear in the \"Interesting Read\" section is the lowest \n";
    print OUT "percent identity is below 90% (Anellovirus is excluded).\n\n";
    print OUT $c, "\n\n";

    print OUT "Summary:\n\n";
    $self->generate_SampleDescription( $dir );
    print OUT "End of Summary\n\n";
    print OUT $c ;

    print OUT "\n\nSequence Report\n\n";
    $self->generate_SequenceReport( $dir );
    print OUT "End of Sequence Report\n\n";
    print OUT $c ;

    print OUT "\n\nAssignment in each sample:\n\n";
    $self->generate_AssignmentSummary( $dir );
    print OUT "End of Assignment\n\n";
    print OUT $c ;

    print OUT "\n\nInteresting Reads\n\n";
    $self->generate_InterestingReads( $dir );
    print OUT "End of Interesting Reads\n\n";

    $self->log_event("Assignment Generate completed");

    return 1;
}

sub generate_SampleDescription {
    my ($self,$dir) = @_;
   
    $self->log_event("generate_SampleDescription entered with $dir"); 
    # sample name => num of total sequence in the sample
    my %total_seq = ();

    print OUT $dir,"\n";
    printf OUT "%20s\t", " ";
    printf OUT  "%5s\t%15s\t%40s\n", "ViralRead", "PercentIDrange", "IdentifiedVirus";

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my @files = readdir DH;
    foreach my $name (sort @files) {
	# name is either file name or sample name (directory)
	if (($name =~ /^S\d+/)||($name =~ "undecodable")) {

	    my $full_path = $dir."/".$name;
	    if (-d $full_path) { # is a directory, sample directory
		my @t = split("_", $name);
		my $s_number = $t[0];
		$s_number =~ s/S//;

		# enter sample directory
		opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
		my @files_sampleDir = readdir SubDH;
		
		# get total number of sequences in the sample
		my $tempF = $full_path."/".$name.".fa";
		$total_seq{$name} = $self->count_num_of_seq($tempF);
		
		printf OUT "%30s\t%8d\n", $name,  $total_seq{$name};
		
		foreach my $file (@files_sampleDir) { 
		    if ($file =~ /AssignmentSummary$/) {
			my $file_name = $full_path."/".$file;
			open (IN, $file_name) or die "can not open file $file_name!\n";
			foreach (1..17) {
			    <IN>;
			}
			while (<IN>) {
			    if ($_ =~ /^\s*$/) { # empty line
				next;
			    }
			    else {
				my $number_reads = 0;
				my $range = "";
				my @temp = split(";", $_);
				my $info = pop @temp;
				my $virus = pop @temp;
				if ($info =~ /\ttotal number of reads: (\d+)\t(.*)/) {
				    $number_reads = $1;
				    $range = $2;
				}	
				printf OUT "%20s\t", " ";
				printf OUT "%5d\t%20s\t%40s\n", $number_reads, $range, $virus;
			    }
			}
		    } # finish
		}
	    }
	}
    }
    $self->log_event("generate_SampleDescription completed"); 
}

sub generate_AssignmentSummary {
    my ($self, $dir ) = @_;
    $self->log_event("generate_AssignmentSummary entered with $dir"); 
    
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my @files = readdir DH;
    foreach my $name (sort {$a cmp $b} @files) {
	# name is either file name or sample name (directory)
	my $full_path = $dir."/".$name;
	if (!($name =~ /\./)) {
	    if (-d $full_path) { # is a directory
		opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
		# enter sample directory
		foreach my $file (readdir SubDH) { 
		    if ($file =~ /\.AssignmentSummary/) {
			my $file_name = $full_path."/".$file;
			open (IN, $file_name) or die "can not open file $file_name!\n";
			while (<IN>) {
			    print OUT $_;
			}
		    } 
		}		
		print OUT "#########################################################################\n\n";
	    }
	}
    }
    $self->log_event("generate_AssignmentSummary completed"); 
}
sub generate_SequenceReport {
    my ($self, $dir ) = @_;
    $self->log_event("generating Sequence Report with $dir"); 
    
    # sample name => num of total sequence in the sample
    my %total_seq = ();
    
    # sample name => num of unique sequence in the sample
    my %unique_seq = ();
    my %unique_seq_percent = ();
    
    # sample name => num of Filtered sequence in the libary
    my %bad_seq = ();
    
    # sample name => percentage of Filtered seq in the lib
    my %bad_percent = (); 
    
    # libary name => num of good sequenc in the sample
    my %good_seq = (); 
    
    # sample name => percentage of Filtered seq in the lib
    my %good_percent = ();
    
    # sample name => num of sequence assigned by BLASTN
    my %blastn_assigned = ();
    
    # sample name => percentage of sequences assigned by blastn 
    my %blastn_assigned_percent = ();
    
    # sample name => num of sequence to be TBLASTX
    my %tblastx = ();
    
    # sample name => percentage of seq need TBLASTX
    my %tblastx_percent = ();
    
    # sample name => number of sequence assigned by TBLASTX
    
    print OUT $dir,"\n";
    printf OUT "%30s\t", "sampleName";
    print OUT "total\tuniq\t\%\t Filtered\t\%\tgood\t\%\tBNassign\t\%\tTBLASTX\t\%\n";
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my @files = readdir DH;
    foreach my $name (sort {$a cmp $b} @files) {
	# name is either file name or sample name (directory)
	my $full_path = $dir."/".$name;
	
	if (($name =~ /^S\d+/)||($name =~ "undecodable")) {
	    #next if $name =~ /undecodable/;
	    if (-d $full_path) { # is a directory
		# enter sample directory
		opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
		my @files_sampleDir = readdir SubDH;
		
		# get total number of sequences in the sample
		my $tempF = $full_path."/".$name.".fa";
		$total_seq{$name} = $self->count_num_of_seq($tempF);
		
		# get number of unique sequence in the sample 
		$tempF = $full_path."/".$name.".fa.cdhit_out";
		$unique_seq{$name} = $self->count_num_of_seq($tempF);
		$unique_seq_percent{$name} = $unique_seq{$name}*100/$total_seq{$name};
		print "total # seq = ", $total_seq{$name}, " unique # seq: ", $unique_seq{$name}, "\n";

			
		# get number of Filtered and good sequences 
		$tempF = $full_path."/".$name.".fa.cdhit_out.masked.badSeq";
		open (IN, $tempF) or die "can not open file $tempF!\n";
		while (<IN>) {
		    if ($_ =~ /good seq = (\d+) % = (0\.\d+)/) {
			$good_seq{$name} = $1;
			$good_percent{$name} = $1*100/$total_seq{$name};
		    }
		    if ($_ =~ /bad seq = (\d+) % = (0\.\d+)/) {
			$bad_seq{$name} = $1;
			$bad_percent{$name} = $1*100/$total_seq{$name};
		    }
		}
	
		# get number of sequences assigned by BLASTN and number of sequences saved for TBLASTX 
		my $total_saved = 0;
		my $total_BNassigned = 0;
		$tempF = $full_path."/".$name.".BNFiltered.fa";
		if (-e $tempF) {
		    my $BNFiltered = $self->count_num_of_seq($tempF);
		    $blastn_assigned{$name} = $good_seq{$name} - $BNFiltered;
		    $blastn_assigned_percent{$name} = $blastn_assigned{$name}*100/$total_seq{$name};
		    $tblastx{$name} = $BNFiltered;
		    $tblastx_percent{$name} = $BNFiltered*100/$total_seq{$name};
		}
		else {
		    my $BNFiltered = 0;
		    $blastn_assigned{$name} = $good_seq{$name} - $BNFiltered;
		    $blastn_assigned_percent{$name} = $blastn_assigned{$name}*100/$total_seq{$name};
		    $tblastx{$name} = $BNFiltered;
		    $tblastx_percent{$name} = $BNFiltered*100/$total_seq{$name};
		}

		printf OUT "%30s\t%5d\t%5d\t%5.1f\t", $name, $total_seq{$name}, $unique_seq{$name}, $unique_seq_percent{$name};
		printf OUT "%5d\t%5.1f\t%5d\t%5.1f\t", $bad_seq{$name}, $bad_percent{$name}, $good_seq{$name}, $good_percent{$name};
		printf OUT "%5d\t%9.1f\t%5d\t%5.1f\n", $blastn_assigned{$name}, $blastn_assigned_percent{$name}, $tblastx{$name},  $tblastx_percent{$name};
	    }
	}
    }

    my $total = 0;
    my $unique = 0;
    my $bad = 0;
    my $good = 0;
    my $BNassign = 0;
    my $Tx = 0;
    foreach my $key (keys %total_seq) {
	$total += $total_seq{$key};
	$unique += $unique_seq{$key};
	$bad += $bad_seq{$key};
	$good += $good_seq{$key};
	$BNassign += $blastn_assigned{$key};
	$Tx += $tblastx{$key};
    }
    $total_seq{"total"} = $total;
    $unique_seq{"total"} = $unique;
    $unique_seq_percent{"total"} = $unique*100/$total;
    $bad_seq{"total"} = $bad;
    $bad_percent{"total"} = $bad*100/$total;
    $good_seq{"total"} = $good;
    $good_percent{"total"} = $good*100/$total;
    $blastn_assigned{"total"} = $BNassign;
    $blastn_assigned_percent{"total"} = $BNassign*100/$total;
    $tblastx{"total"} = $Tx;
    $tblastx_percent{"total"} = $Tx*100/$total;
    
    # print out report for this sample
    printf OUT "%30s\t%5d\t%5d\t%5.1f\t", "total", $total_seq{"total"}, $unique_seq{"total"}, $unique_seq_percent{"total"};
    printf OUT "%5d\t%5.1f\t%5d\t%5.1f\t", $bad_seq{"total"}, $bad_percent{"total"}, $good_seq{"total"}, $good_percent{"total"};
    printf OUT "%5d\t%9.1f\t%5d\t%5.1f\n", $blastn_assigned{"total"}, $blastn_assigned_percent{"total"}, $tblastx{"total"},  $tblastx_percent{"total"};
    $self->log_event("generate_AssignmentSummary completed"); 
    
}

sub count_num_of_seq () {
    my ($self,$fastaFile) = @_;
    my $count = 0;
    
    open (FastaFile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";
    while (my $line = <FastaFile>){
	if ($line =~ ">") {
	    $count++;
	}
    }
    close FastaFile;
    
    return $count;
}

sub generate_InterestingReads {
    my ($self, $dir ) = @_;
    $self->log_event("generate_InterestingReads entered with $dir"); 
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my @files = readdir DH;
    foreach my $name (sort {$a cmp $b} @files) {
	# name is either file name or sample name (directory)
	my $full_path = $dir."/".$name;
	if (!($name =~ /\./)) {
	    if (-d $full_path) { # is a directory
		my $has_file = 0;
		print OUT $name, "\n";
		opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
		# enter sample directory
		foreach my $file (readdir SubDH) { 
		    if ($file =~ /\.InterestingReads/) {
			$has_file = 1;
			my $file_name = $full_path."/".$file;
			open (IN, $file_name) or die "can not open file $file_name!\n";
			while (<IN>) {
			    print OUT $_;
			}
		    } 
		}
		if (!$has_file) {
		    print OUT "$name does not have .InteresingReads file!\n";
		}		
		print OUT "#########################################################################\n\n";
	    }
	}
    }
    $self->log_event("generate_InterestingReads completed");
}
1;

