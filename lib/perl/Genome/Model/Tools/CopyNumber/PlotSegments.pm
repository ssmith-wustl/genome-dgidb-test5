package Genome::Model::Tools::CopyNumber::PlotSegments;

##############################################################################
# 
#					
#	AUTHOR:		Chris Miller (cmiller@genome.wustl.edu)
#
#	CREATED:	05/05/2011 by CAM.
#	MODIFIED:
#
#	NOTES:	
#			
##############################################################################

use strict;
use Genome;
use IO::File;
use Statistics::R;
use File::Temp;
use warnings;
require Genome::Sys;

class Genome::Model::Tools::CopyNumber::PlotSegments {
    is => 'Command',
    has => [


	chr => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'If supplied, only that chromosome will be plotted, otherwise produces a whole-genome plot',
	},

	segment_files => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'comma-seperated list of files containing the segments to be plotted. Expects CBS-lite output, with columns: chr, start, stop, #bins, copyNumber',
	},

	gain_threshold => {
	    is => 'Float',
	    is_optional => 1,
	    default => 2.5, 
	    doc => 'Threshold for coloring a segment as a gain',
	},

	loss_threshold => {
	    is => 'Float',
	    is_optional => 1,
	    doc => 'Threshold for coloring a segment as a loss',
	    default => 1.5, 
	},

	# male_sex_loss_threshold => {
	#     is => 'Float',
	#     is_optional => 0,
	#     doc => 'Threshold for coloring X/Y in males as a gain',
	#     default => 1.5,
	# },

	# male_sex_gain_threshold => {
	#     is => 'Float',
	#     is_optional => 0,
	#     doc => 'Threshold for coloring X/Y in males as a loss',
	#     default => 0.5,
	# },


	log_input => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'Set this flag if input copy numbers are expressed as log-rations, as opposed to absolute copy number',
	},

	log_plot => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'Set this flag if you want a log-scaled plot, as opposed to absolute copy number',
	},

	highlights => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'file containing regions to highlight, in bed format',
	},

	lowres => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'make CN segments appear larger than they actually are for visibility. Without this option, many focal CNs will not be visible on low res plots',
	},

	lowres_min => {
	    is => 'Integer',
	    is_optional => 1,
	    doc => 'if lowres is enabled, segments longer than this many bp (and < lowres_max) will be scaled up to the lowres_max value for visibility',
	    default => '100000'
	},

	lowres_max => {
	    is => 'Integer',
	    is_optional => 1,
	    doc => 'if lowres is enabled, segments shorter than this many bp (and > lowres_min) will be scaled up to the lowres_max value for visibility',
	    default => '5000000'
	},


	ymax => {
	    is => 'Float',
	    is_optional => 1,
	    doc => 'Set the max val of the y-axis',
	},


	hide_normal => {
	    is => 'Boolean',
	    is_optional => 1,
	    doc => 'Plot normal segments in addition to gain and loss',
	    default => 0,
	},

	rcommands_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'an output file for your R commands - defaults to /tmp/<timestamp>.R',
	},

	output_pdf => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'pdf file to write output to',	    
	},

       	entrypoints_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'entrypoints to be used for plotting - note that male/female needs to specified here',
	    default => "/gscmnt/sata921/info/medseq/cmiller/annotations/entrypoints.hg18.female",
	},

	plot_height => {
	    is => 'Float',
	    is_optional => 1,
	    default => 4, 
	    doc => 'height of each plot',
	},

	plot_width => {
	    is => 'Float',
	    is_optional => 1,
	    default => 8, 
	    doc => 'width of each plot',
	},

	# ylab => {
	#     is => 'String',
	#     is_optional => 1,
	#     default => "Copy Number", 
	#     doc => 'y-axis labels',
	# },


	# xmin => {
	#     is => 'String',
	#     is_optional => 1,
	#     doc => '',
	# },

	# xmax => {
	#     is => 'String',
	#     is_optional => 1,
	#     doc => '',
	# },

    ]
};

sub help_brief {
    "generate a plot of copy number alterations"
}

sub help_detail {
    "generate a plot of copy number alterations from "
}



#########################################################################

sub execute {
    my $self = shift;   
    my $chr = $self->chr;
    my $segment_files = $self->segment_files;
    my $gain_threshold = $self->gain_threshold;
    my $loss_threshold = $self->loss_threshold;
    # my $male_sex_loss_threshold = $self->male_sex_loss_threshold;
    # my $male_sex_gain_threshold = $self->male_sex_gain_threshold;
    my $log_input = $self->log_input;
    my $log_plot = $self->log_plot;
    my $highlights = $self->highlights;
    my $lowres = $self->lowres;
    my $lowres_min = $self->lowres_min;
    my $lowres_max = $self->lowres_max;
    my $ymax = $self->ymax;
    my $hide_normal = $self->hide_normal;
    my $entrypoints_file = $self->entrypoints_file;
    my $output_pdf = $self->output_pdf;
    my $rcommands_file = $self->rcommands_file;
    my $plot_height = $self->plot_height;
    my $plot_width = $self->plot_width;
    # my $ylab = $self->ylab;



    my @infiles = split(",",$segment_files);
    

    #set up a temp file for the R commands (todo use real tmp methods)
    unless (defined($rcommands_file)){
	$rcommands_file = "/tmp/" . `date +%s%N`;
	chomp($rcommands_file);
	$rcommands_file = $rcommands_file . ".R";
    }

    #open the R file
    open(R_COMMANDS,">$rcommands_file") || die "can't open $rcommands_file for writing\n";

    #todo - what's an easier way to source this R file?
    print R_COMMANDS "source(\"~cmiller/gscCode/genome/lib/perl/Genome/Model/Tools/CopyNumber/PlotSegments.R\")\n";


    #set up pdf parameters
    my $docwidth = $plot_width;
    my $docheight = $plot_height * @infiles;
    print "$docwidth x $docheight\n";
    print R_COMMANDS "pdf(file=\"" . $output_pdf . "\",width=" .$docwidth .",height=" . $docheight . ")\n";


    #set up the plotting space
    print R_COMMANDS "par(xaxs=\"i\", xpd=FALSE, mfrow=c(" . @infiles . ",1), oma=c(1,1,1,1), mar=c(1,3,1,1))\n";


    #draw the plots for each set of segments
    foreach my $infile (@infiles){
	print R_COMMANDS "plotSegments(";

	#first the core stuff
	if(defined($chr)){
	    print R_COMMANDS "chr=" . $chr;
	} else {
	    print R_COMMANDS "chr=\"ALL\"";
	}
	print R_COMMANDS ", filename=\"" . $infile . "\"";
	print R_COMMANDS ", entrypoints=\"" . $entrypoints_file . "\"";

	#then the optional parameters
	if(defined($ymax)){
	    print R_COMMANDS ", ymax=" . $ymax;
	}
	
	if (defined($highlights)){
	    print R_COMMANDS ", highlights=\"" . $highlights . "\"";
	}

	if ($log_plot){
	    print R_COMMANDS ", logPlot=TRUE";
	}

	if ($log_input){
	    print R_COMMANDS ", logInput=TRUE";
	}

	if ($lowres){
	    print R_COMMANDS ", lowRes=TRUE";	    
	}

	if (defined($lowres_min)){
	    print R_COMMANDS ", lowResMin=" . $lowres_min;
	}

	if (defined($lowres_max)){
	    print R_COMMANDS ", lowResMax=" . $lowres_max;
	}

	if ($hide_normal){
	    print R_COMMANDS ", showNorm=FALSE";
	} else {
	    print R_COMMANDS ", showNorm=TRUE";
	}
	
	print R_COMMANDS ", gainThresh=" . $gain_threshold;
	print R_COMMANDS ", lossThresh=" . $loss_threshold;

	# if (defined($ylab)){
	#     print R_COMMANDS ", ylabel=\"" . $ylab . "\"";
	# } else {
	#     if($log_plot){
	# 	print R_COMMANDS ", ylabel=\"Log2 Copy Number\"";
	#     } else {
	# 	print R_COMMANDS ", ylabel=\"Copy Number\"";
	#     }
	# }

	print R_COMMANDS ")\n";	
    }


    #close it out
    print R_COMMANDS "dev.off()\n";
    print R_COMMANDS "q()\n";
    close R_COMMANDS;
    

    #now run the R command
    my $cmd = "R --vanilla --slave \< $rcommands_file";
    my $return = Genome::Sys->shellcmd(
	cmd => "$cmd",
        );
    unless($return) { 
	$self->error_message("Failed to execute: Returned $return");
	die $self->error_message;
    }
    return $return;
}
