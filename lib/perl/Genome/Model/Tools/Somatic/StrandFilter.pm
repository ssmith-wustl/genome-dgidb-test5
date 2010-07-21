package Genome::Model::Tools::Somatic::StrandFilter;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Readonly;
use Genome::Info::IUB;

class Genome::Model::Tools::Somatic::StrandFilter {
    is => 'Command',
    has => [
       'variant_file' => {
           type => 'String',
           is_input => 1,
           doc => 'List of variant positions in annotation format',
       },
       'output_file' => {
           type => 'String',
           is_input => 1,
           is_output => 1,
           doc => 'File name in which to write output',
       },
       'filtered_file' => {
           type => 'String',
           is_input => 1,
           is_output => 1,
           doc => 'File name in which to write variants that were filtered',
       },       
       'tumor_bam_file' => {
            type => 'String',
            doc => 'Tumor bam file in which to examine reads',
            is_input => 1,
       },
       'min_strandedness' => {
            type => 'String',
            default => '0.01',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum representation of variant allele on each strand',
       },
       'min_read_pos' => {
            type => 'String',
            default => '0.10',
            is_optional => 1,
            is_input => 1,
            doc => 'Minimum average relative distance from start/end of read',
       },
       'max_mm_qualsum_diff' => {
            type => 'String',
            default => '100',
            is_optional => 1,
            is_input => 1,
            doc => 'Maximum difference of mismatch quality sum between variant and reference reads (paralog filter)',
       },
       prepend_chr => {
           is => 'Boolean',
           default => '0',
           is_optional => 1,
           is_input => 1,
           doc => 'prepend the string "chr" to chromosome names. This is primarily used for external/imported bam files.',
       },
       verbose => {
           is => 'Boolean',
           default => '0',
           is_optional => 1,
           is_input => 1,
           doc => 'Print the filtering result for each site.',
       },
       # Make workflow choose 64 bit blades
       lsf_resource => {
            is_param => 1,
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1]',
       },
       lsf_queue => {
            is_param => 1,
            default_value => 'long',
       },
       skip => {
           is => 'Boolean',
           default => '0',
           is_input => 1,
           is_optional => 1,
           doc => "If set to true... this will do nothing! Fairly useless, except this is necessary for workflow.",
       },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
    ]
};

sub help_brief {
    return "This module uses strandedness and read position to further filter somatic variants";
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
    gmt somatic strand-filter --variant-file somatic.snvs --tumor-bam tumor.bam --output-file somatic.snvs.strandfilter 
EOS
}

sub help_detail {                           
    return <<EOS 
This module uses strandedness and read position to further filter somatic variants
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;

    if ($self->skip) {
        $self->status_message("Skipping execution: Skip flag set");
        return 1;
    }
    
    if (($self->skip_if_output_present)&&(-s $self->output_file)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }

    #test architecture to make sure we can run read count program
    unless (`uname -a` =~ /x86_64/) {
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    #check on BAM file
    unless(-e $self->tumor_bam_file) {
        $self->error_message("Tumor bam file: " . $self->tumor_bam_file . " does not exist");
        die;
    }

    unless(-e $self->tumor_bam_file . ".bai") {
        $self->error_message("Tumor bam must be indexed");
        die;
    }


    ## Determine the strandedness and read position thresholds ##
    
    my $min_read_pos = $self->min_read_pos;
    my $max_read_pos = 1 - $min_read_pos;
    
    my $min_strandedness = $self->min_strandedness;
    my $max_strandedness = 1 - $min_strandedness;

    my $max_mm_qualsum_diff = $self->max_mm_qualsum_diff;

    ## Reset counters ##
    
    my %stats = ();
    $stats{'num_variants'} = $stats{'num_fail_strand'} = $stats{'num_fail_pos'} = $stats{'num_no_readcounts'} = $stats{'num_pass_filter'} = $stats{'num_no_allele'} = $stats{'num_fail_mmqs'} = 0;
    $stats{'num_MT_sites_autopassed'} = 0;

    ## Open the output file ##
    
    my $ofh = IO::File->new($self->output_file, "w");
    unless($ofh) {
        $self->error_message("Unable to open " . $self->output_file . " for writing. $!");
        die;
    }


    ## Open the variants file ##

    my $input = new FileHandle ($self->variant_file);

    unless($input) {
        $self->error_message("Unable to open " . $self->variant_file . ". $!");
        die;
    }


    ## Build temp file for positions where readcounts are needed ##

    my ($tfh,$temp_path) = Genome::Utility::FileSystem->create_temp_file;
    unless($tfh) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    $temp_path =~ s/\:/\\\:/g;

    ## Print each line to file, prepending chromosome if necessary ##
    print "Printing variants to temp file...\n";
    while(my $line = $input->getline) {
        chomp $line;
        my ($chr, $start, $stop) = split /\t/, $line;
        if ($self->prepend_chr) {
            $chr = "chr$chr";
            $chr =~ s/MT$/M/;
        };
	
	print $tfh "$chr\t$start\t$stop\n";
    }
    $tfh->close;

    close($input);

    ## Run BAM readcounts in batch mode to get read counts for all positions in file ##

    print "Running BAM Readcounts...\n";
    my $cmd = readcount_program() . " -b 15 " . $self->tumor_bam_file . " -l $temp_path";
    my $readcounts = `$cmd 2>/dev/null`;
    chomp($readcounts) if($readcounts);

    ## Load the results of the readcounts ##
    
    my %readcounts_by_position = ();

    my @readcounts = split(/\n/, $readcounts);
    foreach my $rc_line (@readcounts)
    {
	(my $chrom, my $pos) = split(/\t/, $rc_line);
	$readcounts_by_position{"$chrom\t$pos"} = $rc_line;
    }

    print "Readcounts loaded\n";

    ## Open the filtered output file ##
    
    my $ffh = IO::File->new($self->filtered_file, "w") if($self->filtered_file);



    ## Reopen file for parsing ##

    $input = new FileHandle ($self->variant_file);
    

    ## Parse the variants file ##

    my $lineCounter = 0;
    
    while (<$input>)
    {
            chomp;
            my $line = $_;
            $lineCounter++;

            $stats{'num_variants'}++;
            
#            if($lineCounter <= 10)
 #           {
                (my $chrom, my $chr_start, my $chr_stop, my $ref, my $var) = split(/\t/, $line);
                
		$ref = uc($ref);
		$var = uc($var);
		
                my $query_string = "";
                
                if($self->prepend_chr)
                {
                    $query_string = "chr" . $chrom . ":" . $chr_start . "-" . $chr_stop;
                }
                else
                {
                    $query_string = $chrom . ":" . $chr_start . "-" . $chr_stop;
                }

                ## if the variant allele is an IUPAC code, convert it: ##
                
                if(!($var =~ /[ACGT]/))
                {
                    $var = iupac_to_base($ref, $var);
                }
    
                if($var =~ /[ACGT]/)
                {
		    ## Skip MT chromosome sites,w hich almost always pass ##
	
		    if($chrom eq "MT" || $chrom eq "chrMT")
		    {
			## Auto-pass it to increase performance ##
			$stats{'num_MT_sites_autopassed'}++;
			print $ofh "$line\n";
		    }
#		    elsif($self->prepend_chr && $chrom =~ "random")
#		    {
#			$stats{'num_random_sites_autopassed'}++;
#			print $ofh "$line\n";			
#		    }
		    else
		    {
			## Run Readcounts ##
#			my $cmd = readcount_program() . " -b 15 " . $self->tumor_bam_file . " $query_string";
#			my $readcounts = `$cmd`;
#			chomp($readcounts) if($readcounts);

			my $readcounts = "";
			if($self->prepend_chr)
			{
	   			$readcounts = $readcounts_by_position{"chr$chrom\t$chr_start"} if($readcounts_by_position{"chr$chrom\t$chr_start"});			    
			}
			else
			{
	   			$readcounts = $readcounts_by_position{"$chrom\t$chr_start"} if($readcounts_by_position{"$chrom\t$chr_start"});			    
			}
 

			## Parse the results for each allele ##
	    
			my $ref_result = read_counts_by_allele($readcounts, $ref);
			my $var_result = read_counts_by_allele($readcounts, $var);
			
			if($ref_result && $var_result)
			{
				## Calculate percent-fwd-strand ##
				(my $ref_count, my $ref_map, my $ref_base, my $ref_semq, my $ref_plus, my $ref_minus, my $ref_pos, my $ref_subs, my $ref_mismatch_qual) = split(/\t/, $ref_result);
				(my $var_count, my $var_map, my $var_base, my $var_semq, my $var_plus, my $var_minus, my $var_pos, my $var_subs, my $var_mismatch_qual) = split(/\t/, $var_result);
    
				my $ref_strandedness = my $var_strandedness = 0.50;

				## Use conservative defaults if we can't get mismatch quality sums ##
				$ref_mismatch_qual = 50 if(!$ref_mismatch_qual);
				$var_mismatch_qual = 0 if(!$var_mismatch_qual);
				my $mismatch_qualsum_diff = $var_mismatch_qual - $ref_mismatch_qual;
    
				## Determine ref strandedness ##
				
				if(($ref_plus + $ref_minus) > 0)
				{
				    $ref_strandedness = $ref_plus / ($ref_plus + $ref_minus);
				    $ref_strandedness = sprintf("%.2f", $ref_strandedness);
				}
    
				## Determine var strandedness ##
    
				if(($var_plus + $var_minus) > 0)
				{
				    $var_strandedness = $var_plus / ($var_plus + $var_minus);
				    $var_strandedness = sprintf("%.2f", $var_strandedness);
				}
    
				if($var_count && ($var_plus + $var_minus))
				{
				    ## We must obtain variant read counts to proceed ##
				    
				    ## FAILURE 1: READ POSITION ##
				    
				    if(($var_pos < $min_read_pos))# || $var_pos > $max_read_pos))
				    {
					print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadPos<$min_read_pos\n"if ($self->filtered_file);
					print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tReadPos<$min_read_pos\n"if ($self->verbose);
					$stats{'num_fail_pos'}++;
				    }
				    
				    ## FAILURE 2: Variant is strand-specific but reference is NOT strand-specific ##
				    
				    elsif(($var_strandedness < $min_strandedness || $var_strandedness > $max_strandedness) && ($ref_strandedness >= $min_strandedness && $ref_strandedness <= $max_strandedness))
				    {
					## Print failure to output file if desired ##
					print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tStrandedness<$min_strandedness\n"if ($self->filtered_file);
					print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tStrandedness<$min_strandedness\n"if ($self->verbose);
					$stats{'num_fail_strand'}++;
				    }
				    
				    ## FAILURE 3: Paralog filter for sites where variant allele mismatch-quality-sum is significantly higher than reference allele mmqs
				    
				    elsif($mismatch_qualsum_diff> $max_mm_qualsum_diff)
				    {
					## Print failure to output file if desired ##
					print $ffh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMismatchQualsum:$var_mismatch_qual-$ref_mismatch_qual>$max_mm_qualsum_diff\n" if ($self->filtered_file);
					print "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tMismatchQualsum:$var_mismatch_qual-$ref_mismatch_qual>$max_mm_qualsum_diff" if ($self->verbose);
					$stats{'num_fail_mmqs'}++;					
				    }
				    ## SUCCESS: Pass Filter ##				
				    else
				    {
					$stats{'num_pass_filter'}++;
					## Print output, and append strandedness information ##
					print $ofh "$line\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\t$ref_mismatch_qual\t$var_mismatch_qual\t$mismatch_qualsum_diff\n";
					print "$line\t\t$ref_pos\t$var_pos\t$ref_strandedness\t$var_strandedness\tPASS\n" if($self->verbose);
				    }
				}
				else
				{
				    $stats{'num_no_readcounts'}++;
				    print $ffh "$line\tno_reads\n" if($self->filtered_file);
				    print "$chrom\t$chr_start\t$chr_stop\t$ref\t$var\tFAIL no reads in $var_result\n" if($self->verbose);        
				}
			}
			else
			{
#			    $self->error_message("Unable to get read counts for $ref/$var at position $chrom\t$chr_start\t$chr_stop");
#			    die;                
			}			
		    }

                }
		else
		{
		    print $ffh "$line\tno_allele\n" if($self->filtered_file);
		    print "$line\tFailure: Unable to determine allele!\n" if($self->verbose);        
		    $stats{'num_no_allele'}++;
		}
#            }
    }
    
    close($input);

    print $stats{'num_variants'} . " variants\n";
    print $stats{'num_MT_sites_autopassed'} . " MT sites were auto-passed\n";
    print $stats{'num_random_sites_autopassed'} . " chrN_random sites were auto-passed\n" if($stats{'num_random_sites_autopassed'});
    print $stats{'num_no_allele'} . " failed to determine variant allele\n";
    print $stats{'num_no_readcounts'} . " failed to get readcounts for variant allele\n";
    print $stats{'num_fail_pos'} . " had read position < $min_read_pos\n";
    print $stats{'num_fail_strand'} . " had strandedness < $min_strandedness\n";
    print $stats{'num_fail_mmqs'} . " had mismatch qualsum difference > $max_mm_qualsum_diff\n";
    print $stats{'num_pass_filter'} . " passed the strand filter\n";

    return 1;
}



#############################################################
# Readcount_Program - the path to BAM-readcounts
#
#############################################################

sub readcount_program {
    return "/gscuser/dlarson/src/bamsey/readcount/trunk/bam-readcount-test2 -f /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa";
#    return "/gscuser/dlarson/src/bamsey/readcount/trunk/bam-readcount -f /gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa";
}






#############################################################
# Read_Counts_By_Allele - parse out readcount info for an allele
#
#############################################################

sub read_counts_by_allele
{
	(my $line, my $allele) = @_;
	
	my @lineContents = split(/\t/, $line);
	my $numContents = @lineContents;
	
	for(my $colCounter = 5; $colCounter < $numContents; $colCounter++)
	{
		my $this_allele = $lineContents[$colCounter];
		my @alleleContents = split(/\:/, $this_allele);
		if($alleleContents[0] eq $allele)
		{
			my $numAlleleContents = @alleleContents;
			
			return("") if($numAlleleContents < 8);
			
			my $return_string = "";
			my $return_sum = 0;
			for(my $printCounter = 1; $printCounter < $numAlleleContents; $printCounter++)
			{
				$return_sum += $alleleContents[$printCounter];
				$return_string .= "\t" if($return_string);
				$return_string .= $alleleContents[$printCounter];
			}
			
                        return($return_string);
                        
#			if($return_sum)
#			{
#				return($return_string);
#			}
#			else
#			{
#				return("");
#			}
		}
	}
	
	return("");
}

#############################################################
# ParseBlocks - takes input file and parses it
#
#############################################################

sub iupac_to_base
{
	(my $allele1, my $allele2) = @_;
	
	return($allele2) if($allele2 eq "A" || $allele2 eq "C" || $allele2 eq "G" || $allele2 eq "T");
	
	if($allele2 eq "M")
	{
		return("C") if($allele1 eq "A");
		return("A") if($allele1 eq "C");
		return("A");	## Default for triallelic variant 
	}
	elsif($allele2 eq "R")
	{
		return("G") if($allele1 eq "A");
		return("A") if($allele1 eq "G");
		return("A"); 	## Default for triallelic variant 
	}
	elsif($allele2 eq "W")
	{
		return("T") if($allele1 eq "A");
		return("A") if($allele1 eq "T");
		return("A");	## Default for triallelic variant 
	}
	elsif($allele2 eq "S")
	{
		return("C") if($allele1 eq "G");
		return("G") if($allele1 eq "C");
		return("C");	## Default for triallelic variant 
	}
	elsif($allele2 eq "Y")
	{
		return("C") if($allele1 eq "T");
		return("T") if($allele1 eq "C");
		return("C");	## Default for triallelic variant 
	}
	elsif($allele2 eq "K")
	{
		return("G") if($allele1 eq "T");
		return("T") if($allele1 eq "G");
		return("G");	## Default for triallelic variant 
	}	
	
	return($allele2);
}



1;
