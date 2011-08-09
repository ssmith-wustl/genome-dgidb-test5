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
use File::Spec;

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


	bed_directory => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'directory containing bed files of mapped reads (one per chromosome, named 1.bed, 2.bed ...) (1-based coords)',
	},

#	sample_name => {
#	    is => 'String',
#	    is_optional => 0,
#	    doc => 'sample name - doubles as output dir name',
#	},

        read_length => {
            is => 'Integer',
            is_optional => 1,
            doc =>'read length',
            default => '76',
        },
        
        output_map_corrected_bins => {
            is => 'Boolean',
            is_optional => 1,
            doc =>'output a listing of the bins and their read-depths after mapability correction',
            default => 0,
        },

        do_segmentation => {
            is => 'Boolean',
            is_optional => 1,
            doc =>'run segmentation on the bins to get discrete regions of copy number (CBS algorithm)',
            default => 1,
        },

        # do_plotting => {
        #     is => 'Boolean',
        #     is_optional => 1,
        #     doc =>'output a whole-genome plot',
        #     default => 1,
        # },

        output_directory => {
            is => 'String',
            is_optional => 0,
            doc =>'path to the output directory',
        },

        annotation_directory => {
            is => 'String',
            is_optional => 0,
            doc =>'path to the annotation directory',
        },

        
        
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
#    my $sample_name = $self->sample_name;
    my $read_length = $self->read_length;
    my $output_map_corrected_bins = $self->output_map_corrected_bins;
    my $do_segmentation = $self->do_segmentation;
    my $output_directory = $self->output_directory;
    my $annotation_directory = $self->annotation_directory;
    my $bed_directory = $self->bed_directory;
#    `mkdir $sample_name`;
#    `ln -s /gscuser/cmiller/cna/annotations/annotations.$read_length $sample_name/annotations`;


    #resolve relative paths to full path
    $output_directory = File::Spec->rel2abs($output_directory);
    $annotation_directory = File::Spec->rel2abs($annotation_directory);

    my $pf = open(PARAMSFILE, ">$output_directory/params") || die "Can't open params file.\n";

    #write params file
    print PARAMSFILE "readLength\t$read_length\n";
    print PARAMSFILE "fdr\t0.01\n";
    print PARAMSFILE "overDispersion\t3\n";
    print PARAMSFILE "gcWindowSize\t100\n";
    print PARAMSFILE "percCNGain\t0.05\n";
    print PARAMSFILE "percCNLoss\t0.05\n";
    print PARAMSFILE "maxCores\t4\n";
    print PARAMSFILE "outputDirectory\t$output_directory\n";
    print PARAMSFILE "annotationDirectory\t$annotation_directory\n";

    if(defined($bam_file)){
        $bam_file = File::Spec->rel2abs($bam_file);
        print PARAMSFILE "bamFile\t$bam_file\n"; #bam file
        print PARAMSFILE "inputType\tbam\n";
    } elsif (defined($bin_file)){
        $bin_file = File::Spec->rel2abs($bin_file);
        print PARAMSFILE "binFile\t$bin_file\n"; #bim file
        print PARAMSFILE "inputType\tbins\n";
    } elsif (defined($bed_directory)){
        $bed_directory = File::Spec->rel2abs($bed_directory);
        print PARAMSFILE "bedDirectory\t$bed_directory\n"; #bim file
        print PARAMSFILE "inputType\tbed\n";
    } else {
        die("either bam_file, bin_file, or bed_directory must be specified")
    }

    print PARAMSFILE "binSize\t10000\n";
    print PARAMSFILE "verbose\tFALSE\n";
    close(PARAMSFILE);

    #drop into the output directory to make running the R script easier
    chdir $output_directory;

    my $rf = open(RFILE, ">run.R") || die "Can't open R file for writing.\n";

##need to make sure latest version of readDepth is installed
##sessionInfo()$otherPkgs$readDepth$Version


    print RFILE "library(readDepth)\n";
    print RFILE "verbose <<- FALSE\n";
    print RFILE "rdo = new(\"rdObject\")\n";
    print RFILE "rdo = readDepth(rdo)\n";
    print RFILE "rdo = rd.mapCorrect(rdo, minMapability=0.60)\n";
    if ($output_map_corrected_bins){
        print RFILE 'writeBins(rdo,filename="bins.map")' . "\n";
    }    
    print RFILE "rdo = rd.gcCorrect(rdo)\n";    


    if ($do_segmentation){
        print RFILE "segs = rd.cnSegments(rdo)\n";
        print RFILE "writeSegs(segs)\n";
        print RFILE "writeAlts(segs,rdo)\n";
        print RFILE "writeThresholds(rdo)\n";
    }

    print RFILE "writeBins(rdo)\n";
    print RFILE 'write(estimateOd(rdo),paste(rdo@params$annotationDirectory,"/overdispersion",sep=""))' . "\n";

    close(RFILE);
 
    `Rscript run.R`
}
1;
