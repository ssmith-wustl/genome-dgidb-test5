package Genome::Model::Tools::CopyNumber::Cbs;

##############################################################################
#
#
#	AUTHOR:		Chris Miller (cmiller@genome.wustl.edu)
#
#	CREATED:	07/11/11
#
#	NOTES:  TODO - add array support (from some other scripts lying around)
#
##############################################################################

use strict;
use Genome;
use IO::File;
#use Statistics::R;
use File::Basename;
use warnings;
require Genome::Sys;
use FileHandle;

class Genome::Model::Tools::CopyNumber::Cbs {
    is => 'Command',
    has => [
	bamwindow_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'File containing read counts in windows. Three columns requred: chr, start, read count',
	},

	bam2cna_file => {
	    is => 'String',
	    is_optional => 1,
	    doc => 'File containing read counts in windows. Three columns requred: chr, start, read count',
	},

        output_R_object => {
            is => 'String',
	    is_optional => 1,
            doc => 'If specified, output will be an Rdata object with segments stored in a variable named "d". This creates suitable input for the RAE peak-finding algorithm.',
        },
        
        output_file => {
            is => 'String',
	    is_optional => 1,
            doc => 'If specified, output will be a 5-column tab-seperated file containing segments',
        },
        
        convert_names => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Replace X, Y, MT with 23, 24, 25',
            default => 0,
        },

        sample_name => {
            is => 'String',
            is_optional => 1,
            doc => 'If specified, output becomes 6-column with sample name in first column, followed by chr, st, sp, bins, cn',
        },
        
    ]
};

sub help_brief {
    "segment copy-number data using the circular binary segmentation algorithm"
}

sub help_detail {
    "segment copy-number data using the circular binary segmentation algorithm"
}


#########################################################################
sub name_convert{
    my $cmd = 'x=which(cn[,1] == "X")' . "\n";
    $cmd = $cmd . 'y=which(cn[,1] == "Y")' . "\n";
    $cmd = $cmd . 'm=which(cn[,1] == "MT")' . "\n";
    $cmd = $cmd . 'names=as.numeric(cn[,1])' . "\n";
    $cmd = $cmd . 'names[x]=23' . "\n";
    $cmd = $cmd . 'names[y]=24' . "\n";
    $cmd = $cmd . 'names[m]=25' . "\n";
    $cmd = $cmd . 'cn[,1] = names' . "\n"; 
    return($cmd);
}


sub execute {
    my $self = shift;
    my $bamwindow_file = $self->bamwindow_file;    
    my $bam2cna_file = $self->bam2cna_file;    
    my $output_R_object = $self->output_R_object;
    my $output_file = $self->output_file;
    my $convert_names = $self->convert_names;
    my $sample_name = $self->sample_name;
    
    #sanity checks
    unless( (defined($output_R_object)) || (defined($output_file))){
        die $self->error_message("You must specify either the output_file OR output_R_object file");
    }

    unless( (defined($bamwindow_file)) || (defined($bam2cna_file))){
        die $self->error_message("You must specify either a bamwindow file or a bam2cna file");
    }
    
    #set up a temp file for the R commands
    my $temp_path;
    my ($tfh,$tfile) = Genome::Sys->create_temp_file;
    unless($tfh) {
        $self->error_message("Unable to create temporary file $!");
        die;
    }
    
    
    #open the R file
    open(R_COMMANDS,">$tfile") || die "can't open $tfile for writing\n";

    print R_COMMANDS "library(DNAcopy)" . "\n";
    
    #get input file
    if(defined($bamwindow_file)){
        print R_COMMANDS "cn <- read.table(\"" . $bamwindow_file . "\",header=F,sep=\"\t\")" . "\n";        
    } else {
        print R_COMMANDS 'cn <- read.table("' . $bam2cna_file . '", header=T, sep="\t", comment.char="#")' . "\n";
    }

    if($convert_names){            
        print R_COMMANDS name_convert();
    } 


    #create cna object
    print R_COMMANDS "CNA.object <-CNA( genomdat = ";
    if(defined($bamwindow_file)){        
        print R_COMMANDS "log2(cn[,3]/median(cn[3],na.rm=T))";
    } else {
        print R_COMMANDS "log2(cn[,3]/cn[,4])";
    }
    
    print R_COMMANDS ", chrom = cn[,1], maploc = cn[,2], data.type = 'logratio'";
    
    if(defined($sample_name)){
        print R_COMMANDS ", sampleid=\"" . $sample_name . "\"";
    }
    print R_COMMANDS ")" . "\n";


    #segment the data
    print R_COMMANDS "d <- segment(CNA.object, verbose=0, min.width=2) " . "\n";

    
    if(defined($output_file)){
        #extract the segs, output
        print R_COMMANDS 'segs = d$output' . "\n";
        if(defined($sample_name)){        
            print R_COMMANDS 'write.table(segs, file="' . $output_file . '", row.names=F, col.names=F, quote=F, sep="\t")' . "\n";
        } else {
            print R_COMMANDS 'write.table(segs[,2:6], file="' . $output_file . '", row.names=F, col.names=F, quote=F, sep="\t")' . "\n";
        }

    } elsif(defined($output_R_object)){        
        #output the data structure as an Rdata file
        print R_COMMANDS "save(d,file=\"" . $output_R_object . "\")" . "\n";
    }
    print R_COMMANDS "q()\n";
    close R_COMMANDS;

#    `cp $tfile /tmp/tmp.R`;

    #now run the R command
    my $cmd = "R --vanilla --slave \< $tfile";
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
