package Genome::Model::Tools::Cufflinks::Assemble;

use strict;
use warnings;

use Genome;
use Cwd;

class Genome::Model::Tools::Cufflinks::Assemble {
    is => 'Genome::Model::Tools::Cufflinks',
    has_input => [
        sam_file => {
            doc => 'The sam file to generate transcripts and expression levels from.',
        },
        params => {
            doc => 'Any additional parameters to pass to cufflinks',
            is_optional => 1,
        },
        output_directory => { doc => 'The directory to write all output files to', is => 'Text',},
    ],
    has_output => [
        transcripts_file => {
            is_optional => 1,
        },
        transcript_expression_file => {
            is_optional => 1,
        },
        gene_expression_file => {
            is_optional => 1,
        },
        assembler_output_file => {
            is_optional => 1,
        }
    ],
};


sub execute {
    my $self = shift;

    my $cwd = getcwd;
    my $output_directory = $self->output_directory;
    unless (chdir($output_directory)) {
        $self->error_message('Failed to change cwd to '. $output_directory);
        die($self->error_message);
    }
    $self->transcripts_file($output_directory .'/transcripts.gtf');
    $self->transcript_expression_file($output_directory .'/transcripts.expr');
    $self->gene_expression_file($output_directory .'/genes.expr');
    $self->assembler_output_file($output_directory .'/cufflinks.out');
    
    my $params = $self->params || '';
    if (version->parse($self->use_version) >= version->parse('0.9.0')) {
        # The progress bar since v0.9.0 is causing massive(50MB) log files 
        $params .= ' -q ';
    }
    my $cmd = $self->cufflinks_path .' '. $params .' '. $self->sam_file .' > '. $self->assembler_output_file .' 2>&1';
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [$self->sam_file],
        output_files => [$self->transcripts_file,$self->transcript_expression_file,$self->gene_expression_file,$self->assembler_output_file],
    );
    unless (chdir($cwd)) {
        $self->error_message('Failed to change directory to '. $cwd);
        die($self->error_message);
    }
    return 1;
}
