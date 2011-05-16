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
        doc => 'Comma-delimited list of .bam files',
    },
    names_of_bams => {
        is => 'String',
        doc => 'Comma-delmited list of names to give .bam files (in same order as .bams)',
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
    ],
};

sub help_brief {
    "generate a plot of CN alterations from .bam files"
}

sub help_detail {
    "This tool takes a list of any number of .bam files and the names you would like to give them (IN THE SAME ORDER), and then runs Ken Chen's scripts to determine single-genome read-depth based copy-number assessments (BAM2CN.pl) and also the single-genome segmentation script (CNVseg.pl), and then take the segmented output and feed into Chris Millers PlotSegments.pm which produces a graph of the predicted amplifications and deletions. The output directory of the output file will also be used for intermediate files for now."
}

sub execute {
    my $self = shift;

    #parse input arguments
    my $output_file = $self->output_file;
    my $output_dir = dirname($output_file);
    my @bams = split /,/,$self->bams;
    my $bam_names = $self->names_of_bams;
    my @bam_names = split /,/,$bam_names;
    unless (scalar @bams == scalar @bam_names) {
        $self->error_message("Number of .bam files and names for .bam files must be the same (comma-delimited).");
        return;
    }
    my @seg_filenames = ();

    #run BAM2CN.pl and CNVseg.pl on each .bam
    for my $i (0 .. $#bams) {
        
        my $bam2cn_outfile = $output_dir . $bam_names[$i] . ".bam2cn";
        my $bam2cn_cmd = "/gscuser/kchen/SNPHMM/SolexaCNV/scripts/BAM2CN.pl -w 1250 -p " . $bams[$i] . " > " . $bam2cn_outfile;
        run($self,$bam2cn_cmd);

        my $cnvseg_outfile = $bam2cn_outfile . ".cnvseg";
        my $cnvseg_cmd = "/gscuser/kchen/SNPHMM/SolexaCNV/scripts/CNVseg.pl -n 4 -y 4 " . $bam2cn_outfile . " > " . $cnvseg_outfile;
        run($self,$cnvseg_cmd);

        push @seg_filenames,$cnvseg_outfile;
    }

    #plot CN output for all .bams on same plot
    my $segment_files = join(",",@seg_filenames);
    my $build = $self->genome_build;
    my $plot_cmd = Genome::Model::Tools::CopyNumber::PlotSegments->create(
        segment_files => $segment_files,
        output_pdf => $output_file,
        cnvhmm_input => '1',
        genome_build => $build,
        plot_title => $self->names_of_bams,
        sex => $self->sex,
        ymax => $self->plot_ymax,
    );
    $self->status_message("Running plotting tool.");
    $plot_cmd->execute;

    return 1;
}

sub run {
    my $self = shift;
    my $cmd = shift;

    $self->status_message("Running $cmd");
    my $shell_return = Genome::Sys->shellcmd(
        cmd => "$cmd",
    );

    unless ($shell_return) {
        $self->error_message("Failed to correctly execute $cmd. Returned $shell_return");
        return;
    }
}
