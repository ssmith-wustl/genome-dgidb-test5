package Genome::Model::Tools::CopyNumber::ReadDepthPaired;

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
#use Digest::MD5 qw(md5_hex);

class Genome::Model::Tools::CopyNumber::ReadDepthPaired {
    is => 'Command',
    has => [

	tumor_bam => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bam file to count tumor reads from',
	},

	normal_bam => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bam file to count normal reads from',
	},

	tumor_bins => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bins file to get tumor reads from',
	},

	normal_bins => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bins file to get normal reads from',
	},
        
        bin_size => {
            is => 'Integer',
            is_optional => 1,
            doc => 'Choose the bin size to use for read counts. Default 10k',
            #todo: script will determine an optimal size',
            default => '10000',
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

        # do_segmentation => {
        #     is => 'Boolean',
        #     is_optional => 1,
        #     doc =>'run segmentation on the bins to get discrete regions of copy number (CBS algorithm)',
        #     default => 1,
        # },

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
            default => 1,
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
    "rough code for processing two bams, and merging the results into a cnv-hmm compatible output file"
}

sub help_detail {
    "rough code for processing two bams, and merging the results into a cnv-hmm compatible output file"
}

#########################################################################

sub execute {
    my $self = shift;
    my $tumor_bam = $self->tumor_bam;
    my $normal_bam = $self->normal_bam;
    my $tumor_bins = $self->tumor_bins;
    my $normal_bins = $self->normal_bins;
#    my $bin_file = $self->bin_file;
    my $read_length = $self->read_length;
#    my $output_map_corrected_bins = $self->output_map_corrected_bins;
    my $output_directory = $self->output_directory;
    my $annotation_directory = $self->annotation_directory;
#    my $bed_directory = $self->bed_directory;
    my $cnvseg_output = $self->cnvseg_output;
    my $per_lib = $self->per_lib;
    my $bin_size = $self->bin_size;

    #resolve relative paths to full path
    $output_directory = File::Spec->rel2abs($output_directory);
    $annotation_directory = File::Spec->rel2abs($annotation_directory);

    #write tumor params file
    my $pf = open(PARAMSFILE1, ">$output_directory/paramsTumor") || die "Can't open params file.\n";
    print PARAMSFILE1 "readLength\t$read_length\n";
    print PARAMSFILE1 "fdr\t0.01\n";
    print PARAMSFILE1 "verbose\tTRUE\n";
    print PARAMSFILE1 "overDispersion\t3\n";
    print PARAMSFILE1 "gcWindowSize\t100\n";
    print PARAMSFILE1 "percCNGain\t0.05\n";
    print PARAMSFILE1 "percCNLoss\t0.05\n";
    print PARAMSFILE1 "maxCores\t4\n";
    print PARAMSFILE1 "outputDirectory\t$output_directory\n";
    print PARAMSFILE1 "annotationDirectory\t$annotation_directory\n";
    print PARAMSFILE1 "binSize\t$bin_size\n";

    if(defined($tumor_bam)){
        print PARAMSFILE1 "inputType\tbam\n";        
        $tumor_bam = File::Spec->rel2abs($tumor_bam);
        print PARAMSFILE1 "bamFile\t$tumor_bam\n"; 
    } elsif (defined($tumor_bam)){
        print PARAMSFILE1 "inputType\tbins\n";        
        $tumor_bam = File::Spec->rel2abs($tumor_bins);
        print PARAMSFILE1 "bamFile\t$tumor_bins\n"; 
    } else {
        die("either tumor_bam or tumor_bins must be defined\n")
    }

    if($per_lib){
        print PARAMSFILE1 "perLib\tTRUE\n";
    }


    close(PARAMSFILE1);

    #write normal params file
    my $pf2 = open(PARAMSFILE2, ">$output_directory/paramsNormal") || die "Can't open params file.\n";
    print PARAMSFILE2 "readLength\t$read_length\n";
    print PARAMSFILE2 "fdr\t0.01\n";
    print PARAMSFILE2 "verbose\tTRUE\n";
    print PARAMSFILE2 "overDispersion\t3\n";
    print PARAMSFILE2 "gcWindowSize\t100\n";
    print PARAMSFILE2 "percCNGain\t0.05\n";
    print PARAMSFILE2 "percCNLoss\t0.05\n";
    print PARAMSFILE2 "maxCores\t4\n";
    print PARAMSFILE2 "outputDirectory\t$output_directory\n";
    print PARAMSFILE2 "annotationDirectory\t$annotation_directory\n";
    print PARAMSFILE2 "binSize\t$bin_size\n";
    print PARAMSFILE2 "inputType\tbam\n";        

    if(defined($normal_bam)){
        print PARAMSFILE2 "inputType\tbam\n";        
        $normal_bam = File::Spec->rel2abs($normal_bam);
        print PARAMSFILE2 "bamFile\t$normal_bam\n"; 
    } elsif (defined($normal_bam)){
        print PARAMSFILE2 "inputType\tbins\n";        
        $normal_bam = File::Spec->rel2abs($normal_bins);
        print PARAMSFILE2 "bamFile\t$normal_bins\n"; 
    } else {
        die("either normal_bam or normal_bins must be defined\n")
    }

    if($per_lib){
        print PARAMSFILE2 "perLib\tTRUE\n";
    }

    $normal_bam = File::Spec->rel2abs($normal_bam);
    print PARAMSFILE2 "bamFile\t$normal_bam\n";     
    close(PARAMSFILE2);


    #drop into the output directory to make running the R script easier
    chdir $output_directory;
    my $rf = open(RFILE, ">run.R") || die "Can't open R file for writing.\n";

##need to make sure latest version of readDepth is installed
##sessionInfo()$otherPkgs$readDepth$Version

    print RFILE "library(readDepth)\n";

    #first the tumor
    print RFILE "PARAMSFILE <<- \"" . $output_directory . "/paramsTumor\"\n";
    #print RFILE "verbose <<- FALSE\n";
    print RFILE "rdo = new(\"rdObject\")\n";
    print RFILE "rdo = readDepth(rdo)\n";
    print RFILE "rdo = rd.mapCorrect(rdo, minMapability=0.60)\n";
    print RFILE "rdo = rd.gcCorrect(rdo)\n";
    print RFILE "rdo = mergeLibraries(rdo)\n";
    if($cnvseg_output){
        print RFILE "writeBins(rdo,file=\"$output_directory/tumorBins\",cnvHmmFormat=TRUE)\n";
    } else {
        print RFILE "writeBins(rdo,file=\"$output_directory/tumorBins\")\n";
    }

    #first the tumor
    print RFILE "PARAMSFILE <<- \"" . $output_directory . "/paramsNormal\"\n";
    #print RFILE "verbose <<- FALSE\n";
    print RFILE "rdo2 = new(\"rdObject\")\n";
    print RFILE "rdo2 = readDepth(rdo2)\n";
    print RFILE "rdo2 = rd.mapCorrect(rdo2, minMapability=0.60)\n";
    print RFILE "rdo2 = rd.gcCorrect(rdo2)\n";
    print RFILE "rdo2 = mergeLibraries(rdo2)\n";
    if($cnvseg_output){
        print RFILE "writeBins(rdo2,file=\"$output_directory/tumorBins\",cnvHmmFormat=TRUE)\n";
    } else {
        print RFILE "writeBins(rdo2,file=\"$output_directory/tumorBins\")\n";
    }

    #print cnvhmm input file 
    print RFILE "writeCnvhmmInput(rdo,rdo2)\n";
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
