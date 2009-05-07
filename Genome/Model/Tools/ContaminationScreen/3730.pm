package Genome::Model::Tools::ContaminationScreen::3730;

use strict;
use warnings;

use Genome;
use Workflow;
use File::Basename;

class Genome::Model::Tools::ContaminationScreen::3730
{
    is => 'Genome::Model::Tools::ContaminationScreen',
    has => [
            parse_script =>{
                             doc => 'script to parse cross match (post-crossmatch cutoff: 95% identity over at least 75% the length of the query)',
                             is => 'String',
                             default => '/gscmnt/233/analysis/sequence_analysis/scripts/parse_blast_results_fullgroup_percid_fractionoflength.pl',
                         },
        ],
    has_param => [
        lsf_resource => {
            default_value => "-M 15000000 -R 'select[type==LINUX64] rusage[mem=15000]'",
        }
    ],
};

operation_io Genome::Model::Tools::ContaminationScreen::3730
{
    input  => [ 'input_file', 'database' ],
    output => [ 'read_file','output_file'],
};

sub help_brief 
{
    "locate contamination in quality/vector trimmed data for 3730",
}

sub help_synopsis 
{
    return <<"EOS"
    gt blastn --database --input_file M=1 N=-3 R=3 Q=3 wordmask=seg lcmask topcomboN=1 hspsepsmax=10 golmax=0 B=1 V=1  >  --read_file 
    gt --parse_script -input --read_file -output --parsed_file -percent -num_hits 1 -percent 95 -fol .75 > --output_file
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
    my ($read_file, $parsed_file, $hits_file) = ($self->_resolve_directory . '/reads.txt', $self->_resolve_directory . '/reads.parsed', $self->_resolve_directory . '/hits.fna');
    my $output_file = $self->input_file . 'screened';

    #create read file
    my $cmd = 'blastn ' . $self->database . ' ' . $self->input_file . ' M=1 N=-3 R=3 Q=3 wordmask=seg lcmask topcomboN=1 hspsepsmax=10 golmax=0 B=1 V=1  >  ' . $read_file; 
    $self->status_message('Running: '. $cmd);

    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command $cmd");
        return;
    }

    #run parsing script
    my $parse = $self->parse_script . ' -input ' . $read_file . ' -output ' . $parsed_file . ' -num_hits 1 -percent 95 -fol .75'; 
    $self->status_message('Running: ' . $parse);
    $rv = system($parse);
    unless ($rv == 0)
    {
        $self->error_message("non-zero return value($rv) from command $parse");
        return;
    }
    
    #search for hits
    my $grep = 'grep "====" ' . $parsed_file . ' > ' . $hits_file;
    $self->status_message('Running: ' . $grep);
    $rv = system($grep);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command $grep");
        return;
    }

    #parse out column of reads
    my $awk = 'cat ' . $hits_file . ' | awk -F " " \'{print $2}\' > ' . $output_file;
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
