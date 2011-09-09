
package Genome::Model::Tools::Varscan::LohSegments;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# Varscan::FilterVariantCalls    Process somatic pipeline output
#
#    AUTHOR:     Dan Koboldt (dkoboldt@genome.wustl.edu)
#
#    CREATED:    12/09/2009 by D.K.
#    MODIFIED:   12/29/2009 by D.K.
#
#    NOTES:
#
#####################################################################################################################################

use strict;
use warnings;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Varscan::LohSegments {
    is => 'Command',

    has => [                                # specify the command's single-value properties (parameters) <---
        variant_file     => { is => 'Text', doc => "File containing LOH and Germline calls in VarScan-annotation format" , is_optional => 0, is_input => 1},
        min_freq_for_het     => { is => 'Text', doc => "Minimum variant allele frequency in normal to consider a heterozygote" , is_optional => 0, is_input => 1, default => 40},
        max_freq_for_het     => { is => 'Text', doc => "Maximum variant allele frequency in normal to consider a heterozygote" , is_optional => 0, is_input => 1, default => 60},
        output_basename  => { is => 'Number', doc => "Basename for creating output files", is_optional => 1, is_input => 1, default_value => '0.07'},

    ],
    has_param => [
        lsf_resource => { value => 'select[tmp>1000] rusage[tmp=1000]'},
    ]
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Generate LOH Frequency Plots from VarScan Germline+LOH Data"                 
}

sub help_synopsis {
    return <<EOS
    This command generates LOH Frequency Plots from VarScan Germline+LOH Data
    EXAMPLE:    gmt varscan loh-segments --variant-file varScan.output.LOHandGermline.snp --output-basename varScan.output.LOH.segments ...
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS
EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
    my $self = shift;

    ## Get required parameters ##
    my $variant_file = $self->variant_file;
    my $output_basename = $self->output_basename;

    my $min_freq_for_het = $self->min_freq_for_het;
    my $max_freq_for_het = $self->max_freq_for_het;
    
    ## Correct to percentage values if a fraction frequency provided ##
    $min_freq_for_het = 100 * $min_freq_for_het if($min_freq_for_het > 0 && $min_freq_for_het < 1);
    $max_freq_for_het = 100 * $max_freq_for_het if($max_freq_for_het > 0 && $max_freq_for_het < 1);

    my %stats = ();
    $stats{'num_snps'} = $stats{'num_het'} = $stats{'num_loh'} = $stats{'num_germline'} = $stats{'loh_segments'} = 0;

    ## Convert variant file to infile ##

    open(OUTFILE, ">$output_basename.infile");
    print OUTFILE "chrom\tposition\tnfreq\ttfreq\tstatus\n";

    open(SEGMENTS, ">$output_basename.segments");
    print SEGMENTS "chrom\tchr_start\tchr_stop\tnum_snps\tone\n";

    my $input = new FileHandle ($self->variant_file);
    my $lineCounter = 0;
    
    my $loh_chrom = my $loh_start = my $loh_stop = my $loh_snps = 0;
    
    while (<$input>)
    {
            chomp;
            my $line = $_;
            $lineCounter++;		
    
            my @lineContents = split(/\t/, $line);
            my $chrom = $lineContents[0];
            my $pos = $lineContents[1];
            my $nfreq = $lineContents[7];
            my $tfreq = $lineContents[11];
            my $status = $lineContents[13];
            
            $stats{'num_snps'}++;

            $nfreq =~ s/\%//;
            $tfreq =~ s/\%//;
            
            if($nfreq >= $min_freq_for_het && $nfreq <= $max_freq_for_het)
            {
                $stats{'num_het'}++;
                print OUTFILE join("\t", $chrom, $pos, $nfreq, $tfreq, $status) . "\n";
                
                ## If the call was LOH ##
                
                if($status eq "LOH")
                {
                    $stats{'num_loh'}++;
                    ## If we have no LOH region, start one ##
                    
                    if(!$loh_snps)
                    {
                        $loh_chrom = $chrom;
                        $loh_start = $pos;
                        $loh_stop = $pos;
                        $loh_snps = 1;
                    }
                    
                    ## If we're on a different chrom, end any LOH regions ##
                    elsif($chrom ne $loh_chrom)
                    {
                        if($loh_snps > 1)
                        {
                            print SEGMENTS join("\t", $loh_chrom, $loh_start, $loh_stop, $loh_snps, -1) . "\n";
                            $stats{'loh_segments'}++;
                        }
                        ## Also start a new region ##
                        $loh_chrom = $chrom;
                        $loh_start = $pos;
                        $loh_stop = $pos;
                        $loh_snps = 1;
                    }
                    else
                    {
                        ## Extend the LOH region ##
                        
                        $loh_stop = $pos;
                        $loh_snps++;
                    }
                    
                }
                elsif($status eq "Germline")
                {
                    $stats{'num_germline'}++;
                    ## A germline heterozygote will end any LOH regions ##
                    
                    if($loh_snps > 1)
                    {
                        print SEGMENTS join("\t", $loh_chrom, $loh_start, $loh_stop, $loh_snps, -1) . "\n";
                        $stats{'loh_segments'}++;
                    }
                    
                    $loh_chrom = $loh_start = $loh_stop = $loh_snps = 0;
                }
                
                ## Otherwise if we h
            }

    }
    
    close($input);	

    ## Process final LOH region if there was one ##

    if($loh_snps > 1)
    {
        print SEGMENTS join("\t", $loh_chrom, $loh_start, $loh_stop, $loh_snps, -1) . "\n";
        $stats{'loh_segments'}++;
    }


    close(OUTFILE);
    close(SEGMENTS);

    ## Open HTML File ##
    open(INDEX, ">$output_basename.index.html") or die "Can't open outfile: $!\n";
    print INDEX "<HTML><BODY><TABLE CELLSPACING=0 CELLPADDING=5 BORDER=0 WIDTH=\"100%\">\n";
    print INDEX "<TR>\n";
    my $num_printed_in_column = 0;

    open(OUTFILE, ">$output_basename.R") or die "Can't open outfile: $!\n";
    print OUTFILE "snp <- read.table(\"$output_basename.infile\", header=TRUE)\n";
    print OUTFILE "lohsegs <- read.table(\"$output_basename.segments\", header=TRUE)\n";
    print OUTFILE "minus1 <- snp\$pos - snp\$pos - 1\n";

    for(my $chrCounter = 1; $chrCounter <= 24; $chrCounter++)
    {
        my $chrom = $chrCounter;
        $chrom = "X" if($chrCounter == 23);
        $chrom = "Y" if($chrCounter == 24);

        my $outfile = $output_basename . ".$chrom.png";
        my $outfile_dist = $output_basename . ".$chrom.dist.png";
        
        print OUTFILE qq{
png("$outfile", height=300, width=800)
maxpos <- max(snp\$pos[snp\$chrom=="$chrom"])
par(mar=c(4,4,2,2))
plot(snp\$pos[snp\$chrom=="$chrom"], snp\$nfreq[snp\$chrom=="$chrom"], pch=19, cex=0.25, ylim=c(0,100), xlim=c(1,maxpos), xlab="Position on chr$chrom", ylab="Variant Allele Freq", col="blue")
points(snp\$pos[snp\$chrom=="$chrom"], snp\$tfreq[snp\$chrom=="$chrom"], pch=19, cex=0.25, ylim=c(0,100), col="green")
segments(lohsegs\$chr_start[lohsegs\$chrom=="$chrom"], lohsegs\$one[lohsegs\$chrom=="$chrom"], lohsegs\$chr_stop[lohsegs\$chrom=="$chrom"], lohsegs\$one[lohsegs\$chrom=="$chrom"], col="red")
points(snp\$pos[snp\$chrom=="$chrom" & snp\$status=="LOH"], minus1[snp\$chrom=="$chrom" & snp\$status=="LOH"], pch=19, cex=0.5, ylim=c(0,100), col="red")
dev.off()
png("$outfile_dist", height=300, width=800)
par(mar=c(4,4,2,2))
freqDistNormal <- table(cut(snp\$nfreq[snp\$chrom=="$chrom"], seq(0,105,by=5), left=FALSE, right=FALSE))
rownames(freqDistNormal) <- seq(0,100,by=5)
freqDistTumor <- table(cut(snp\$tfreq[snp\$chrom=="$chrom"], seq(0,105,by=5), left=FALSE, right=FALSE))
rownames(freqDistTumor) <- seq(0,100,by=5)
plot(prop.table(freqDistNormal), col="blue", type="l", ylim=c(0, 0.50), xlab="Variant Allele Frequency", ylab="Fraction of SNPs")
lines(prop.table(freqDistTumor), col="green", type="l")
dev.off()
};

        ## Get Image filename ##
        my @temp = split(/\//, $outfile);
        my $numdirs = @temp;
        my $image_filename = $temp[$numdirs - 1];

        my @temp2 = split(/\//, $outfile_dist);
        $numdirs = @temp2;
        my $image_filename_dist = $temp2[$numdirs - 1];


        print INDEX "<TD><A HREF=\"$image_filename\"><IMG SRC=\"$image_filename\" HEIGHT=240 WIDTH=320 BORDER=0></A><BR><A HREF=\"$image_filename_dist\"><IMG SRC=\"$image_filename_dist\" HEIGHT=240 WIDTH=320 BORDER=0></A></TD>\n";
        $num_printed_in_column++;

        if($num_printed_in_column >= 4)
        {
                print INDEX "</TR><TR>\n";
                $num_printed_in_column = 0;
        }

    }
    
    close(OUTFILE);

    system("R --no-save < $output_basename.R");

    print INDEX "</TR></TABLE></BODY></HTML>\n";
    close(INDEX);


    return 1;
}



################################################################################################
# 
#
################################################################################################

sub process_loh_region
{
    
}

1;
