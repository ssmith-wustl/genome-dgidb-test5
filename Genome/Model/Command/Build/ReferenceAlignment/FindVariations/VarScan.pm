package Genome::Model::Command::Build::ReferenceAlignment::FindVariations::VarScan;

#REVIEW fdu
#1. Fix wrong help_brief/synopsis/detail
#2. Is this actively used in pipeline ? Remove if not


use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ReferenceAlignment::FindVariations::VarScan {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::FindVariations',
       ],
    has => [
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
    my $alignment_file = $self->build->merged_alignments_file;
    my $sample = $model->subject_name;
    my $ref_dir = $model->reference_build->data_directory;
    my $output_dir = $self->build->variants_directory;
    my $fasta_file = $self->build->merged_fasta_file;
    my $quality_file = $self->build->merged_qual_file;

    unless (Genome::Utility::FileSystem->create_directory($output_dir)) {
        $self->error_message('Failed to make variants directory '. $output_dir .":  $!");
        return;
    }

    my $cmd = 'varscan easyrun '. $alignment_file .' --sample '. $sample .' --output-dir '. $output_dir
                .' --fasta-file '. $fasta_file .' --quality-file '. $quality_file;
    #TODO: Should we use the reference to make indel calls?
    #--ref-dir '. $ref_dir
    Genome::Utility::FileSystem->shellcmd(
                                          cmd => $cmd,
                                          #input_directories => [$ref_dir],
                                          input_files => [$alignment_file, $fasta_file, $quality_file],
                                          output_directories => [$output_dir],
                                      );
    return 1;
}


1;

