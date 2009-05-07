package Genome::Model::Tools::ContaminationScreen::Solexa;

use strict;
use warnings;

use Genome;
use Workflow;
use File::Basename;

class Genome::Model::Tools::ContaminationScreen::Solexa
{
    is => 'Genome::Model::Tools::ContaminationScreen',
    has => [
        ],
    has_param => [
        lsf_resource => {
            default_value => "-M 15000000 -R 'select[type==LINUX64] rusage[mem=15000]'",
        }
    ],
};

sub help_brief 
{
    "locate contamination in GERALD fastq files for Illumina/Solexa",
}

sub help_synopsis 
{
    return <<"EOS"
    gt cross_match.test --input_file --database -raw -tags -minmatch 16 -minscore 42 -bandwidth 3 -penalty -1 -gap_init -1 -gap_exp -1 >  --output_file 
EOS
}

sub create 
{
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return $self;
}

sub execute 
{
    my $self = shift;
    my ($read_file, $hits_file) = ($self->_resolve_directory . '/reads.txt', $self->_resolve_directory . '/hits.fna');
    my $output_file = $self->input_file . '.screened';

    #create read file
    my $cmd = 'cross_match.test ' . $self->input_file . ' ' .  $self->database . ' -raw -tags -minmatch 16 -minscore 42 -bandwidth 3 -penalty -1 -gap_init -1 -gap_ext -1 > ' . $read_file;
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command $cmd");
        return;
    }
    #search for hits
    my $grep = 'grep "ALIGNMENT" ' . $read_file . ' > ' . $hits_file;
    $self->status_message('Running: ' . $grep);
    $rv = system($grep);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command $grep");
        return;
    }
    #parse out column of reads
    my $awk = 'cat ' . $hits_file . ' | awk -F " " \'{print $6}\' > ' . $output_file;
    $rv = system($awk);
    unless ($rv == 0)
    {
        $self->error_message("non-zero return value($rv) from command $awk");
        return;
    }

    $self->output_file($output_file);
    return 1;
}

1;
