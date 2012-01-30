package Genome::Model::Tools::CopyNumber::ReadDepth;

##############################################################################
#
#
#	AUTHOR:		Chris Miller (cmiller@genome.wustl.edu)
#	CREATED:	07/01/2011 by CAM.
#	NOTES:
#
##############################################################################

use strict;
use Genome;
use IO::File;
use Statistics::R;
use File::Basename;
use warnings;
require Genome::Sys;
use FileHandle;
use File::Spec;
use Digest::MD5 qw(md5_hex);

class Genome::Model::Tools::CopyNumber::ReadDepth {
    is => 'Command',
    has => [

	bam_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bam file to counts reads from (Choose one of bin_file, bam_file, or bed_directory)',
	},


	bin_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'pre-binned read counts from bamwindow (Choose one of bin_file, bam_file, or bed_directory)',
	},


	bed_directory => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'directory containing bed files of mapped reads, one per chromosome, named 1.bed, 2.bed ... Expects 1-based coords. (Choose one of bin_file, bam_file, or bed_directory)',
	},

        bin_size => {
            is => 'Integer',
            is_optional => 1,
            doc => 'Choose the bin size to use for read counts. Default is that the script will determine an optimal size',
            default => '76',
        },

        read_length => {
            is => 'Integer',
            is_optional => 1,
            doc =>'read length',
            default => '76',
        },

        # output_map_corrected_bins => {
        #     is => 'Boolean',
        #     is_optional => 1,
        #     doc =>'output a listing of the bins and their read-depths after mapability correction',
        #     default => 0,
        # },

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

        cnvseg_output => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc =>'tweak the output to be compatible with cnvSeg (cnvHMM)',
        },

        per_lib => {
            is => 'Boolean',
            is_optional => 1,
            default => 1,
            doc =>'get window counts and do normalization on a per-library basis',
        },

        min_mapability => {
            is => 'Float',
            is_optional => 1,
            default => 0.60,
            doc =>'the minimum fraction of a window that must be mappable in order to be considered',
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
    my $read_length = $self->read_length;
#    my $output_map_corrected_bins = $self->output_map_corrected_bins;
    my $do_segmentation = $self->do_segmentation;
    my $output_directory = $self->output_directory;
    my $annotation_directory = $self->annotation_directory;
    my $bed_directory = $self->bed_directory;
    my $cnvseg_output = $self->cnvseg_output;
    my $per_lib = $self->per_lib;

    #resolve relative paths to full path
    $output_directory = File::Spec->rel2abs($output_directory);
    $annotation_directory = File::Spec->rel2abs($annotation_directory);

    #write params file
    my $pf = open(PARAMSFILE, ">$output_directory/params") || die "Can't open params file.\n";
    print PARAMSFILE "readLength\t$read_length\n";
    print PARAMSFILE "fdr\t0.01\n";
    print PARAMSFILE "verbose\tTRUE\n";
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
        print PARAMSFILE "binFile\t$bin_file\n"; #bin file
        print PARAMSFILE "inputType\tbins\n";
    } elsif (defined($bed_directory)){
        $bed_directory = File::Spec->rel2abs($bed_directory);
        print PARAMSFILE "bedDirectory\t$bed_directory\n"; #bed dir
        print PARAMSFILE "inputType\tbed\n";
    } else {
        die("either bam_file, bin_file, or bed_directory must be specified")
    }

    print PARAMSFILE "binSize\t10000\n";
    close(PARAMSFILE);


    #drop into the output directory to make running the R script easier
    chdir $output_directory;
    my $rf = open(RFILE, ">run.R") || die "Can't open R file for writing.\n";

##need to make sure latest version of readDepth is installed
##sessionInfo()$otherPkgs$readDepth$Version
    print RFILE "PARAMSFILE <<- \"" . $output_directory . "/params\"\n";
    print RFILE "library(readDepth)\n";
    #print RFILE "verbose <<- FALSE\n";
    print RFILE "rdo = new(\"rdObject\")\n";
    print RFILE "rdo = readDepth(rdo)\n";
    print RFILE "rdo = rd.mapCorrect(rdo, minMapability=0.60)\n";
    # if ($output_map_corrected_bins){
    #     if($cnvseg_output){
    #         print RFILE 'writeBins(rdo,filename="bins.map", cnvHmmFormat=TRUE)' . "\n";
    #     } else {
    #         print RFILE 'writeBins(rdo,filename="bins.map")' . "\n";
    #     }
    # }
    print RFILE "rdo = rd.gcCorrect(rdo)\n";
    print RFILE "rdo = mergeLibraries(rdo)\n";
    if($cnvseg_output){
        print RFILE "writeBins(rdo,cnvHmmFormat=TRUE)\n";
    } else {
        print RFILE "writeBins(rdo)\n";
    }


    if ($do_segmentation){
        print RFILE "segs = rd.cnSegments(rdo)\n";
        print RFILE "writeSegs(segs)\n";
        print RFILE "writeAlts(segs,rdo)\n";
        print RFILE "writeThresholds(rdo)\n";
    }

#    print RFILE 'write(estimateOd(rdo),paste(rdo@params$annotationDirectory,"/overdispersion",sep=""))' . "\n";

    close(RFILE);

#    my $cmd = "R --vanilla --slave \< run.R";
    my $cmd = "Rscript run.R";
    my $return = Genome::Sys->shellcmd(
	cmd => "$cmd",
        );
    unless($return) {
	$self->error_message("Failed to execute: Returned $return");
	die $self->error_message;
    }
    return $return;
}
1;
