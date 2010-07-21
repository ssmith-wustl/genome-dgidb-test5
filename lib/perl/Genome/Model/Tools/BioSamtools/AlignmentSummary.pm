package Genome::Model::Tools::BioSamtools::AlignmentSummary;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::AlignmentSummary {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data'
        },
        bed_file => {
            is => 'Text',
            doc => 'A BED file of regions of interest to evaluate on/off target alignment',
            is_optional => 1,
        },
        wingspan => {
            is => 'Integer',
            doc => 'A wingspan to add to each region of interest coordinate span',
            is_optional => 1,
        },
        output_directory => {
            is => 'Text',
            doc => 'A directory path used to resolve the output file name.  Required if output_file not defined.  Mostly used for workflow parallelization.',
            is_optional => 1,
        },
    ],
    has_output => [
        output_file => {
            is => 'Text',
            doc => 'A file path to store tab delimited output.  Required if ouput_directory not provided.',
            is_optional => 1,
        },
    ],
    has_param => [
        lsf_queue => {
            doc => 'When run in parallel, the LSF queue to submit jobs to.',
            is_optional => 1,
            default_value => 'apipe',
        },
        lsf_resource => {
            doc => 'When run in parallel, the resource request necessary to run jobs on LSF.',
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
        },
    ],
};

sub execute {
    my $self = shift;

    my $bam_file = $self->bam_file;
    # resolve the output file but only use it if the param was not defined
    my $resolved_output_file;
    my $output_directory = $self->output_directory;
    if ($output_directory) {
        unless ($output_directory) {
            die('Failed to provide either output_file or output_directory!');
        }
        unless (-d $output_directory) {
            unless (Genome::Utility::FileSystem->create_directory($output_directory)) {
                die('Failed to create output directory: '. $output_directory);
            }
        }
        my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($bam_file,qw/\.bam/);
        unless(defined($bam_suffix)) {
            die ('Failed to recognize bam_file '. $bam_file .' without bam suffix');
        }
        $resolved_output_file = $output_directory .'/'. $bam_basename;
    } elsif (!defined($self->output_file)) {
        die('Failed to provide either output_file or output_directory!');
    }
    
    my $cmd = $self->execute_path .'/alignment_summary-64.pl '. $bam_file;
    my @input_files = ($bam_file);
    my $bed_file = $self->bed_file;
    if ($bed_file) {
        my ($bed_basename,$bed_dirname,$bed_suffix) = File::Basename::fileparse($bed_file,qw/\.bed/);
        unless(defined($bed_suffix)) {
            die ('Failed to recognize bed_file '. $bed_file .' without bed suffix');
        }
        $resolved_output_file .= '-'. $bed_basename;
        $cmd .= ' '. $bed_file;
        push @input_files, $bed_file;
        my $wingspan = $self->wingspan;
        if (defined($wingspan)) {
            $cmd .= ' '. $wingspan;
            $resolved_output_file .= '-wingspan_'. $wingspan;
        }
    }
    $resolved_output_file .= '-alignment_summary.tsv';
    unless ($self->output_file) {
        $self->output_file($resolved_output_file);
    }
    $cmd .= ' > '. $self->output_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => \@input_files,
        output_files => [$self->output_file],
    );
    return 1;
}

1;
