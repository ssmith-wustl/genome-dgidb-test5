
package Genome::Model::Tools::ViromeEvent::BlastHumanGenome::ParseOutput;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::BlastHumanGenome::ParseOutput{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Blast Human Genome parse output";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
This script will check all .HGblast.parsed file in the 
given directory to make sure parsing blastn output file is finished 
for the given file.

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
    my $dir = $self->dir;
    $self->log_event("Blast Human Genome check output entered");
    my @temp_dir_arr = split("/", $dir);
    my $lib_name = $temp_dir_arr[$#temp_dir_arr];

    my $allFinished = 1;
    my $have_input_file = 0;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) 
    {
        if ($name =~ /goodSeq_HGblast$/) 
        { # Human Genome blast directory
	    my $full_path = $dir."/".$name;
            opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
            $self->log_event("opened $full_path, now checking for entries");
	    foreach my $file (readdir SubDH) 
            {
                $self->log_event("checking $file");
	        if ($file =~ /\.HGblast\.out$/) 
                {
		    $have_input_file = 1;
		    my $have_blastn_parsed = 0;
        	    my $finished = 0;

		    my $temp_name = $file;
		    $temp_name =~ s/\.HGblast\.out//;
		    my $blastn_parsed_file = $full_path."/".$temp_name.".HGblast.parsed";
		    if (-s $blastn_parsed_file) 
                    {
		        $have_blastn_parsed = 1;
		        open (TEMP, "<$blastn_parsed_file") or die "can not open file $blastn_parsed_file!\n";
		        while (my $line = <TEMP>) 
                        {
			    if ($line =~ /# Summary/) 
                            {
			        $finished = 1;
			    }
		        }
		    }
		
		    if ((!$have_blastn_parsed)||(!$finished)) 
                    {
		        $allFinished = 0;	
                        $self->run_parser($full_path,$file);
		        #my $com = 'perl /gsc/var/tmp/virome/scripts/scripts2/Process454_S5_Blast_HumanGenome_3_parser.pl '.$full_path.' '.$file;
		        #my $ec = system ($com);
		        #if ($ec) 
                        #{
			#    die("Parse HG blast failed for command: $com\n");
		        #}
		    }
	        }
	    }
        }
    }


    if ($have_input_file) 
    {
        if ( $allFinished) 
        {
	   $self->log_event ("parsing blast Human Genome all finished ");
        }
    }
    else 
    {
        $self->log_event ("$dir does not have input file!");
    }

    $self->log_event("Blast Human Genome check output completed");
    return 1;
}

sub run_parser()
{ 
    my ($self, $dir, $blastout) = @_;

    # cutoff value for having a good hit, 1e-10 is a value that gives reasonable confidence
    my $E_cutoff = 1e-10;

    # create ouput file
    my $outFile = $blastout;
    $outFile =~ s/HGblast\.out/HGblast.parsed/;
    $outFile = $dir."/".$outFile;
    open (OUT, ">$outFile") or die "can not open file $outFile!\n";

    my @keep = (); # query should be kept for further analysis
    my @known = (); # queries that are significantly similar to human sequences
    my $total_records = 0;

    $self->log_event("parsing blast output files for $blastout...");

    my $input_file = $dir."/".$blastout;
    my $report = new Bio::SearchIO(-format => 'blast', -file => $input_file, -report_type => 'blastn');

    # Go through BLAST reports one by one        
    while(my $result = $report->next_result) 
    {# next query output
	$total_records++;
	my $haveHit = 0;
	my $keep = 1;
	while(my $hit = $result->next_hit) {
		$haveHit = 1;
		# check whether the hit should be kept for further analysis
		if ($hit->significance <= $E_cutoff) {
			$keep = 0;	
			print OUT $result->query_name, "\t", $result->query_length, "\tHomo\tHomo\t".$hit->name."\t".$hit->significance,"\n";

		}
		last; # only look at the first hit
	}

	if ($haveHit) {
		if ($keep) {
			push @keep, $result->query_name;
		}	
		else {		
			push @known, $result->query_name;
		}
	}
	else { # does not have a hit
		push @keep, $result->query_name;
	}	

   } 
   print OUT "# Summary: ", scalar @keep, " out of $total_records ", scalar @keep/$total_records, " is saved for BLASTN analysis.\n";

    close OUT;

    # generate a fasta file that contains all the sequences that do not match
    # to human sequences
    # read in blastn input sequences
    my $file = $blastout;
    $file =~ s/\.HGblast\.out//;
    $file = $dir."/".$file.".fa";
    my %seq = $self->read_FASTA_data($file);

    $outFile = $blastout;
    $outFile =~ s/\.HGblast\.out//;
    $outFile = $dir."/".$outFile.".HGfiltered.fa";
    open (OUT2, ">$outFile") or die "can not open file $outFile!\n";
    foreach my $seq_name (@keep) {
	print OUT2 ">$seq_name\n";
	print OUT2 $seq{$seq_name}, "\n";
    }
    close OUT2;
}

sub read_FASTA_data () {
    my ($self,$fastaFile) = @_;

    #keep old read seperator and set new read seperator to ">"
    my $oldseperator = $/;
    $/ = ">";
	 
    my %fastaSeq;	 
    open (fastaFile, $fastaFile) or die "Can't Open FASTA file: $fastaFile";

    while (my $line = <fastaFile>){
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
	    @rows = split (/\s/, $line);	
	    my $contigName = shift @rows;
	    my $contigSeq = join("", @rows);
	    $contigSeq =~ s/\s//g; #remove white space
	    $fastaSeq{$contigName} = $contigSeq;
	}
    }

    #reset the read seperator
    $/ = $oldseperator;
    
    return %fastaSeq;
}

1;

