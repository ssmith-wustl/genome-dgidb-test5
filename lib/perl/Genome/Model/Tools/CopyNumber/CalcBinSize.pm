package Genome::Model::Tools::CopyNumber::CalcBinSize;

use strict;
use warnings;
use Genome;
use Cwd;
use FileHandle;

#this is a wrapper to precess illumina file and make copy number graph, swt test. 

class Genome::Model::Tools::CopyNumber::CalcBinSize {
    is => 'Command',
    has => [
	read_count => {
	    is => 'Integer',
	    is_optional => 0,	
	    doc => 'The number of reads in the sample',
	},
	output_dir => {
	    is => 'String',
	    is_optional => 1,
	    default => getcwd(),
	    doc => 'Directory to use for (small) temporary file',
	},
	entrypoints => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'path to an entrypoints file containing chr, length and ploidy. See (/gscmnt/sata921/info/medseq/cmiller/annotations/entrypoints.hg18.[male|female])',
	},
	mapability => {
	    is => 'String',
	    is_optional => 0,
	    doc => 'path to an entrypoints file containing the mapability of the genome for the read length that you are using. See (~cmiller/annotations/mapability.hg18.[readlength]bpReads.dat)',
	},
	no_matched_normal => {
	    is => 'Integer',
	    is_optional => 1,
	    default => 0,
	    doc => ' Flag indicating sample is standalone (not a tumor/normal pair)',
	},
	p_value => {
	    is => 'Float',
	    is_optional => 1,
	    default => 0.01,
	    doc => ' The probability that any given window is misclassified',
	},
	gain_fraction => {
	    is => 'Float',
	    is_optional => 1,
	    default => 0.05,
	    doc => 'The fraction of the genome that is copy number amplified. A good estimation will help the tool choose a better bin size, but isn\'t strictly necessary.',
	},
	loss_fraction => {

	    is => 'Float',
	    is_optional => 1,
	    default => 0.05,
	    doc => 'The fraction -of the genome that is copy number deleted. A good estimation will help the tool choose a better bin size, but isn\'t strictly necessary.',
	},
	overdispersion => {
	    is => 'String',
	    is_optional => 1,
	    default => 3,
	    doc => 'The amount of overdispersion observed in the data. The default is sensible for Illumina reads',
	},
	verbose => {
	    is => 'Integer',
	    is_optional => 1,
	    default => 0,
	    doc => 'Include extra output, including some plots (written to Rplots.pdf)',
	},
	]
};

sub help_brief {
    "calculate a good window size for estimating copy number from WGS data"
}

sub help_detail {
    "This script takes the number of reads you've got as input, models the reads using a negative binomial distribution, then calculates a bin size. This bin size will enable good separability between the diploid and triploid peaks without misclassifying a greater fraction of windows than specified by the input p-value. 

It will also return info that gives you an idea of how many consecutive altered windows should be required during the segmentation step (CNAseg.pl: option -n) to maximize the resolution while minimizing the chance of obtaining a false positive alteration call.
"
}

sub execute {
    my $self = shift;
    my $read_count = $self->read_count;
    my $entrypoints = $self->entrypoints;
    my $mapability = $self->mapability;
    my $p_value = $self->p_value;
    my $gain_fraction = $self->gain_fraction;
    my $loss_fraction = $self->loss_fraction;
    my $overdispersion = $self->overdispersion;
    my $verbose = $self->verbose;
    my $no_matched_normal = $self->no_matched_normal;
    my $output_dir = $self->output_dir;


    my $matched_normal = 1;
    $matched_normal = 0 if($no_matched_normal);

    my $tmpFile = "/tmp/" . `date +%s%N`;
    chomp($tmpFile);
    $tmpFile = $tmpFile . ".calcBinSize.R";
    chomp($tmpFile);
    print "script file written to $tmpFile\n";
    system("cp /gscuser/cmiller/cna/calcBinSizeStub.R $tmpFile");
    my $outFh =  open (my $tmpFileH, ">>$tmpFile") || die "Can't open output file.\n";

    print $tmpFileH "cat(\"input: $read_count reads\\n\")\n";
    print $tmpFileH "cat(\"matched normal: $matched_normal\\n\\n\")\n";
    print $tmpFileH "verbose <<- $verbose\n";
    print $tmpFileH "numReads = $read_count\n";
    print $tmpFileH "entrypointsFile = \"$entrypoints\"\n";
    print $tmpFileH "entrypoints = readEntrypoints(entrypointsFile)\n";
    print $tmpFileH 'entrypoints <- addMapability("' . $mapability . '",entrypoints)' ."\n";
    print $tmpFileH "expectedLoss = $loss_fraction\n";
    print $tmpFileH "expectedGain = $gain_fraction\n";
    print $tmpFileH "fdr = $p_value\n";
    print $tmpFileH "overDispersion = $overdispersion\n";
    print $tmpFileH "minSize = 100\n";
    print $tmpFileH "matchedNormal = $matched_normal\n";
    print $tmpFileH "genomeSize = sum(entrypoints\$length)\n";
    print $tmpFileH "binInfo=getBinSize(numReads,entrypoints,expectedLoss,expectedGain,fdr,overDispersion,minSize,matchedNormal)\n";
    print $tmpFileH "cat(\"binSize: \",binInfo\$binSize,\"\\n\")\n";
    print $tmpFileH "cat(\"expected false calls with N consecutive windows:\\n\")\n";
    print $tmpFileH "for(i in seq(2,5)){\n";
    print $tmpFileH "cat(i,\": \",genomeSize/binInfo\$binSize*(fdr^i),\"\\n\")\n";
    print $tmpFileH "}\n";
    $tmpFileH->close;

    system("Rscript --vanilla $tmpFile");

    return 1;
}
1;
