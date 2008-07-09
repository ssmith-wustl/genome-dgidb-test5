package Genome::Model::Command::AddReads::PostprocessVariations::BreakPointRead454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::PostprocessVariations::BreakPointRead454 {
    is => [
           'Genome::Model::Command::AddReads::PostprocessVariations',
       ],
    has => [
            merged_alignments_file => { via => 'prior_event' },
            merged_fasta_file => {
                                  calculate_from => ['model'],
                                  calculate => q|
                                          return $model->alignments_directory .'/'. $model->sample_name .'.fa';
                                  |,
                              },
            insertions_file => { via => 'prior_event' },
            combined_insertions_file => {
                                         calculate_from => ['insertions_file'],
                                         calculate => q|
                                             return $insertions_file .'.combined';
                                         |,
                                     },
            deletions_file => { via => 'prior_event' },
            combined_deletions_file => {
                                         calculate_from => ['deletions_file'],
                                         calculate => q|
                                             return $deletions_file .'.combined';
                                         |,
                                     },
            substitutions_file => { via => 'prior_event' },
            combined_substitutions_file => {
                                            calculate_from => ['substitutions_file'],
                                            calculate => q|
                                             return $substitutions_file .'.combined';
                                         |,
                                        },
            coverage_blocks_file => {
                                     calculate_from => ['merged_alignments_file'],
                                     calculate => q|
                                         return $merged_alignments_file .'.coverage.blocks';
                                     |,
                                 },
        ],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments identify-variation break-point-read-454 --model-id 5 --ref-seq-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the postprocess-alignments process
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;

    my @alignment_events = $model->alignment_events;
    my @fasta_files = map {$_->fasta_file} @alignment_events;
    unless ($self->_cat_files($self->merged_fasta_file,@fasta_files)){
        $self->error_message("Could not merge all alignment files");
        return;
    }

    my $break_point_path = 'perl ~jwalker/svn/perl_modules/breakPointRead/breakPointRead454.pl';

    my $snp_cmd = sprintf("%s --genotype-snps %s --alignment-file %s --sample-name %s",
                          $break_point_path,
                          $self->combined_substitutions_file,
                          $self->coverage_blocks_file,
                          $model->sample_name);
    my $in_cmd = sprintf("%s --genotype-indels %s --alignment-file %s --sample-name %s --reads-fasta %s --ref-dir %s",
                            $break_point_path,
                            $self->combined_insertions_file,
                            $self->coverage_blocks_file,
                            $model->sample_name,
                            $model->alignments_directory,
                            $model->reference_sequence_path,
                        );
    my $del_cmd = sprintf("%s --genotype-indels %s --alignment-file %s --sample-name %s --reads-fasta %s --ref-dir %s",
                            $break_point_path,
                            $self->combined_deletions_file,
                            $self->coverage_blocks_file,
                            $model->sample_name,
                            $model->alignments_directory,
                            $model->reference_sequence_path,
                        );
    my @cmds = ($snp_cmd,$in_cmd,$del_cmd);
    for my $cmd (@cmds) {
        $self->status_message('Running: '. $cmd);
        my $rv = system($cmd);
        unless ($rv == 0) {
            $self->error_message("non-zero exit code '$rv' returned from '$cmd'");
            return;
        }
    }

    return 1;
}

sub _cat_files {
    my $self = shift;
    my $out_file = shift;
    my @files = @_;

    if (-s $out_file) {
        $self->error_message("File already exists '$out_file'");
        return;
    }

    my $out_fh = IO::File->new($out_file,'w');
    unless ($out_fh) {
        $self->error_message("File will not open with write priveleges '$out_file'");
        return;
    }
    for my $in_file (@files) {
        my $in_fh = IO::File->new($in_file,'r');
        unless ($in_fh) {
            $self->error_message("File will not open with read priveleges '$in_file'");
            return;
        }
        while (my $line = $in_fh->getline()) {
            $out_fh->print($line);
        }
    }
    $out_fh->close();
    return 1;
}

1;

