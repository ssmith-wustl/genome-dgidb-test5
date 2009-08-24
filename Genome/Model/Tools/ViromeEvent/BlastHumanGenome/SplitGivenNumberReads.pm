
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::SplitGivenNumberReads;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::SplitGivenNumberReads{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast Human Genome split Given Number Reads";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0.fa .file1.fa ... 
etc All the generated files are placed in on subdirectory with the 
same name as the given file with "_HumanGenomeBlast" suffix. 

perl script <dir>
<dir> = full path of the folder holding files for a sample library
        without last "/"
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

    $self->log_event("Blast Human Genome entered");

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $file (readdir DH) {
        $self->log_event("step 0:  $file");
        	if ($file =~ /\.masked\.goodSeq$/) { 
                    $self->log_event("step 1:  found $file for splitting");
	        	# directory for splited files
		    my $out_dir = $file;
        		$out_dir = $dir."/".$out_dir."_HGblast";
		    $self->splitGivenNumberSequence($dir, $file, $out_dir);
	        }							
    }   

    $self->log_event("Blast Human Genome completed");

    return 1;
}

sub splitGivenNumberSequence {
	my ($self, $inFile_dir, $inFile_name, $outDir ) = @_;
        my $numSeq = 200; # number of sequences in each file
        $self->log_event("Blast Human Genome splitGivenNumberSequence entered");
				
	# read in sequences
	my $inFile = $inFile_dir."/".$inFile_name;
	my %seq = $self->read_FASTA_data($inFile);
	my $num_seq_total = keys %seq;
	my $num_seq_left = $num_seq_total;
					
	# check there are sequences in the file
	my $n = keys %seq;
	if (!$n) {
                $self->log_event("step 2, $inFile_name does not have any sequences, returning");
		print $inFile_name, " does not have any sequences!\n\n";
		return 0;
	}

	# make directory for splited files
	if (-e $outDir) {
                $self->log_event("step 2, $outDir exists, returning");
		return 0;
	}
	else {
		my $com = "mkdir $outDir";
                $self->log_event("step 2, mkdir $outDir");
		system ($com);
	}
	
	# start spliting
	my $geneCount = 0;
	my $fileCount = 0;
	my $outFile = $outDir."/".$inFile_name."_file".$fileCount.".fa";
	open (OUT, ">$outFile") or die "can not open file $outFile!\n";
        $self->log_event("step 3, $outFile created");
	foreach my $read (keys %seq) {
		print OUT ">$read\n";
		print OUT $seq{$read}, "\n";
		$geneCount++;

		if (!($geneCount%$numSeq)) {
			close OUT;
			$fileCount++;
			$num_seq_left = $num_seq_total - $geneCount;
			if ($num_seq_left) {
				$outFile = $outDir."/".$inFile_name."_file".$fileCount.".fa";
				open (OUT, ">$outFile") or die "can not open file $outFile!\n";
			}
			else {
				return 0;
			}
		}
	}
	close OUT;
        $self->log_event("Blast Human Genome splitGivenNumberSequence completed");
}


sub read_FASTA_data () {
    my ($self,$fastaFile) = @_;
    $self->log_event("Blast Human Genome read_FASTA_data entered");

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    my %fastaSeq;	 
    open (IN, $fastaFile) or die "Can't Open FASTA file: $fastaFile";

    $self->log_event("$fastaFile opened");
    while (my $line = <IN>){
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
			@rows = split (/\n/, $line);	
			my $contigName = shift @rows;
			my $contigSeq = join("", @rows);
			$contigSeq =~ s/\s//g; #remove white space
			$fastaSeq{$contigName} = $contigSeq;
		}
    }

    #reset the read seperator
    $/ = $oldseperator;
	close IN;
    
    $self->log_event("Blast Human Genome read_FASTA_data completed");
    return %fastaSeq;
}



1;

