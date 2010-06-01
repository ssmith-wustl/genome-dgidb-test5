package Genome::Model::Tools::Fastqc::GenerateReports;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Fastqc::GenerateReports {
    is => 'Genome::Model::Tools::Fastqc',
    has => [
        fastq_files => {
            doc => 'The fastq files to generate quality reports for.',
            is => 'Text',
        },
        report_directory => {
            is => 'Text',
            doc => 'A directory where all output report will be written',
        }
    ],
};

sub execute {
    my $self = shift;
    my @fastq_files = split(',',$self->fastq_files);
    my $cmd = $self->fastqc_path .' -Djava.awt.headless=true -Dfastqc.output_dir='. $self->report_directory .' uk.ac.bbsrc.babraham.FastQC.FastQCApplication '. join(' ',@fastq_files) ;
    $self->run_java_vm(
        cmd => $cmd,
        input_files => \@fastq_files,
    );
    return 1;
}
