package Genome::Model::Tools::ContaminationScreen::454;

use strict;
use warnings;

use Genome;
use Workflow;
use File::Basename;

class Genome::Model::Tools::ContaminationScreen::454
{
    is => 'Genome::Model::Tools::ContaminationScreen',
    has => [
            parse_script =>{
                             doc => 'script to parse cross match (post-crossmatch cutoff: 90% identity over at least 50 bases)',
                             is => 'String',
                             default => '/gscmnt/233/analysis/sequence_analysis/scripts/parse_crossmatch_results.pl',
                         },
        ],
};

#operation_io Genome::Model::Tools::ContaminationScreen::454
#{
#    input  => [ 'input_file', 'database' ],
#    output => [ 'read_file','output_file'],
#};

sub help_brief 
{
    "locate contamination in quality/vector trimmed data for 454",
}

sub help_synopsis 
{
    return <<"EOS"
    gt cross_match.test --input_file --database -raw -tags -minmatch 14 -bandwidth 6 -penalty -1 -gap_init -1 -gap_ext -1 >  --read_file
    gt --parse_script -input --read_file -output --parsed_file -percent 90 -length 50 > --output_file
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
    my $output_file = $self->input_file . '.screened';

    #create read file
    my $cmd = 'cross_match.test ' . $self->input_file . ' ' .  $self->database . ' -raw -tags -minmatch 14 -bandwidth 6 -penalty -1 -gap_init -1 -gap_ext -1 > ' . $read_file;
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command $cmd");
        return;
    }

    #run parsing script
    my $parse = $self->parse_script . ' -input ' . $read_file . ' -output ' . $parsed_file . ' -percent 90 -length 50'; 
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
