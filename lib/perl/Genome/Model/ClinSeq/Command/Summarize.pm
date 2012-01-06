package Genome::Model::ClinSeq::Command::Summarize;
use strict;
use warnings;
use Genome;

class Genome::Model::ClinSeq::Command::Summarize {
    is => 'Command::V2',
    has_input => [
        models => { 
            is => 'Genome::Model::ClinSeq',
            is_many => 1,
            shell_args_position => 1,
            require_user_verify => 0,
            doc => 'clinseq models to sumamrize'
        },
    ],
    doc => 'summarize clinseq model status and results',
};

sub help_synopsis {
    return <<EOS
genome model clin-seq summarize 12345

genome model clin-seq summarize mymodelname

genome model clin-seq summarize subject.common_name=HG1

genome model clin-seq summarize subject.common_name=HG%
EOS
}

sub help_detail {
    return <<EOS
Summarize the status and key metrics for 1 or more clinseq models.

(put more content here)
EOS
}

sub execute {
    my $self = shift;
    my @models = $self->models;
    
    for my $model (@models) {
        $self->status_message("***** " . $model->__display_name__ . " ****");

        my $patient = $model->subject;
        my @samples = $patient->samples;
        for my $sample (@samples) {
            my @instdata = $sample->instrument_data;
            $self->status_message("sample " . $sample->__display_name__ . " has " . scalar(@instdata) . " instrument data");
        }

        my $clinseq_build = $model->last_complete_build;
        unless ($clinseq_build) {
            $self->status_message("NO COMPLETE CLINSEQ BUILD!");
            next;
        }

        my $wgs_build = $clinseq_build->wgs_build;
        my $exome_build = $clinseq_build->exome_build;
        my $tumor_rnaseq_build = $clinseq_build->tumor_rnaseq_build;
        my $normal_rnaseq_build = $clinseq_build->normal_rnaseq_build;

        for my $build ($wgs_build, $exome_build, $tumor_rnaseq_build, $normal_rnaseq_build, $clinseq_build) {
            next unless $build;
            $self->status_message("build " . $build->__display_name__ . " has status " . $build->status);
        }
    }

    return 1;
}

1;

