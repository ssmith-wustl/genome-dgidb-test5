
package Genome::Model::Tools::ViromeEvent::Assignment::Summary;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::Assignment::Summary{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    "gzhao's summary for virome"
}

sub help_synopsis {
    return <<"EOS"
This script will read the assignment report files in the given 
directory and generate a summary report for a given library. It will report 
in each library, for each category, how many total sequence were 
assigned to this category, how many were assigned by BLASTN, how many
were assigned by TBLASTX.

It will also filter the virus lineage, leave out virus that are phage.
It will rank the virus lineage by range of percent ID from low to high. 

It will also generate a .InterestingReads report about the details of each lineage.

perl script <sample folder>
<sample folder> = full path to the folder holding files for a given sample 
                   e.g. /home/gzhao/data/454_2007_12_03/Wang_KM_Samples_MRCE/KM_A/S21_Rota_other
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

    $self->log_event("Assignment Summary begun");

    # cutoff for sequences to be interesting
    my $percentID_cutoff = 100;

    my @temp = split("\/", $dir);
    my $lib_name = pop @temp;

    my $out = $dir."/".$lib_name.".AssignmentSummary";
    open (OUT, ">$out") or die "can not open file $out!\n";
    my $out2 = $dir."/".$lib_name.".InterestingReads";
    open (OUT2, ">$out2") or die "can not open file $out2!\n";

    my $seq_file = $dir."/".$lib_name.".fa";
    my %sequences = $self->read_FASTA_data($seq_file); # read_ID => sequence

    my %ID_low = ();  # lineage => lowest percent identity to hits
    my %ID_high = (); # lineage => highest percent identity to hits

    my $C = "##############################################\n\n";

    print OUT "$dir\n\n";
    # get sequence statistics
    my @nums = $self->get_SequenceInfo_OneSample($dir);
    print OUT "#total\tuniq\t\%\tFiltered\ttotal\%\tgood\ttotal\%\tBNHG\ttotal\%\tBNNT\ttotal\%\tTBXNT\ttotal\%\tTBXVG\ttotal\%\n";

    printf OUT ("%d\t%d\t%5.1f\t%d\t%5.1f\t%d\t%5.1f\t%d\t%5.1f\t%d\t%5.1f\t%d\t%5.1f\t%d\t%5.1f\n", $nums[0], $nums[1], $nums[1]*100/$nums[0], $nums[2], $nums[2]*100/$nums[0], $nums[3], $nums[3]*100/$nums[0], $nums[4], $nums[4]*100/$nums[0], $nums[5], $nums[5]*100/$nums[0], $nums[6], $nums[6]*100/$nums[0], $nums[7], $nums[7]*100/$nums[0]);
    print OUT "\n\n";

    my $oldSeperator = $/;
    $/ = "###########\n";
    my $AssignmentReport_file = $dir."/".$lib_name.".AssignmentReport";
    if (-e $AssignmentReport_file) 
    {
        if (-s $AssignmentReport_file > 0) 
        {
	    open (IN, $AssignmentReport_file) or die "can not open file $AssignmentReport_file!\n";
    	    my $line = <IN>;
	    $line =~ s/#//g;
	    my @temps = split("\n", $line);
	    shift @temps;
	    foreach my $temp (@temps) 
            {
	        print OUT $temp, "\n";
	    }
	    print OUT "\n\n";
	
	    while (<IN>) 
            {
	        if ($_ =~ /^\s*$/) 
                { # skip blank line
		    next;
	        }
	    
	        my @lines = split("\n", $_);
	        my $lineage = shift @lines;
	        $lineage = shift @lines;
	        my $high = 0;
	        my $low = 100;
	        my %readID_Identity = (); # readID => percent ID
	        my %readID_desc = (); # readID => description of the read
	        foreach my $l (@lines) 
                {

		    if ($l =~ /^\s*$/) { next; }
		    elsif ($l =~ /QueryName/) { next; }
		    elsif ($l =~ /reads from/) { next; }
		    elsif ($l =~ /#+/) { next; }
		    my ($read_ID, $Qlength, $hitName, $hitLen, $hitDesc, $alnLen, $ID, $hitS, $hitE, $e) = split("\t", $l);

		    #TURNING ON WARNINGS CAUSES ERROR HERE .. COMPARING ##% TO ## BUT IT STILL DOES THE RIGHT THING

		    #TO SHUT OFF SOME WORNINGS .. SHOULD BE OK TO DO THIS .. BUT
		    my $ID_num = $ID;
		    $ID_num =~ s/\%//;

		    if($ID_num > $high) { $high = $ID_num;}
		    if($ID_num < $low) { $low = $ID_num;}
 		    if (defined ($readID_Identity{$read_ID})) {
		        my $ID_2_num = $readID_Identity{$read_ID};
		        $ID_2_num =~ s/\%//;
		        if ($ID_num > $ID_2_num) {
 			    $readID_Identity{$read_ID} = $ID;
 			    $readID_desc{$read_ID} = $l;	
 		        }
 		    }
 		    else 
                    {
 		        $readID_Identity{$read_ID} = $ID;	
 		        $readID_desc{$read_ID} = $l;
 		    }

	        }
	        $ID_low{$lineage} = $low;
	        $ID_high{$lineage} = $high;

	        # only print out things that looks interesting
	        if ($low < $percentID_cutoff) 
                { 
		    print OUT2 $lineage, "\t[$low, $high]\n\n";
		    foreach my $key (sort {$readID_Identity{$a} <=> $readID_Identity{$b}} keys %readID_Identity) 
                    {
		        print OUT2  $readID_desc{$key}, "\n";
		    }
		    print OUT2 "\n";
		    foreach my $key (sort {$readID_Identity{$a} <=> $readID_Identity{$b}} keys %readID_Identity) 
                    {
		        print OUT2 ">$key\n";
		        print OUT2 "$sequences{$key}\n\n";
		    }
	        }
	    }
	    close IN;
        }
        else 
        {
	    print OUT "$AssignmentReport_file does not have content!\n";
	    exit;
        }
    }
    else 
    {
	print OUT  "$AssignmentReport_file does not exist!\n";
	exit;
    }

    foreach my $key (sort {$ID_low{$a} <=> $ID_low{$b}} keys %ID_low) 
    {
	printf OUT  ("%s\t[%4.1f, %4.1f]%\n", $key, $ID_low{$key}, $ID_high{$key});
    }
    close OUT;
    close OUT2;

    # remove all .job files 
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $file (readdir DH) 
    { 
	if ($file =~ /\.job$/) 
        {
		my $tempfile = $dir."/".$file;
		my $com = "unlink $tempfile";
		system ( $com );
	}
	# .job files in RepeatMasker directory
	if ($file =~ /cdhit_out_RepeatMasker$/) {
		my $tempDir = $dir."/".$file;
		opendir(TDH, $tempDir) or die "Can not open dir $tempDir!\n";
		foreach my $file2 (readdir TDH) {
			if ($file2 =~ /\.job$/) {
				my $tempfile = $tempDir."/".$file2;
				my $com = "unlink $tempfile";
				system ( $com );
			}
		}
	}
	closedir TDH;

	# .job files in HGblast directory
	if ($file =~ /goodSeq_HGblast$/) {
		my $tempDir = $dir."/".$file;
		opendir(TDH, $tempDir) or die "Can not open dir $tempDir!\n";
		foreach my $file2 (readdir TDH) {
			if ($file2 =~ /\.job$/) {
				my $tempfile = $tempDir."/".$file2;
				my $com = "unlink $tempfile";
				system ( $com );
			}
		}
	}
	closedir TDH;

	# .job files in BLASTN directory
	if ($file =~ /HGfiltered_BLASTN$/) {
		my $tempDir = $dir."/".$file;
		opendir(TDH, $tempDir) or die "Can not open dir $tempDir!\n";
		foreach my $file2 (readdir TDH) {
			if ($file2 =~ /\.job$/) {
				my $tempfile = $tempDir."/".$file2;
				my $com = "unlink $tempfile";
				system ( $com );
			}
		}
	}
	closedir TDH;

	# .job files in TBLASTX directory
	if ($file =~ /BNFiltered_TBLASTX_nt$/) {
		my $tempDir = $dir."/".$file;
		opendir(TDH, $tempDir) or die "Can not open dir $tempDir!\n";
		foreach my $file2 (readdir TDH) {
			if ($file2 =~ /\.job$/) {
				my $tempfile = $tempDir."/".$file2;
				my $com = "unlink $tempfile";
				system ( $com );
			}
		}
	}
	closedir TDH;

	# .job files in TBLASTX ViralGenome directory
	if ($file =~ /TBXNTFiltered_TBLASTX_ViralGenome$/) {
		my $tempDir = $dir."/".$file;
		opendir(TDH, $tempDir) or die "Can not open dir $tempDir!\n";
		foreach my $file2 (readdir TDH) {
			if ($file2 =~ /\.job$/) {
				my $tempfile = $tempDir."/".$file2;
				my $com = "unlink $tempfile";
				system ( $com );
			}
		}
	}
	closedir TDH;

    }
    closedir DH;

    $self->log_event("Assignment Summary completed");

    return 1;
}

sub read_FASTA_data () 
{
    my ($self,$fastaFile) = @_;

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    my %fastaSeq;	 
    open (FastaFile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";

    while (my $line = <FastaFile>){
		# Discard blank lines
        if ($line =~ /^\s*$/) {
			next;
		}
		# discard comment lines
		elsif ($line =~ /^\s*#/) {
	       next;
		}
		# discard the first line which only has ">", keep the rest
		elsif ($line ne ">") {
		    chomp $line;
		    my @rows = ();
		    @rows = split (/\n/m, $line);	
		    my $temp = shift @rows;
			my @temp_arr = split(/\s/, $temp);
			my $contigName = shift @temp_arr;
		    my $contigSeq = join("", @rows);
		    $contigSeq =~ s/\s//g; #remove white space
		    $fastaSeq{$contigName} = $contigSeq;
		}
    }

    #reset the read seperator
    $/ = $oldseperator;
    
    return %fastaSeq;
}

sub get_SequenceInfo_OneSample 
{
	my ($self, $dir ) = @_;

	my $total_seq = 0;
	my $unique_seq = 0;
	my $good_seq = 0;
	my $filtered_seq = 0;	
	my $blast_HG_assigned = 0;
	my $blastn_assigned = 0;
	my $tblastx_nt_assigned = 0;
	my $tblastx_VG_assigned = 0;

	# get directory path
	my @fields = split(/\//, $dir);
	my $libName = $fields[$#fields];

	# get total number of sequences in the sample
	my $tempF = $dir."/".$libName.".fa";
	$total_seq = $self->count_num_of_seq($tempF);

	# get number of unique sequence in the sample 
	$tempF = $dir."/".$libName.".fa.cdhit_out";
	if (-e $tempF) {
		$unique_seq = $self->count_num_of_seq($tempF);
	}		
	
	# get number of Filtered and good sequences 
	$tempF = $dir."/".$libName.".fa.cdhit_out.masked.badSeq";
	if (-e $tempF) {
		open (IN, $tempF) or die "can not open file $tempF!\n";
	}	
	while (<IN>) {
		if ($_ =~ /good seq = (\d+) % = (0\.\d+)/) {
			$good_seq = $1;
		}
		if ($_ =~ /bad seq = (\d+) % = (0\.\d+)/) {
			$filtered_seq = $1;
		}
	}

	# get number of sequences assigned by BLAST HumanGenome  
	my $HGfiltered = 0;
	$tempF = $dir."/".$libName.".HGfiltered.fa";
	if (-e $tempF) {
		$HGfiltered = $self->count_num_of_seq($tempF);
	}
	else {
		$HGfiltered = 0;
	}
	$blast_HG_assigned = $good_seq - $HGfiltered;

	# get number of sequences assigned by BLASTN  
	my $BNFiltered = 0;
	$tempF = $dir."/".$libName.".BNFiltered.fa";
	if (-e $tempF) {
		$BNFiltered = $self->count_num_of_seq($tempF);
	}
	else {
		$BNFiltered = 0;
	}

	$blastn_assigned = $HGfiltered - $BNFiltered;

	# get number of sequences assigned by TBLASTX nt  
	my $TBXNTfiltered = 0;
	$tempF = $dir."/".$libName.".TBXNTFiltered.fa";
	if (-e $tempF) {
		$TBXNTfiltered = $self->count_num_of_seq($tempF);
	}
	else {
		$TBXNTfiltered = 0;
	}
	$tblastx_nt_assigned = $BNFiltered - $TBXNTfiltered;

	# get number of sequences assigned by TBLASTX ViralGenome  
	my $unassigned_num = 0;
	$tempF = $dir."/".$libName.".unassigned.fa";
	if (-e $tempF) {
		$unassigned_num = $self->count_num_of_seq($tempF);
	}
	else {
		$unassigned_num = 0;
	}
	$tblastx_VG_assigned = $TBXNTfiltered - $unassigned_num;


	return ($total_seq, $unique_seq,  $filtered_seq, $good_seq, $blast_HG_assigned, $blastn_assigned, $tblastx_nt_assigned, $tblastx_VG_assigned);
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
1;

