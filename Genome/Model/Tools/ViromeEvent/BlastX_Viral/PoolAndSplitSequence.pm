
package Genome::Model::Tools::ViromeEvent::BlastX_Viral::PoolAndSplitSequence;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastX_Viral::PoolAndSplitSequence{
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
This script will put all sequences in all BXfiltered.fa files in given
sample library into one .BXfiltered.fa file.

Given a fasta file, this script will split it to a number of files. Each 
file will contain given number of sequences. Generated files have the 
same name as the given file with numbered suffix .file0 .file1 ... etc 
All the generated files are placed in on subdirectory with the same name 
as the given file with "BXfiltered_TBLASTX_Viral" suffix. 

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
    $self->log_event("Blast X Viral Pool and Split Sequence entered");
    my $dir = $self->dir;


    $self->pool_BXNTfiltered_sequence( $dir );

    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    my $matches = 0;
    foreach my $file (readdir DH) 
    {
	if ($file =~ /\.TBXNTFiltered\.fa$/) 
        { 
                $matches++;
                $self->log_event("$file MATCHED .TBXNTFiltered");
		# directory for splited files
		my $out_dir = $file;
		$out_dir =~ s/TBXNTFiltered.fa/TBXNTFiltered_TBLASTX_ViralGenome/;
		$out_dir = $dir."/".$out_dir;
			
		$self->splitGivenNumberSequence($dir, $file, $out_dir);
	}
    }
    closedir DH;

    $self->log_event("Blast X Viral Pool and Split Sequence completed with $matches matches");
    return 1;
}

sub pool_BXNTfiltered_sequence {
	my ($self, $dir ) = @_;

	opendir(DH, $dir) or die "Can not open dir $dir!\n";
        my $matches = 0;
        my $pushes = 0;
	foreach my $name (readdir DH) {
		if ($name =~ /BNFiltered_TBLASTX_nt$/) {
                        $matches++;
                        $self->log_event("$name MATCHED BNFiltered_TBLASTX_nt in pool_BXNTfiltered_sequence");
			my $temp = $name;
			my @temp = split(/\./, $temp);
			$temp = shift @temp;
			my $out = $dir."/".$temp.".TBXNTFiltered.fa";
			if (-e $out) {
				return 0;
			}
			my @files = ();
			my $full_path = $dir."/".$name;
			opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
			foreach my $name2 (readdir SubDH) { 
				if ($name2 =~ /TBXNTfiltered\.fa$/) {
                                        $pushes++;
                                        $self->log_event("pushing $name2");
					push @files, $full_path."/".$name2;
				}
			}
			closedir( SubDH );

			my $com = "cat ";
			foreach my $file (@files) {
				$com = "cat $file >> $out ";
                                $self->log_event("pool_BXNT, calling $com");
				system( $com );
			}
		}
	}
        $self->log_event("$matches pooled matches and $pushes pushes");

	closedir( DH );
}

sub splitGivenNumberSequence {
	my ($self, $inFile_dir, $inFile_name, $outDir ) = @_;
$self->log_event("spliting sequence for $inFile_name");				
        my $numSeq = 400; # number of sequences in each file
	# read in sequences
	my $inFile = $inFile_dir."/".$inFile_name;
	my %seq = $self->read_FASTA_data($inFile);
	my $num_seq_total = keys %seq;
	my $num_seq_left = $num_seq_total;
					
	# check there are sequences in the file
	my $n = keys %seq;
	if (!$n) {
		$self->log_event($inFile_name, " does not have any sequences!\n\n");
		return 0;
	}

	# make directory for splited files
	if (-e $outDir) {
		return 0;
	}
	else {
		my $com = "mkdir $outDir";
		system ($com);
	}
	
	# start spliting
	my $geneCount = 0;
	my $fileCount = 0;
	my $outFile = $outDir."/".$inFile_name."_file".$fileCount.".fa";
	open (OUT, ">$outFile") or die "can not open file $outFile!\n";
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
}

sub read_FASTA_data () {
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
			@rows = split (/\n/, $line);	
			my $contigName = shift @rows;
			my $contigSeq = join("", @rows);
			$contigSeq =~ s/\s//g; #remove white space
			$fastaSeq{$contigName} = $contigSeq;
		}
    }

    #reset the read seperator
    $/ = $oldseperator;
    close FastaFile; 
    return %fastaSeq;
}


1;

