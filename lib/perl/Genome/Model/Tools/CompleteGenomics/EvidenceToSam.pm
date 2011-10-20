package Genome::Model::Tools::CompleteGenomics::EvidenceToSam;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Tools::CompleteGenomics::EvidenceToSam {
    is => 'Genome::Model::Tools::CompleteGenomics',
    has_input => [
        evidence_file => {
            is => 'Text',
            doc => 'The CompleteGenomics mapping file to convert',
        },
        bam_file => {
            is => 'Text',
            doc => 'BAM output file',
            is_optional => 1,
            is_output => 1,
        },
        bam_directory => {
            is => 'Text',
            doc => 'A directory in which to write the new BAM (must supply this or bam_file)',
            is_optional => 1,
        },
        reference_file => {
            is => 'Text',
            doc => 'Path to CRR reference file',
        },
    ],
    has_param => [
        lsf_resource => {
            default_value => "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>1000 && mem>4000] span[hosts=1] rusage[tmp=1000,mem=4000]'",
        },
    ],
};

sub execute {
    my $self = shift;

    unless(-e $self->evidence_file) {
        die $self->error_message('Evidence file ' . $self->evidence_file . ' could not be found.');
    }

    unless($self->bam_file) {
        unless($self->bam_directory) {
            die $self->error_message('Must specify either bam_file or bam_directory.');
        }

        my $bam_file = File::Basename::basename($self->evidence_file);
        $bam_file =~ s/.tsv.bz2/.bam/;
        $self->bam_file($self->bam_directory . '/' . $bam_file);
    }

    my $tmp_file = Genome::Sys->create_temp_file_path;
    #This is a "beta" command, so the --beta flag is required
    my $cmd = 'evidence2sam --beta -e ' . $self->evidence_file . ' -s ' . $self->reference_file . ' | samtools view - -b -S -o ' . $tmp_file;

    $self->run_command($cmd, input_files => [$self->evidence_file], output_files => [$tmp_file]);
    Genome::Sys->copy_file($tmp_file, $self->bam_file);

    return 1;
}

1;
