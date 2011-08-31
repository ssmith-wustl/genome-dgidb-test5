package Genome::Model::Tools::Validation::LongIndels;

use warnings;
use strict;
use Genome;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Validation::LongIndels {
    is => 'Command',
    has_input => [
    long_indel_file => {
        is => 'String',
        doc => 'unsorted, unannotated 3bp indel file',
    },
    output_dir => {
        is => 'String',
        doc => 'directory for output files',
    },
    tumor_val_model_id => {
        is => 'Number',
        doc => 'validation model ID for the tumor sample',
    },
    normal_val_model_id => {
        is => 'Number',
        doc => 'validation model ID for the normal sample',
    },
    ],
    has_optional_input => [
    reference_transcripts => {
        is => 'String',
        doc => 'reference transcripts plus version to be used to annotate input indel file',
        default => 'NCBI-human.combined-annotation/54_36p_v2',
    },
    ref_seq => {
        is => 'String',
        doc => 'Optional reference sequence path (default: NCBI-human-build36)',
        default => '/gscmnt/gc4096/info/model_data/2741951221/build101947881/all_sequences.fa'
    },
    ],
    doc => 'Begin validation of 3bp indels.',
};

sub help_detail {
    return <<EOS
    This is a first attempt at creating a tool to perform many of the steps for 3bp indel validation which are outlined at this wiki page: https://gscweb.gsc.wustl.edu/wiki/Medical_Genomics/Nimblegen_Solid_Phase_Capture_Validation/Analysis#.3E3bp_Indels. Currently preforms steps 1-5.
EOS
}

sub execute {

    $DB::single = 1;
    my $self = shift;

    #parse input params
    my $indels_full_path = $self->long_indel_file;
    my $output_dir = $self->output_dir;
    my $ref_seq = $self->ref_seq;

    #sort indels
    my ($indels_filename_only) = fileparse($indels_full_path);
    my $sort_output = $output_dir . "/" . $indels_filename_only . ".sorted";
    my $sort_cmd = Genome::Model::Tools::Snp::Sort->create(
        output_file => $sort_output,
        snp_file => $indels_full_path,
    );
    $sort_cmd->execute;
    $sort_cmd->delete;

    #annotate indels
    my $anno_output = $sort_output . ".anno";
    my $anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
        output_file => $anno_output,
        annotation_filter => "top",
        variant_bed_file => $sort_output,
        reference_transcripts => $self->reference_transcripts,
    );
    $anno_cmd->execute;
    $anno_cmd->delete;

    #prepare assembly input
    my $assembly_input = $anno_output . ".assembly_input";
    my $prepare_ass_input_cmd = Genome::Model::Tools::Validation::AnnotationToAssemblyInput->create(
        annotation_file => $anno_output,
        output_file => $assembly_input,
    );
    $prepare_ass_input_cmd->execute;
    $prepare_ass_input_cmd->delete;

    #secure BAM paths from input params
    my $normal_model = Genome::Model->get($self->normal_val_model_id) or die "Could not find normal model with id $self->normal_val_model_id.\n";
    my $tumor_model = Genome::Model->get($self->tumor_val_model_id) or die "Could not find tumor model with id $self->tumor_val_model_id.\n";
    my $normal_build = $normal_model->last_succeeded_build or die "Could not find last succeeded build from normal model $self->normal_val_model_id.\n";
    my $tumor_build = $tumor_model->last_succeeded_build or die "Could not find last succeeded build from tumor model $self->tumor_val_model_id.\n";
    my $normal_bam = $normal_build->whole_rmdup_bam_file or die "Cannot find normal .bam.\n";
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file or die "Cannot find tumor .bam.\n";

    #run tigra on the list of predicted indels in the normal BAM
    #gmt sv assembly-validation --bam-files normal.bam --output-file normal.csv --sv-file all_indels.for_assembly --intermediate-read-dir intermediate_normal/ --min-size-of-confirm-asm-sv 3 --flank-size 200 --breakpoint-seq-file normal.bkpt.fa --asm-high-coverage
    my $normal_output_file = $output_dir . "/normal.csv";
    my $normal_breakpoint_file = $output_dir . "/normal.bkpt.fa";
    my $normal_assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $normal_bam,
        output_file =>  $normal_output_file,
        sv_file => $assembly_input,
        min_size_of_confirm_asm_sv => '3',
        flank_size => '200',
        breakpoint_seq_file => $normal_breakpoint_file,
        asm_high_coverage => '1',
        reference_file => $ref_seq,
    );
    $normal_assembly_cmd->execute;
    $normal_assembly_cmd->delete;

    #run tigra on the list of predicted indels in the tumor BAM
    my $tumor_output_file = $output_dir . "/tumor.csv";
    my $tumor_breakpoint_file = $output_dir . "/tumor.bkpt.fa";
    my $tumor_assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $tumor_bam,
        output_file =>  $tumor_output_file,
        sv_file => $assembly_input,
        min_size_of_confirm_asm_sv => '3',
        flank_size => '200',
        breakpoint_seq_file => $tumor_breakpoint_file,
        asm_high_coverage => '1',
        reference_file => $ref_seq,
    );
    $tumor_assembly_cmd->execute;
    $tumor_assembly_cmd->delete;

    #build contigs for remapping based on the assembly results
    #gmt validation build-remapping-contigs --normal-assembly-breakpoints-file normal.bkpt.fa --tumor-assembly-breakpoints-file tumor.bkpt.fa --output-file contigs.fa --input-file all_indels.for_assembly --contig-size 500
    my $contigs_file = $output_dir . "/contigs.fa";
    my $contig_cmd = Genome::Model::Tools::Validation::BuildRemappingContigs->create(
        normal_assembly_breakpoints_file => $normal_breakpoint_file,
        tumor_assembly_breakpoints_file => $tumor_breakpoint_file,
        output_file => $contigs_file,
        contig_size => '500',
    );
    $contig_cmd->execute;
    $contig_cmd->delete;

    return 1;
}
1;




