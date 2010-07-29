package Genome::Model::Tools::Bmr::SubmitBatchClassSummary;

use warnings;
use strict;

use Genome;
use IO::File;

class Genome::Model::Tools::Bmr::SubmitBatchClassSummary {
    is => 'Genome::Command::OO',
    has_input => [
    wiggle_file_dirs => {
        is => 'Comma-delimited String',
        is_optional => 0,
        doc => 'Comma-delimited list of directories containing wiggle files',
    },
    mutation_maf_file => {
        is => 'String',
        is_optional => 0,
        doc => 'MAF file containing all mutations to be considered in the test',
    },
    roi_bedfile => {
        is => 'String',
        is_optional => 0,
        doc => 'BED file used to limit background regions of interest when calculating background mutation rate',
    },
    genes_to_exclude => {
        is => 'Comma-delimited String',
        is_optional => 1,
        doc => 'Comma-delimited list of genes to exclude in the BMR calculation',
    },
    stdout_dir => {
        is => 'String',
        is_optional => 0,
        doc => 'Directory to catch all of the stdout from the simultaneously submitted jobs',
    },
    output_dir => {
        is => 'String',
        is_optional => 0,
        doc => 'Directory to catch all of the output files from the batch-class-summary commands',
    },
    ]
};

sub help_brief {
    "Submit batch-class-summary jobs, 1 per wiggle file."
}

sub help_detail {
    "Submit batch-class-summary jobs, 1 per wiggle file in the given directories. Do not bsub this command."
}

sub execute {
    my $self = shift;
    
    #Parse wiggle file directories to obtain the path to wiggle files
    my %wiggle_files; # %wiggle_files -> wigfile = full_path_wigfile
    my $wiggle_dirs = $self->wiggle_file_dirs;
    my @wiggle_dirs = split ",",$wiggle_dirs;
    for my $wiggle_dir (@wiggle_dirs) {
        opendir(WIG,$wiggle_dir) || die "Cannot open directory $wiggle_dir";
        my @files = readdir(WIG);
        closedir(WIG);
        @files = grep { !/^(\.|\.\.)$/ } @files;
        for my $file (@files) {
            my $full_path_file = "$wiggle_dir/" . $file;
            $wiggle_files{$file} = $full_path_file;
        }
    }

    #required inputs
    my $maf = $self->mutation_maf_file;
    my $roi_bed = $self->roi_bedfile;
    my $output_dir = $self->output_dir;
    my $stdout_dir = $self->stdout_dir;
    my $genes_to_exclude = $self->genes_to_exclude;
    unless (defined $genes_to_exclude) {
        $genes_to_exclude = "";
    }

    #submit jobs
    for my $wigfile (keys %wiggle_files) {
        my $jobname = $wigfile . "-genesum";
        my $outfile = $output_dir . $wigfile . ".gene_summary";
        my $stdout_file = $stdout_dir . $wigfile . ".stdout";
        my $wiggle = "/opt/fscache/" . $wiggle_files{$wigfile};
        $self->status_message("$wiggle");
        print `bsub -q tcga -M 4000000 -R 'select[localdata && mem>4000] rusage[mem=4000]' -oo $stdout_file -J $jobname gmt bmr batch-class-summary --mutation-maf-file $maf --output-file $outfile --roi-bedfile $roi_bed --wiggle-file $wiggle --genes-to-exclude $genes_to_exclude`;
    }

    return 1;
}
1;

