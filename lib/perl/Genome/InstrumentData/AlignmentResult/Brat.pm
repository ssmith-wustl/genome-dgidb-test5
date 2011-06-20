package Genome::InstrumentData::AlignmentResult::Brat;

use strict;
use warnings;
use IO::File;
use File::Basename;
use Genome;

#  So, you want to build an aligner?  Follow these steps.
#
#  1) set aligner name in the UR class def
#  2) set required_rusage
#  3) Implement run_aligner
#  4) Implement aligner_params_for_sam_header
#
#  You also will want to create a Genome::InstrumentData::Command::Align::YOURCLASSHERE
#  so you can align from the command line too!

class Genome::InstrumentData::AlignmentResult::Brat {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'brat', is_param=>1 },
    ],	
};

sub required_arch_os { 'x86_64' }

#TODO: Put the LSF resources required to run the alignment here.
#sub required_rusage {
#    "-R 'select[model!=Opteron250 && type==LINUX64 && mem>16000 ** tmp > 150000] span[hosts=1] rusage[tmp=150000, mem=16000]' -M 16000000 -n 1";
#}

sub required_rusage {
    "-R 'select[type==LINUX64 && mem>16000 && tmp > 100000] span[hosts=1] rusage[tmp=100000, mem=16000]' -M 16000000 -n 1";
}

#
#  Implement this method with the actual logic to run your aligner.
#  The pathnames for input files are passed in.
#
#  The expected output is an "all_sequences.sam" file in the scratch directory.
#  YOU MUST APPEND TO THIS FILE, NOT OVERWRITE.  This is because the calling code
#  may run multiple passes of run_aligner.  For example, when running trimming,
#  there may be two invocations - one with paired data, and one with a set of remaining
#  singleton reads whose mates were clipped too far in to be usable.
#
#  The sam file also needs to NOT have any SAM headers (i.e. lines starting with "@").
#  The pipeline adds its own detailed headers that are appropriate to the data.
#  Having headers here already will cause issues in the pipeline
#  downstream with picard merge.
#

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    # get refseq info and fasta files
    my $reference_build = $self->reference_build;
    my $reference_fasta_path = $reference_build->full_consensus_path('fa');

    # This is your scratch directory.  Whatever you put here will be wiped when the alignment
    # job exits.
    my $scratch_directory = $self->temp_scratch_directory;

    # This is the alignment output directory.  Whatever you put here will be synced up to the
    # final alignment directory that gets a disk allocation.
    my $staging_directory = $self->temp_staging_directory;

    # This is the SAM file you should be appending to.  Dont forget, no headers!
    my $sam_file = $scratch_directory . "/all_sequences.sam";
    # import format
    my $import_format = $self->instrument_data->import_format;



    # TODO: implement your aligner logic here.  If you need to condition on whether the
    # data is single-ended or paired-ended, key off the number of files passed in (1=SE, 2=PE)
    # Under no circumstances should you ever get more than 2 files, if you do then that's bad and
    # you should die.
    my $paired_end=0;
    my $min_insert_size = -1;
    my $max_insert_size = -1;

    print "number of ends: " . @input_pathnames . "\n";
    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.");
	$paired_end=1;

        ## TODO - Here's where we need the min/max insert size params
        ## I'm not sure where to get those at the moment.
	die("paired end data requires insert size params - not implemented yet (talk to Chris M.)");
	my $min_insert_size = $self->min_insert_size;	
	my $max_insert_size = $self->max_insert_size;
	if ($max_insert_size == -1){
	    die("maximum insert size required for paired end data")
	}
    } else {
        $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
        die $self->error_message;
    }



    #create a refs file with paths to all the fastas
    my ($ref_fh, $refs_file) = Genome::Sys->create_temp_file();


## We use the -P option with a pre-built index for alignment, but we still
## need the fastas for the acgt count step.

## Something like this goes back in once we get caching of individual fasta
## files set up on the blades
##
##    #get the reference directory path
##    print "ref_fasta_path: $reference_fasta_path\n";
##    my $ref_dir = dirname($reference_fasta_path);
##    print "ref_dir: $ref_dir\n";

    # for now, we hardcode the directory containing the fastas and such
    my $ref_dir = "/gscmnt/gc4096/info/model_data/2741951221/build101947881";
    
    #find all the individual fastas
    opendir(DIR, $ref_dir) or die $!;
    while (my $filename = readdir(DIR)){
	# if the filename matches this regex, output it to the list
	# should match 1.fa - 22.fa, along with X.fa, x.fa, Y.fa, y.fa
	# will fail on contigs (NT_113956.fa) or other formats (chr22.fa)
	if ($filename =~ /^(([1-2]?[0-9])|([XYxy]))\.fa$/)
	{
	    $ref_fh->print($ref_dir . "/" . $filename . "\n");
	}
    }
    $ref_fh->close;




    ###################################################
    #reads have to be trimmed first. This handles it

    my $trim_cmd = "/gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/trim -q 20 -m 2 -P $scratch_directory/trimmed";
    $self->status_message("trimming reads");
    #single vs paired end
    if ($paired_end)
    {
	$trim_cmd = $trim_cmd . " -1 $input_pathnames[0] -2 $input_pathnames[1]";
    } else {
    	$trim_cmd = $trim_cmd . " -s $input_pathnames[0]";
    }

###-------
### This shouldn't be necessary right now - defaults work fine
##
##    #determine which type of quality score we're using:
##    if ($import_format eq "solexa fastq") {
##	#older format - starts at ASCII 33
##	$trim_cmd = $trim_cmd . " -L 33";
##    } elsif ($import_format eq "illumina fastq") {
##	#newer format - starts at ASCII 64
##	$trim_cmd = $trim_cmd . " -L 64";
##    }
###----------

    system($trim_cmd);



    ###################################################
    # run the read mapping
    my $align_cmd = "/gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/brat-large";

    #use pre-computed index instead
    #$align_cmd = $align_cmd . " -r $refs_file";
    $align_cmd = $align_cmd . " -P /gscmnt/sata921/info/medseq/cmiller/methylSeq/bratIndex";

    if ($paired_end)
    {
	$align_cmd = $align_cmd . " -1 $scratch_directory/trimmed_reads1.txt";
	$align_cmd = $align_cmd . " -2 $scratch_directory/trimmed_reads2.txt";
	$align_cmd = $align_cmd . " -pe";
	$align_cmd = $align_cmd . " -i $min_insert_size";
	$align_cmd = $align_cmd . " -a $max_insert_size";
    } else {
	$align_cmd = $align_cmd . " -s $scratch_directory/trimmed_reads1.txt";
    }
    $align_cmd = $align_cmd . " -o $scratch_directory/bratout.dat";
    $align_cmd = $align_cmd . " -m 10"; #number of mismatches
    $align_cmd = $align_cmd . " -bs";   #bisulfite option
    $align_cmd = $align_cmd . " -S";    #faster, at the expense of more mem

    $self->status_message("doing alignment");
    $self->status_message("$align_cmd");
    system($align_cmd);

    

    ###################################################
    # deduplicate reads,

    $self->status_message("deduplicating reads");    
    my $dup_cmd = "/gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/remove-dupl";
    $dup_cmd = $dup_cmd . " -r $refs_file"; #reference fastas

    # create a list file with paths to the aligned reads
    # for the record, it's stupid that we have to do this, 
    # since there's only one file
    my ($list_fh, $list_file) = Genome::Sys->create_temp_file();
    $list_fh->print("$scratch_directory/bratout.dat\n");
    $list_fh->close;
    

    if ($paired_end)
    {
    	$dup_cmd = $dup_cmd . " -p $list_file";
    } else {
    	$dup_cmd = $dup_cmd . " -s $list_file";
    }
    $self->status_message("RUN: $dup_cmd");    
    system($dup_cmd);



    #sort the reads prior to sam conversion
    system("sort -nk1 $scratch_directory/bratout.dat.nodupl >$scratch_directory/bratout.dat.nodupl.sorted");


    ###################################################
    # convert to sam format
    # this is harder than it should be because we have to convert
    # the mapped reads, then go back to the fastqs to retrieve
    # the unmapped reads.

    $self->status_message("converting output to SAM format");

    #first do the aligned reads
    my $prevNum = -1;
    my %missing = ();
    my $inFh = IO::File->new( "$scratch_directory/bratout.dat.nodupl.sorted" ) || die "can't open bratout.dat.nodupl\n";
    my $outFh = open (my $samfile, ">$scratch_directory/mapped_reads.sam") || die "Can't open output file.\n";
    while( my $line = $inFh->getline )
    {
	chomp($line);
	my @fields = split("\t" ,$line);
	my @samline = ();

	#---Paired End---------------------------
	if ($paired_end)
	{

	    #name = id
	    push(@samline,$fields[0] . "/1");

	    #strand info goes in flag
	    if ($fields[4] eq "+")
	    {
		push(@samline,"99");
	    } else {
		push(@samline,"83");
	    }

	    # "chr" gets added
	    # $fields[3] = "chr" . $fields[3] unless ($fields[3] =~ /chr/);
	    push(@samline,$fields[3]);

	    #pos
	    push(@samline,$fields[5]);
	    #mapq
	    push(@samline,255);

	    #cigar - includes length
	    push(@samline,length($fields[1]) . "M");

	    #other end of pair
	    push(@samline,$fields[3]);
	    push(@samline,$fields[6]);

	    #default vals for the rest
	    push(@samline,"0");
	    push(@samline,"*");
	    push(@samline,"*");

	    print $samfile join("\t",@samline) . "\n";

	    #now second read - flip positions, etc
	    $samline[0] = $fields[0] . "/2";
	    if ($fields[4] eq "+")
	    {
		$samline[1] = "147";
	    } else {
		$samline[1] = "163";
	    }
	    $samline[3] = $fields[6];
	    $samline[5] = length($fields[2]) . "M"; #cigar
	    $samline[7] = $fields[5];
	    print $samfile join("\t",@samline) . "\n";

	    #---Single End---------------------------
	} else {

	    #name = id
	    push(@samline,$fields[0]);

	    #strand info goes in flag
	    if ($fields[3] eq "+")
	    {
		push(@samline,"0");
	    } else {
		push(@samline,"16");
	    }

	    #"chr" gets added
	    #$fields[2] = "chr" . $fields[2] unless ($fields[2] =~ /chr/);
	    push(@samline,$fields[2]);

	    push(@samline,$fields[4]); #pos
	    push(@samline,255);        #mapq
	    push(@samline,length($fields[1]) . "M"); #cigar
	    #other end of pair
	    push(@samline,$fields[3]);
	    push(@samline,$fields[5]);
	    push(@samline,"0");
	    push(@samline,"*");
	    push(@samline,"*");

	    print $samfile join("\t",@samline) . "\n";
	}

	#also keep track of which sequences didn't get mapped
	$prevNum++;
	while($prevNum < $fields[0])
	{
	    # $self->status_message("missing $prevNum");
	    $missing{$prevNum} = 0;
	    $prevNum++;
	}

	$prevNum = $fields[0];
    }
    $inFh->close;



    ##############################################################################
    # now, add reads that weren't mapped back to sam file. this is a little ugly, 
    # but necessary for the standard pipeline
    $self->status_message("adding unmapped reads to SAM");    

    #---Paired End---------------------------
    if ($paired_end)
    {
        #from first trimmed fastq - unmapped reads
	my $count = 0;
	my $fastqF = IO::File->new( "$scratch_directory/trimmed_reads1.txt" ) || die "can't open $scratch_directory/trimmed_reads1.txt\n";
	while( my $line = $fastqF->getline )
	{   
	    #and if this is one of the sequences that's missing
	    if (exists $missing{$count})
	    {
		chomp($line);
		my @splitline = split("\t",$line);		    
		printUnmappedReadToSam($splitline[0], ("n_" . $count . "/1"), $samfile);
		# also have to handle lines at the end of the fastq that are missing
		# with ids > the highest one output above
		#prevNum will still be equal to the last read output above
	    } elsif ($count > $prevNum) {
		chomp($line);
		my @splitline = split("\t",$line);
		printUnmappedReadToSam($line, ("n_" . $count . "/1"), $samfile);		
	    }
	    $count++;
	}
	$fastqF->close;

	#now from second trimmed fastq - unmapped reads
	$count = 0;
	$fastqF = IO::File->new( "$scratch_directory/trimmed_reads2.txt" ) || die "can't open $scratch_directory/trimmed_reads2.txt\n";
	while( my $line = $fastqF->getline )
	{
	    #if we're on a sequence line
#	    if ($count % 4 == 2)
#	    {
		#and if this is one of the sequences that's missing
		if (exists $missing{$count})
		{
		    chomp($line);
		    my @splitline = split("\t",$line);		    
		    printUnmappedReadToSam($splitline[0], ("n_" .  $count . "/2"), $samfile);

		# also have to handle lines at the end of the fastq that are missing
		# with ids > the highest one output above
		#prevNum will still be equal to the last read output above
		} elsif ($count > $prevNum) {
		    chomp($line);
		    my @splitline = split("\t",$line);		    
		    printUnmappedReadToSam($splitline[0], ("n_" .  $count . "/2"), $samfile);
		}	    
#	    }
	    $count++;
	}
	$fastqF->close;
	
	
	#finally, add the reads where one or more ends was trimmed and set quality scores to 0
	my @files = ("$scratch_directory/trimmed_mates1.seq", "$scratch_directory/trimmed_badMate1.seq",
		     "$scratch_directory/trimmed_mates2.seq", "$scratch_directory/trimmed_badMate2.seq",
		     "$scratch_directory/trimmed_err1.seq", "$scratch_directory/trimmed_err2.seq");
	
	$count = 0;
	foreach my $file (@files)
	{
	    if ( -e $file ){
		$fastqF = IO::File->new( $file ) || die "can't open fastq - $file\n";
		while( my $line = $fastqF->getline )
		{
		    printUnmappedReadToSam($line, ("n_" . $count . "/1"), $samfile);	    
		    $count++;
		}
		$fastqF->close;
	    } else {
		$self->status_message("couldn't open $file - skipped\n");
	    }
	}
	
	

    #---Single End---------------------------
    } else {
	my $count = 0;

	my $fastqF = IO::File->new( "$scratch_directory/trimmed_reads1.txt" ) || die "can't open file: $scratch_directory/trimmed_pair1.fastq\n";
	while( my $line = $fastqF->getline )
	{

	    #if we're on a sequence line
#	    if ($count % 4 == 2)
#	    {
		#and if this is one of the sequences that's missing
		if (exists $missing{$count})
		{
		    chomp($line);
		    my @splitline = split("\t",$line);		    	
		    printUnmappedReadToSam($line, "n_" . $count, $samfile);
		    
		# also have to handle lines at the end of the fastq that are missing
                # with ids > the highest one output above
	        #prevNum will still be equal to the last read output above
		} elsif ($count > $prevNum) {
		    chomp($line);
		    my @splitline = split("\t",$line);		    
		    printUnmappedReadToSam($line, "pn_" . $count, $samfile);
		}
 #	    }

	    $count++;
	}
	$fastqF->close;


	#next,add the reads where one or more ends couldn't be mapped and set quality scores to 0
	my @files = ("$scratch_directory/trimmed_mates1.seq", "$scratch_directory/trimmed_err1.seq");

	foreach my $file (@files)
	{
	    if ( -e $file ){
		$fastqF = IO::File->new( $file ) || die "can't open fastq $file\n";
		while( my $line = $fastqF->getline )
		{
		    printUnmappedReadToSam($line, ("n_" . $count), $samfile);		    
		    $count++;
		}
		$fastqF->close;
	    } else {
		$self->status_message("couldn't open $file - skipped\n");
	    }
	}

    } ##end if paired_end

    $samfile->close;


    #finally, sort that temporary samfile and append it to the output one
    system("sort -nk 1 $scratch_directory/mapped_reads.sam >> $scratch_directory/all_sequences.sam");

    ##for testing - copy the output so I can look at it
    ##system("cp $scratch_directory/* /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch1/");
    ##system("cp $refs_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch1/");



    ###################################################
    # create the methylation map
    my $count_cmd = "/gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/acgt-count";
    $count_cmd = $count_cmd . " -r $refs_file"; #reference fastas
    $count_cmd = $count_cmd . " -P $scratch_directory/map"; #output prefix

    # create a list file with paths to the aligned reads
    # for the record, this is stupid, since there's only one file
    my ($list2_fh, $list2_file) = Genome::Sys->create_temp_file();
    $list2_fh->print("$scratch_directory/bratout.dat.nodupl\n");
    $list2_fh->close;

    if ($paired_end)
    {
	$count_cmd = $count_cmd . " -p $list_file";
    } else {
	$count_cmd = $count_cmd . " -s $list_file";
    }
    $count_cmd = $count_cmd . " -B"; #get a map of methylation events, not a
                                     #a count of every base
    $self->status_message("running acgt count to create methylation map:");
    $self->status_message($count_cmd);
    system($count_cmd);

    $self->status_message("RUN: $count_cmd");    


    ##for testing
    # system("cp $scratch_directory/* /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $list_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $list2_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $refs_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");


    #move the methMap output files to the staging dir
    my $mv_cmd = "mv $scratch_directory/map_forw.txt $staging_directory";
    system($mv_cmd);
    $mv_cmd = "mv $scratch_directory/map_rev.txt $staging_directory";
    system($mv_cmd);


    # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and
    # copied out.
    unless (-s $sam_file) {
        die "The sam output file $sam_file is zero length; something went wrong.";
    }


    #x TODO:
    # If you have any log files from the aligner you're wrapping that you'd like to keep,
    # copy them out into the staging directory here.


    # TODO:
    # Do any last minute checks on the staged data and die if they fail.


    # If we got to here, everything must be A-OK.  AlignmentResult will take over from here
    # to convert the sam file to a BAM and copy everything out.

    return 1;
}

# TODO: This should be the command line used to run your aligner, not just the params.
# sorry for the mis-named method name, it'll get fixed soon.
#
# This will end up in our re-composed sam/bam header.

sub aligner_params_for_sam_header {
    my $self = shift;
    return "brat" . $self->aligner_params;
}

sub fillmd_for_sam {
    return 0;
}



sub printUnmappedReadToSam {
    my ($line, $name, $samfile) = @_;
    my @samline = ();
    #name = id
    push(@samline,$name);

    #strand info goes in flag
    push(@samline,"4");

    push(@samline,"*");
    push(@samline,0); #pos
    push(@samline,0);        #mapq
    push(@samline,length($line) . "X"); #cigar
    push(@samline,"*");
    push(@samline,"0");
    push(@samline,"0");
    push(@samline,"*");
    push(@samline,"*");

    print $samfile join("\t",@samline) . "\n";
}
