
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

    ## Convert variant file to infile ##

    open(OUTFILE, ">$output_basename.infile");
    print OUTFILE "chrom\tposition\tnfreq\ttfreq\tstatus\n";

    my $input = new FileHandle ($self->variant_file);
    my $lineCounter = 0;
    
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

            $nfreq =~ s/\%//;
            $tfreq =~ s/\%//;
            
            print OUTFILE join("\t", $chrom, $pos, $nfreq, $tfreq, $status) . "\n";
    }
    
    close($input);	
    close(OUTFILE);

    ## Open HTML File ##
    open(INDEX, ">$output_basename.index.html") or die "Can't open outfile: $!\n";
    print INDEX "<HTML><BODY><TABLE CELLSPACING=0 CELLPADDING=5 BORDER=0 WIDTH=\"100%\">\n";
    print INDEX "<TR>\n";
    my $num_printed_in_column = 0;

    open(OUTFILE, ">$output_basename.R") or die "Can't open outfile: $!\n";
    print OUTFILE "snp <- read.table(\"$variant_file.infile\", header=TRUE)\n";
    print OUTFILE "minus1 <- snp\$pos - snp\$pos - 1\n";

    for(my $chrCounter = 1; $chrCounter <= 24; $chrCounter++)
    {
        my $chrom = $chrCounter;
        $chrom = "X" if($chrCounter == 23);
        $chrom = "Y" if($chrCounter == 24);

        my $outfile = $output_basename . "$chrom.png";
       
        
        print OUTFILE qq{
png("$outfile", height=300, width=800)
maxpos <- max(snp\$pos[snp\$chrom=="$chrom"])
plot(snp\$pos[snp\$chrom=="$chrom"], snp\$nfreq[snp\$chrom=="$chrom"], pch=19, cex=0.25, ylim=c(0,100), xlim=c(1,maxpos), xlab="Position on chr$chrom", ylab="Variant Allele Freq", col="blue")
points(snp\$pos[snp\$chrom=="$chrom"], snp\$tfreq[snp\$chrom=="$chrom"], pch=19, cex=0.25, ylim=c(0,100), col="green")
points(snp\$pos[snp\$chrom=="$chrom" & snp\$status=="LOH"], minus1[snp\$chrom=="$chrom" & snp\$status=="LOH"], pch=19, cex=0.25, ylim=c(0,100), col="red")
dev.off()
};

        ## Get Image filename ##
        my @temp = split(/\//, $outfile);
        my $numdirs = @temp;
        my $image_filename = $temp[$numdirs - 1];

        print INDEX "<TD><A HREF=\"$image_filename\"><IMG SRC=\"$image_filename\" HEIGHT=240 WIDTH=320 BORDER=0></A></TD>\n";
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


1;
