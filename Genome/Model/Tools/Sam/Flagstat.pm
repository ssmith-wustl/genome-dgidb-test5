package Genome::Model::Tools::Sam::Flagstat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sam::Flagstat {
    is => 'Genome::Model::Tools::Sam',
    has => [
        bam_file => { },
        output_file => { },
        include_stderr => { is => 'Boolean', is_optional => 1, default_value => 0, doc => 'Include any error output from flagstat in the output file.'}
    ],
};

sub execute {
    my $self = shift;
    my $stderr_redirector = $self->include_stderr ? ' 2>&1 ' : '';
    my $cmd = $self->samtools_path .' flagstat '. $self->bam_file .' > '. $self->output_file . $stderr_redirector;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}
