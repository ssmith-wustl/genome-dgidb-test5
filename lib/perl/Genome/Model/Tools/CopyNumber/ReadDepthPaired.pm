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

	# tumor_bam => {
	#     is => 'String',
	#     is_optional => 1,
	#     doc => 'bam file to count tumor reads from',
	# },

	# normal_bam => {
	#     is => 'String',
	#     is_optional => 1,
	#     doc => 'bam file to count normal reads from',
	# },

	tumor_bins => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bins file to get tumor reads from (output of gmt copy-number bam-window)',
	},

	normal_bins => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'bins file to get normal reads from (output of gmt copy-number bam-window)',
	},
        
        bin_size => {
            is => 'Integer',
            is_optional => 1,
            doc => 'Choose the bin size to use for read counts. Default 10k',
            #todo: script will determine an optimal size',
            default => '10000',
        },

        tumor_read_length => {
            is => 'String',
            is_optional => 1,
            doc =>'tumor read length (can be one integer or a comma-separated list)',
        },

        normal_read_length => {
            is => 'String',
            is_optional => 1,
            doc =>'normal read length (can be one integer or a comma-separated list)',
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
            doc =>'path to the annotation directory that contains all the different readlength annotations',
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

        genome_build => {
            is => 'String',
            is_optional => 0,
            doc =>'genome build - one of "hg18" or "hg19"',
        },

        normal_snp_file => {
            is => 'String',
            is_optional => 1,
            doc =>'het snp sites from the normal genome in gmt bam-readcount format (chr, st, ref, var, refReads, varReads, VAF)',
        },

        tumor_snp_file => {
            is => 'String',
            is_optional => 1,
            doc =>'het snp sites from the tumor genome in gmt bam-readcount format (chr, st, ref, var, refReads, varReads, VAF)',
        },

        just_output_script_files => {
            is => 'Boolean',
            is_optional => 1,
            default => 0,
            doc =>"don't run the R script, just prep everything and dump it into the output directory",
        },
        

        # sex => {
        #     is => 'String',
        #     is_optional => 0,
        #     doc =>'sex of the patient - "male" or "female"',
        # },


        

        ]
};

sub help_brief {
    "rough code for processing two bams, and merging the results into a cnv-hmm compatible output file"
}

sub help_detail {
    "rough code for processing two bams, and merging the results into a cnv-hmm compatible output file"
}

#########################################################################


sub printCoreCode{
    my ($output_directory, $rl, $type, $RFILE) = @_;
    my $name = "rdo." . $type . "." . $rl;
    #first the tumor
    print $RFILE "PARAMSFILE <<- \"" . $output_directory . "/params.$type.$rl\"\n";
    print $RFILE "verbose <<- TRUE\n";
    print $RFILE "$name = new(\"rdObject\")\n";
    print $RFILE "$name = readDepth($name)\n";
    print $RFILE "$name = rd.mapCorrect($name, minMapability=0.60)\n";
    print $RFILE "$name = rd.gcCorrect($name)\n";
    print $RFILE "$name = mergeLibraries($name)\n";
}


#########################################################################

sub execute {
    my $self = shift;
#    my $tumor_bam = $self->tumor_bam;
#    my $normal_bam = $self->normal_bam;
    my $tumor_bam ;
    my $normal_bam;

    my $tumor_bins = $self->tumor_bins;
    my $normal_bins = $self->normal_bins;
#    my $output_map_corrected_bins = $self->output_map_corrected_bins;
    my $output_directory = $self->output_directory;
    my $annotation_directory = $self->annotation_directory;
#    my $bed_directory = $self->bed_directory;
    my $cnvseg_output = $self->cnvseg_output;
    my $per_lib = $self->per_lib;
    my $bin_size = $self->bin_size;
    my $genome_build = $self->genome_build;
    my $tumor_snp_file = $self->tumor_snp_file;
    my $normal_snp_file = $self->normal_snp_file;
#    my $sex = $self->sex;
    my $sex = "male";

    #resolve relative paths to full path
    $output_directory = File::Spec->rel2abs($output_directory);
    $annotation_directory = File::Spec->rel2abs($annotation_directory);
    if(defined($tumor_snp_file)){
        $tumor_snp_file = File::Spec->rel2abs($tumor_snp_file);
    }
    if(defined($normal_snp_file)){
        $normal_snp_file = File::Spec->rel2abs($normal_snp_file);
    }
    #if we have multiple read lengths
    my @tumor_read_lengths=split(",",$self->tumor_read_length);
    my @normal_read_lengths=split(",",$self->normal_read_length);
    

    #open the r file
    my $rf = open(my $RFILE, ">$output_directory/run.R") || die "Can't open R file for writing.\n";
    print $RFILE "library(readDepth)\n";

    foreach my $type (("normal","tumor")){
        my @read_lengths;
        if($type eq "tumor"){
            @read_lengths = @tumor_read_lengths;
        } else {
            @read_lengths = @normal_read_lengths;
        }

        foreach my $rl (@read_lengths){
            my $annotation_path = $annotation_directory . "/" . $genome_build . "." . $rl  . "." . $sex;
            unless ( -d $annotation_path){
                die("no annotations matching $annotation_path");
            }
            
            #write tumor params file
            my $pf = open(PARAMSFILE1, ">$output_directory/params." . $type . "." . $rl) || die "Can't open params file.\n";
            print PARAMSFILE1 "readLength\t$rl\n";
            print PARAMSFILE1 "fdr\t0.01\n";
            print PARAMSFILE1 "verbose\tTRUE\n";
            print PARAMSFILE1 "overDispersion\t3\n";
            print PARAMSFILE1 "gcWindowSize\t100\n";
            print PARAMSFILE1 "percCNGain\t0.05\n";
            print PARAMSFILE1 "percCNLoss\t0.05\n";
            print PARAMSFILE1 "maxCores\t4\n";
            print PARAMSFILE1 "outputDirectory\t$output_directory\n";
            print PARAMSFILE1 "annotationDirectory\t" . $annotation_path . "\n";
            print PARAMSFILE1 "binSize\t$bin_size\n";
            print PARAMSFILE1 "pairedType\t$type\n";

            if($type eq "tumor"){
                if(defined($tumor_bam)){
                    print PARAMSFILE1 "inputType\tbam\n";        
                    $tumor_bam = File::Spec->rel2abs($tumor_bam);
                    print PARAMSFILE1 "bamFile\t$tumor_bam\n"; 
                } elsif (defined($tumor_bins)){
                    print PARAMSFILE1 "inputType\tbins\n";        
                    $tumor_bins = File::Spec->rel2abs($tumor_bins);
                    print PARAMSFILE1 "binFile\t$tumor_bins\n"; 
                } else {
                    die("either tumor_bam or tumor_bins must be defined\n")
                }
            } else {
                if(defined($normal_bam)){
                    print PARAMSFILE1 "inputType\tbam\n";        
                    $normal_bam = File::Spec->rel2abs($normal_bam);
                    print PARAMSFILE1 "bamFile\t$normal_bam\n"; 
                } elsif (defined($normal_bins)){
                    print PARAMSFILE1 "inputType\tbins\n";        
                    $normal_bins = File::Spec->rel2abs($normal_bins);
                    print PARAMSFILE1 "binFile\t$normal_bins\n"; 
                } else {
                    die("either normal_bam or normal_bins must be defined\n")
                }
            }
        
            if($per_lib){
                print PARAMSFILE1 "perLib\tTRUE\n";
            }            
            if(@read_lengths > 1){
                print PARAMSFILE1 "perLibLengths\tTRUE\n";
            }

            if(defined($tumor_snp_file) && ($type eq "tumor")){
                print PARAMSFILE1 "dbSnpVaf\t$tumor_snp_file\n";
            }
            if(defined($normal_snp_file) && ($type eq "normal")){
                print PARAMSFILE1 "dbSnpVaf\t$normal_snp_file\n";
            }

            close(PARAMSFILE1);

            #now dump the appropriate code to the R file
            printCoreCode($output_directory, $rl, $type, $RFILE);
        }

        #merge the data from different read lengths
        my $i;
        print $RFILE "rdo.$type = rdo.$type." . $read_lengths[0] . "\n";
        for($i=1; $i < @read_lengths; $i++){
            print $RFILE "rdo.$type = addObjectBins(rdo." . $type . "," . "rdo." . $type . "." . $read_lengths[$i] . ")\n";
        }

        if(defined($tumor_snp_file) && ($type eq "tumor")){
            print $RFILE "rdo.$type" . '@binParams$med = calculateMedianFromDbsnpSites(rdo.' . $type . ', 2000000, peakWiggle=4)' . "\n";
        }
        if(defined($normal_snp_file) && ($type eq "normal")){
            print $RFILE "rdo.$type" . '@binParams$med = calculateMedianFromDbsnpSites(rdo.' . $type . ', 2000000, peakWiggle=4)' . "\n";
        }

        if($cnvseg_output){
            print $RFILE "writeBins(rdo.$type,file=\"$output_directory/" . $type . "Bins\",cnvHmmFormat=TRUE)\n";
        } else {
            print $RFILE "writeBins(rdo.$type,file=\"$output_directory/" . $type . "Bins\")\n";
        }
    }

    #print cnvhmm input file 
    print $RFILE "writeCnvhmmInput(rdo.normal,rdo.tumor)\n";
    close($RFILE);

    if($self->just_output_script_files){
        return 1;
    }

    #drop into the output directory to make running the R script easier
    chdir $output_directory;
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
