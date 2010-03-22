package Genome::Model::Event::Build::RnaSeq::Expression::Cufflinks;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::RnaSeq::Expression::Cufflinks {
    is => ['Genome::Model::Event::Build::RnaSeq::Expression'],
	has => [
    ],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1]' -n 4";
}

sub execute {
    my $self = shift;

    my $align_reads = Genome::Model::Event::Build::RnaSeq::AlignReads->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
    );
    my $aligner = $align_reads->create_aligner_tool;
    my $sam_file = $aligner->sam_file;
    unless (Genome::Model::Tools::Cufflinks::Assemble->execute(
        sam_file => $aligner->sam_file,
        params => $self->model->expression_params,
        use_version => $self->model->expression_version,
    )) {
        $self->error_message('Failed to execute cufflinks');
        return;
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    warn ('Please implement vsc for class '. __PACKAGE__);
    return 1;
}

1;
