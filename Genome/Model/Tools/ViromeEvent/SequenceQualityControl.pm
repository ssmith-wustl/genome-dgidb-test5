
package Genome::Model::Tools::ViromeEvent::SequenceQualityControl;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::SequenceQualityControl{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return <<"EOS"
filtering step prior to blast for virome pipeline
EOS
}

sub help_synopsis {
    return <<"EOS"
genome-model toold virome-event split-quality-control
EOS
}

sub help_detail {
    return <<"EOS"
This script will check each .masked file in the given directory.
Some sequences have only/lots of Ns because masked by RepeatMasker.
Remove sequences that do not have greater than 50 nt of consecutive
sequence without N.

perl script <run folder>
<run folder> = full path of the folder holding files for this sequence run
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
    $self->log_event("Sequence Quality Control entered");
    my $dir = $self->dir;
    my @fields = split(/\//, $dir);
    my $libName = $fields[$#fields];

    my $total_seq = 0;
    my $good_seq = 0;
    my $bad_seq = 0;
    my $OutFile1 = $dir."/".$libName.".fa.cdhit_out.masked.goodSeq";
    my $OutFile2 = $dir."/".$libName.".fa.cdhit_out.masked.badSeq";

    # if already has the files, exit
    if (-s $OutFile1) 
    {
	return 0;
    }

    open (OUT1, ">$OutFile1") or die "can not open $OutFile1\n";
    open (OUT2, ">$OutFile2") or die "can not open $OutFile2\n";
	
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    $self->log_event("step 0 opening $dir");
    foreach my $name (readdir DH) 
    {
        $self->log_event("step 1 sequencing $name");
        if ($name =~ /.cdhit_out_RepeatMasker$/) 
        { # RepeatMasker directory
            $self->log_event("step 2 sequencing $name");
	    my $full_path = $dir."/".$name;
	    opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            $self->log_event("step 3 opened $full_path");
	    foreach my $file (readdir SubDH) 
            {
                $self->log_event("step 4 opened $file");
	        if ($file =~ /\.masked$/) 
                { # masked sequence
                    $self->log_event("step 5 opened $file");
		    my $maskedFile = $full_path."/".$file;
		    my %seq = ();
		    $self->read_FASTA_data($maskedFile, \%seq);

        		# check for contiguous bases >= 50 bp (non-Ns) 
	        	foreach my $read_id (keys %seq) 
                        {
        		    $total_seq++;
	        	    my $seq_temp = $seq{$read_id};
		            my $goodQuality=$seq_temp=~/[ACTG]{50,}/; 
        		    if($goodQuality) 
                            {
	        		print OUT1 ">$read_id\n";
		        	print OUT1 $seq{$read_id}, "\n";
			        $good_seq++;
        		    }
	        	    else 
                            {
            			print OUT2 ">$read_id\n";
	        		print  OUT2 "$seq{$read_id}\n";
        			$bad_seq++;
		            }
		        }
	        }
                else
                {
                    $self->log_event("step 5 $file doesn't match mask");
                }
	    }
        }
    }

    print OUT2 "total seq = $total_seq\n";
    $self->log_event("total seq = $total_seq");
    if ($total_seq)
    {
        print OUT2 "good seq = $good_seq % = ", $good_seq/$total_seq, "\n";
        print OUT2 "bad seq = $bad_seq % = ", $bad_seq/$total_seq, "\n";
        $self->log_event("good seq = $good_seq % = ", $good_seq/$total_seq);
        $self->log_event("bad seq = $bad_seq % = ", $bad_seq/$total_seq);
    }
    close(OUT1);
    close(OUT2);
    $self->log_event("Sequence Quality Control completed");
    return 1;
}

sub read_FASTA_data () 
{
    my ($self,$fastaFile, $hash_ref) = @_;

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    open (FastaFile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";
    while (my $line = <FastaFile>){
	# Discard blank lines
        if ($line =~ /^\s*$/) {
	    next;
	}
	# discard comment lines
	elsif ($line =~ /#/) {
	    next;
	}
	# discard the first line which only has ">", keep the rest
	elsif ($line ne ">") {
	    chomp $line;
	    my @rows = ();
	    @rows = split (/\n/m, $line);	
	    my $seqName = shift @rows;
	    my @temp = split (/\s/, $seqName);
	    $seqName = shift @temp;
	    my $Seq = join("", @rows);
	    $Seq =~ s/\s//g; #remove white space
	    $hash_ref->{$seqName} = $Seq;
	}
    }
    
    close FastaFile;
    #reset the read seperator
    $/ = $oldseperator;
}


1;

