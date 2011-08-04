package Genome::Model::Tools::CopyNumber::ReadDepth;

##############################################################################
#
#
#	AUTHOR:		Chris Miller (cmiller@genome.wustl.edu)
#
#	CREATED:	07/01/2011 by CAM.
#
#	NOTES:
#
##############################################################################

# This is all sorts of incomplete - just runs on bams right now, even though
# the R package supports lots more


use strict;
use Genome;
use IO::File;
use Statistics::R;
use File::Basename;
use warnings;
require Genome::Sys;
use FileHandle;


class Genome::Model::Tools::CopyNumber::ReadDepth {
    is => 'Command',
    has => [

        
	bam_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bam file to derive reads from',
	},


	bin_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bin file to derive reads from',
	},

	sample_name => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'sample name - doubles as output dir name',
	},

        read_length => {
            is => 'Integer',
            is_optional => 1,
            doc =>'read length',
            default => '76',
        }

        
        ]
};

sub help_brief {
    "This is all sorts of incomplete - just runs on bams right now, even though the R package supports lots more"
}

sub help_detail {
    "This is all sorts of incomplete - just runs on bams right now, even though the R package supports lots more"
}

#########################################################################



sub execute {
    my $self = shift;
    my $bam_file = $self->bam_file;
    my $bin_file = $self->bin_file;
    my $sample_name = $self->sample_name;
    my $read_length = $self->read_length;
    
    `mkdir $sample_name`;
    `ln -s /gscuser/cmiller/cna/annotations/annotations.$read_length $sample_name/annotations`;

    chdir $sample_name;

    my $pf = open(PARAMSFILE, ">params") || die "Can't open params file.\n";

    #write params file
    print PARAMSFILE "readLength\t$read_length\n";
    print PARAMSFILE "fdr\t0.01\n";
    print PARAMSFILE "overDispersion\t3\n";
    print PARAMSFILE "gcWindowSize\t100\n";
    print PARAMSFILE "percCNGain\t0.05\n";
    print PARAMSFILE "percCNLoss\t0.05\n";
    print PARAMSFILE "maxCores\t4\n";
    print PARAMSFILE "inputType\tbam\n";

    if(defined($bam_file)){
        print PARAMSFILE "bamFile\t$bam_file\n"; #bam file
    } elsif (defined($bin_file)){
        print PARAMSFILE "bamFile\t$bam_file\n"; #bim file
    } else {
        die("either bam_file or bin_file must be specified")
    }

    print PARAMSFILE "binSize\t10000\n";
    print PARAMSFILE "annotationDirectory\tannotations\n"; #annodir
    print PARAMSFILE "outputDirectory\t./\n"; #outdir
    print PARAMSFILE "verbose\tFALSE\n";
    close(PARAMSFILE);    

    my $rf = open(RFILE, ">run.R") || die "Can't open R file for writing.\n";
#    print RFILE "setwd(\"$sample_name\")\n";
    print RFILE "library(readDepth)\n";
    print RFILE "verbose <<- FALSE\n";
    print RFILE "rdo = new(\"rdObject\")\n";
    print RFILE "rdo = readDepth(rdo)\n";
    print RFILE "rdo = rd.mapCorrect(rdo)\n";
    print RFILE "rdo = rd.gcCorrect(rdo)\n";
    print RFILE "segs = rd.cnSegments(rdo)\n";
    print RFILE "writeSegs(segs)\n";
    print RFILE "writeAlts(segs,rdo)\n";
    print RFILE "writeThresholds(rdo)\n";
    print RFILE "writeBins(rdo)\n";
    print RFILE 'write(estimateOd(rdo),paste(rdo@params$annotationDirectory,"/overdispersion",sep=""))\n';

    close(RFILE);
 
    `Rscript run.R`
}
1;
