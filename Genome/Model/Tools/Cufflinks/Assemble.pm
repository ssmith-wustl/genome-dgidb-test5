package Genome::Model::Tools::Cufflinks::Assemble;

class Genome::Model::Tools::Cufflinks::Assemble {
    is => 'Genome::Model::Tools::Cufflinks',
    has_input => [
        sam_file => {
            doc => 'The sam file to generate transcripts and expression levels from.',
        },
        params => {
            doc => 'Any additional parameters to pass to cufflinks'.
        },
        threads => {
            is => 'Number',
            doc => 'The number of CPU threads to use',
        },
    ],
    has_output => [
        transcripts_file => {
            is_optional => 1,
        },
    ],
};


sub execute {
    my $self = shift;

    #TODO: These files should be limited to an output directory
    $self->transcripts_file('transcripts.gtf');
    $self->transcript_expression_file('transcripts.expr');
    $self->gene_expression_file('genes.expr');

    my $params = '--num-threads='. $self->threads;
    $params .= ' '. $self->params;
    my $cmd = $self->cufflinks_path .' '. $params .' '. $self->sam_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->sam_file],
        output_files => [$self->transcripts_file,$self->transcript_expression_file,$self->gene_expression_file],
    );
    return 1;
}
