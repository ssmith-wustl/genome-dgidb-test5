
package Genome::Model::Tools::ViromeEvent::BlastX_NT::PoolAndSplitSequence;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_NT::PoolAndSplitSequence{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast x Pool and Split Sequence";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will put all sequences in all BNfiltered.fa files in given
sample library into one .BNfiltered.fa file.

Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0 .file1 ... etc 
All the generated files are placed in on subdirectory with the same name 
as the given file with "BNfiltered" suffix. 


perl script <sample dir>
<sample dir> = full path to the folder holding files for a sample library
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
    $self->log_event("Blast X NT entered");
    my $dir = $self->dir;



    $self->pool_BNfiltered_sequence( );

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my $matches = 0;
    foreach my $file (readdir DH) 
    {
	if ($file =~ /\.BNFiltered\.fa$/) 
        { 
                $self->log_event("$file did MATCH BNFiltered");

		# directory for splited files
		my $out_dir = $file;
		$out_dir =~ s/\.BNFiltered\.fa/.BNFiltered_TBLASTX_nt/;
		$out_dir = $dir."/".$out_dir;

                $matches++;
			
		$self->splitGivenNumberSequence($file, $out_dir);
	}
        else
        {
            $self->log_event("$file did NOT match BNFiltered");
        }
    }
    $self->log_event("Blast X NT completed with $matches matches");
    return 1;
}

sub pool_BNfiltered_sequence 
{
	my ($self) = @_;
        my $dir = $self->dir;
        my $matches = 0;

	opendir(DH, $dir) or die "Can not open dir $dir!\n";
	foreach my $name (readdir DH) 
        {
		if ($name =~ /HGfiltered_BLASTN$/) 
                {
                        $matches++;
                        $self->log_event("$name did MATCH HGfiltered_BLASTN");
			my $temp = $name;
			my @temp = split(/\./, $temp);
			$temp = shift @temp;
			my $full_path = $dir."/".$name;
			my $out = $dir."/".$temp.".BNFiltered.fa";
			if (-e $out) {
                                $self->log_event("$out exists, exiting");
				return 0;
			}
			my @files = ();
			opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
			foreach my $name2 (readdir SubDH) { 
				if ($name2 =~ /BNfiltered\.fa$/) {
					push @files, $full_path."/".$name2;
				}
			}
			closedir( SubDH );

			my $com = "";
			foreach my $file (@files) {
				$com = "cat $file >> $out ";
                                $self->log_event("calling $com");
				system( $com );
			}
		}
	}

	closedir( DH );
        $self->log_event("$matches pooled matches");
}


sub splitGivenNumberSequence {
	my ($self, $inFile_name, $outDir ) = @_;
        my $dir = $self->dir;				
        my $numSeq = 100; # number of sequences in each file
	# read in sequences
	my $inFile = $dir."/".$inFile_name;
	my %seq = $self->read_FASTA_data($inFile);
	my $num_seq_total = keys %seq;
	my $num_seq_left = $num_seq_total;
        $self->log_event("splitGivenNumberSequence entered with $outDir");	
	# check there are sequences in the file
	my $n = keys %seq;
	if (!$n) {
		$self->log_event("in splitGivenNumberSequence ", $inFile_name, " does not have any sequences!");
		return 0;
	}

	# make directory for splited files
	if (-e $outDir) {
                $self->log_event("in splitGivenNumberSequence, $outDir exists, returning");
		return 0;
	}
	else {
                $self->log_event("in splitGivenNumberSequence, creating $outDir");
		my $com = "mkdir $outDir";
		system ($com);
	}
        $self->log_event("beginning splitting...");	
	# start spliting
	my $geneCount = 0;
	my $fileCount = 0;
	my $outFile = $outDir."/".$inFile_name."_file".$fileCount.".fa";
	open (OUT, ">$outFile") or die "can not open file $outFile!\n";
	foreach my $read (keys %seq) {
                $self->log_event("printing $read to $outFile");
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
				;
			}
		}
	}
	close OUT;
        $self->log_event("splitGivenNumberSequence complete");
}

sub read_FASTA_data () {
    my ($self,$fastaFile) = @_;
    $self->log_event("read_FASTA_data entered");
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
			@rows = split (/\n/, $line);	
			my $contigName = shift @rows;
			my $contigSeq = join("", @rows);
			$contigSeq =~ s/\s//g; #remove white space
			$fastaSeq{$contigName} = $contigSeq;
		}
    }

    # execute right

    #reset the read seperator
    $/ = $oldseperator;
   close FastaFile; 
    $self->log_event("read_FASTA_data completed");
    return %fastaSeq;
}


1;

