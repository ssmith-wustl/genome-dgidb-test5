package Genome::Model::Event::Build::RnaSeq::Expression::Cufflinks;

use strict;
use warnings;

use version;

use Genome;

class Genome::Model::Event::Build::RnaSeq::Expression::Cufflinks {
    is => ['Genome::Model::Event::Build::RnaSeq::Expression'],
    has => [
    ],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64 && mem>=32000] rusage[mem=32000] span[hosts=1]' -M 32000000 -n 4";
}

sub execute {
    my $self = shift;
    my $expression_directory = $self->build->accumulated_expression_directory;
    unless (-d $expression_directory) {
        Genome::Sys->create_directory($expression_directory);
    }
    my $align_reads = Genome::Model::Event::Build::RnaSeq::AlignReads->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
    );
    my $aligner = $align_reads->create_aligner_tool;
    my $sam_file;
    if (version->parse($aligner->use_version) >= version->parse('1.1.0')) {
        if (version->parse($self->model->expression_version) >= version->parse('0.9.0')) {
            $sam_file = $aligner->bam_file;
        } else {
            $sam_file = Genome::Sys->create_temp_file_path($self->build->id .'.sam');
            unless (Genome::Model::Tools::Sam::BamToSam->execute(
                bam_file => $aligner->bam_file,
                sam_file => $sam_file,
            )) {
                $self->error_message('Failed to convert BAM '. $aligner->bam_file .' to tmp SAM file '. $sam_file);
                die($self->error_message);
            }
        }
    } else {
        $sam_file = $aligner->sam_file;
    }
    my $params = $self->model->expression_params || '';
    if (version->parse($self->model->expression_version) >= version->parse('0.9.0')) {
        my $reference_build = $self->model->reference_sequence_build;
        my $reference_path = $reference_build->full_consensus_path('fa');
        $params .= ' -r '. $reference_path;
        my $annotation_reference_transcripts = $self->model->annotation_reference_transcripts;
        if ($annotation_reference_transcripts) {
            my ($annotation_name,$annotation_version) = split(/\//, $annotation_reference_transcripts);
            my $annotation_model = Genome::Model->get(name => $annotation_name);
            unless ($annotation_model){
                $self->error_message('Failed to get annotation model for annotation_reference_transcripts: ' . $annotation_reference_transcripts);
                return;
            }
            
            unless (defined $annotation_version) {
                $self->error_message('Failed to get annotation version from annotation_reference_transcripts: '. $annotation_reference_transcripts);
                return;
            }
            
            my $annotation_build = $annotation_model->build_by_version($annotation_version);
            unless ($annotation_build){
                $self->error_message('Failed to get annotation build from annotation_reference_transcripts: '. $annotation_reference_transcripts);
                return;
            }
        
            my $rRNA_MT_path = $annotation_build->rRNA_MT_file('gtf');
            if ($rRNA_MT_path) {
                $params .= ' -M '. $rRNA_MT_path;
            }
        }
        # Cufflinks should probably run once with the annotation gtf and -G to identify known transcripts.
        # Cufflinks should also run a second time to identify novel transcripts
        # This could be a param in the processing profile; however, resolving the annotation set(hence the right build/version) is performed here...
    }
    unless (Genome::Model::Tools::Cufflinks::Assemble->execute(
        sam_file => $sam_file,
        params => $params,
        output_directory => $expression_directory,
        use_version => $self->model->expression_version,
    )) {
        $self->error_message('Failed to execute cufflinks!');
        die($self->error_message);
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    warn ('Please implement vsc for class '. __PACKAGE__);
    return 1;
}

1;
