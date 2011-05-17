package Genome::Model::Tools::CopyNumber::PlotSegmentsFromBams;

use warnings;
use strict;
use Genome;
use File::Basename;

class Genome::Model::Tools::CopyNumber::PlotSegmentsFromBams {
    is => 'Command',
    has_input => [
    bams => {
        is => 'String',
        doc => 'Colon-delmited list of .bam files',
        #doc => 'Comma-delimited list of .bam files',
    },
    names_of_bams => {
        is => 'String',
        doc => 'Comma-delmited list of names to give .bam files (in same order as "bams")',
    },
    output_file => {
        is => 'String',
        doc => 'Name of output file which is the CN graph (PDF)',
    },
    ],
    has_optional_input => [
    genome_build => {
        is => 'String',
        doc => "choose '36' or '37'",
        default => '36'
    },
    sex => {
        is => 'String',
        doc => "choose 'male' or 'female'",
        default => 'male'
    },
    plot_ymax => {
        is => 'Number',
        doc => 'set the max value of the y-axis on the CN plots',
        default => '6',
    },
    bam2cn_window => {
        is => 'Number',
        doc => 'set the window-size used for the single-genome CN estimation',
        default => '2000',
    },
    cnvseg_markers => {
        is => 'Number',
        doc => 'number of consecutive markers needed to make a CN gain/loss prediction',
        default => '4',
    },
    ],
};

sub help_brief {
    "generate a plot of CN alterations from .bam files"
}

sub help_detail {
    "This tool takes a list of any number of .bam files and the names you would like to give them (IN THE SAME ORDER), and then runs Ken Chen's scripts to determine single-genome read-depth based copy-number assessments (BAM2CN.pl) and also the single-genome segmentation (CNVseg.pl). These jobs are bsub'ed simultaneously for each .bam file. Lastly, a command is printed to STDOUT which can be used to feed the segmented output into Chris Millers 'gmt copy-number plot-segments' in order to produce a graph of the predicted amplifications and deletions. The output directory of the output file will also be used for intermediate files until someone complains about this."
}

sub execute {

    my $self = shift;

    #parse input arguments
    my $output_file = $self->output_file;
    my $output_dir = dirname($output_file) . "/";
    my @bams = split /:/,$self->bams;
    my $bam_names = $self->names_of_bams;
    my @bam_names = split /,/,$bam_names;
    unless (scalar @bams == scalar @bam_names) {
        $self->error_message("Number of .bam files and names for .bam files must be the same (comma-delimited).");
        return;
    }

    #needed declarations
    my @seg_filenames = ();
    my $user = $ENV{USER};

    #run BAM2CN.pl and CNVseg.pl on each .bam using simultaneous bsubs
    for my $i (0 .. $#bams) {
        
        #output filenames
        my $bam2cn_outfile = $output_dir . $bam_names[$i] . ".bam2cn";
        my $cnvseg_outfile = $bam2cn_outfile . ".cnvseg";

        #commands
        my $window = $self->bam2cn_window;
        my $markers = $self->cnvseg_markers;
        my $bam2cn_cmd = "/gscuser/kchen/SNPHMM/SolexaCNV/scripts/BAM2CN.pl -w $window -p " . $bams[$i] . " > " . $bam2cn_outfile . ";";
        my $cnvseg_cmd = "/gscuser/kchen/SNPHMM/SolexaCNV/scripts/CNVseg.pl -n $markers -y 4 " . $bam2cn_outfile . " > " . $cnvseg_outfile . ";";
        my $bsub_cmd = "bsub -u $user\@genome.wustl.edu -J " . $bam_names[$i] . "-cn-seg '$bam2cn_cmd $cnvseg_cmd'";

        #run bsub
        run($self,$bsub_cmd);

        #save segment filenames for plotting script
        push @seg_filenames,$cnvseg_outfile;
    }

    #print command which can be used to plot CN output for all .bams on same plot
    my $segment_files = join(",",@seg_filenames);
    my $plot_cmd = "gmt copy-number plot-segments --segment-files $segment_files --output-pdf $output_file --cnvhmm-input --lowres --plot-title " . $self->names_of_bams . " --genome-build " . $self->genome_build . " --sex " . $self->sex . " --ymax " . $self->plot_ymax;
    $self->status_message("\nREADME:\nRun this command when your bsubbed jobs are done:\n$plot_cmd\n");

    return 1;
}

sub run {
    my $self = shift;
    my $cmd = shift;

    #$self->status_message("Running $cmd");
    my $shell_return = Genome::Sys->shellcmd(
        cmd => "$cmd",
    );

    unless ($shell_return) {
        $self->error_message("Failed to correctly execute $cmd. Returned $shell_return");
        return;
    }
}
