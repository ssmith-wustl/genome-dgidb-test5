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
    sample_identifier => {
        is => 'String',
        doc => 'some string to use in model names, etc, such as "BRC2"',
    },
    ],
    has_optional_input => [
    reference_transcripts => {
        is => 'String',
        doc => 'reference transcripts plus version to be used to annotate input indel file',
        default => 'NCBI-human.combined-annotation/54_36p_v2',
    },
    reference_sequence_build_id => {
        is => 'Integer',
        doc => 'Optional reference sequence path (default: NCBI-human-build36 reference sequence build_id 101947881)',
        default => '101947881'
    },
    ],
    doc => 'Begin validation of 3bp indels.',
};

sub help_detail {
    return <<EOS
    This is a first attempt at creating a tool to perform many of the steps for 3bp indel validation which are outlined at this wiki page: https://gscweb.gsc.wustl.edu/wiki/Medical_Genomics/Nimblegen_Solid_Phase_Capture_Validation/Analysis#.3E3bp_Indels. Currently preforms steps 1-3.
EOS
}

sub execute {

    $DB::single = 1;
    my $self = shift;

    #parse input params
    my $indels_full_path = $self->long_indel_file;
    my $output_dir = $self->output_dir;
    my $ref_seq_build_id = $self->reference_sequence_build_id;
    my $ref_seq_build = Genome::Model::Build->get($ref_seq_build_id);
    my $ref_seq_fasta = $ref_seq_build->full_consensus_path('fa');
    my $sample_id = $self->sample_identifier . "_TESTTOOL_";

    #sort indels
    my ($indels_filename_only) = fileparse($indels_full_path);
    my $sort_output = $output_dir . "/" . $indels_filename_only . ".sorted";
=cut
    my $sort_cmd = Genome::Model::Tools::Snp::Sort->create(
        output_file => $sort_output,
        snp_file => $indels_full_path,
    );
    $sort_cmd->execute;
    $sort_cmd->delete;
=cut
    #annotate indels
    my $anno_output = $sort_output . ".anno";
=cut
    my $anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
        output_file => $anno_output,
        annotation_filter => "top",
        #variant_bed_file => $sort_output,
        variant_file => $sort_output,
        reference_transcripts => $self->reference_transcripts,
    );
    $anno_cmd->execute;
    $anno_cmd->delete;
=cut
    #prepare assembly input
    my $assembly_input = $anno_output . ".assembly_input";

=cut
    my $prepare_ass_input_cmd = Genome::Model::Tools::Validation::AnnotationToAssemblyInput->create(
        annotation_file => $anno_output,
        output_file => $assembly_input,
    );
    $prepare_ass_input_cmd->execute;
    $prepare_ass_input_cmd->delete;
=cut
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
=cut
    my $normal_assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $normal_bam,
        output_file =>  $normal_output_file,
        sv_file => $assembly_input,
        min_size_of_confirm_asm_sv => '3',
        flank_size => '200',
        breakpoint_seq_file => $normal_breakpoint_file,
        asm_high_coverage => '1',
        reference_file => $ref_seq_fasta,
    );
    $normal_assembly_cmd->execute;
    $normal_assembly_cmd->delete;
=cut

    #run tigra on the list of predicted indels in the tumor BAM
    my $tumor_output_file = $output_dir . "/tumor.csv";
    my $tumor_breakpoint_file = $output_dir . "/tumor.bkpt.fa";
=cut
    my $tumor_assembly_cmd = Genome::Model::Tools::Sv::AssemblyValidation->create(
        bam_files => $tumor_bam,
        output_file =>  $tumor_output_file,
        sv_file => $assembly_input,
        min_size_of_confirm_asm_sv => '3',
        flank_size => '200',
        breakpoint_seq_file => $tumor_breakpoint_file,
        asm_high_coverage => '1',
        reference_file => $ref_seq_fasta,
    );
    $tumor_assembly_cmd->execute;
    $tumor_assembly_cmd->delete;
=cut
    #build contigs for remapping based on the assembly results
    #gmt validation build-remapping-contigs --normal-assembly-breakpoints-file normal.bkpt.fa --tumor-assembly-breakpoints-file tumor.bkpt.fa --output-file contigs.fa --input-file all_indels.for_assembly --contig-size 500
    my $contigs_file = $output_dir . "/contigs.fa";
=cut
    my $contig_cmd = Genome::Model::Tools::Validation::BuildRemappingContigs->create(
        input_file => $assembly_input,
        normal_assembly_breakpoints_file => $normal_breakpoint_file,
        tumor_assembly_breakpoints_file => $tumor_breakpoint_file,
        output_file => $contigs_file,
        contig_size => '500',
    );
    $contig_cmd->execute;
    $contig_cmd->delete;
=cut

    #create reference sequence using the new contigs (define new reference and track new reference build)
    #my $cmd = "bsub -u ndees\@wustl.edu -J ".$luc."-import genome model define imported-reference-sequence --species-name human --use-default-sequence-uri --derived-from 101947881 --version 500bp_assembled_contigs --fasta-file $contigs --prefix ".$luc."_indels --append-to 101947881";
=cut
    my $new_ref_cmd = Genome::Model::Command::Define::ImportedReferenceSequence->create(
        species_name => 'human',
        use_default_sequence_uri => '1',
        derived_from => $ref_seq_build,
        append_to => $ref_seq_build,
        version => '500bp_assembled_contigs',
        fasta_file => $contigs_file,
        prefix => $sample_id,
    );
    unless ($new_ref_cmd->execute) {
        $self->error_message('Failed to execute the definition of the new reference sequence with added contigs.');
        return;
    }
    my $new_ref_build_id = $new_ref_cmd->result_build_id;
    my $new_ref_build = Genome::Model::Build->get($new_ref_build_id);
    my $new_ref_event = $new_ref_build->the_master_event;
    my $new_ref_event_id = $new_ref_event->id;
    my $new_ref_event_class = $new_ref_event->class;
    while ($new_ref_event->event_status eq 'Running' || $new_ref_event->event_status eq 'Scheduled') {
        sleep 600;
        $new_ref_event = $new_ref_event_class->load($new_ref_event_id);
    }
    unless ($new_ref_event->event_status eq 'Succeeded') {
        $self->error_message('New reference build not successful.');
        return;
    }
=cut
    my $new_ref_build_id = '115047845';
    my $new_ref_build = Genome::Model::Build->get($new_ref_build_id);

    #copy tumor and normal validation models to align data to new reference
    my $new_pp = "dlarson bwa0.5.9 -q 5 indel contig test picard1.42";
    my $new_tumor_model_name = $sample_id . "-Tumor-3bpIndel-Validation";
    my $new_normal_model_name = $sample_id . "-Normal-3bpIndel-Validation";
    #my $tcmd = "genome model copy $tm auto_build_alignments=0 name=$tname processing_profile=name='$pp' reference_sequence_build=$ref region_of_interest_set_name= annotation_reference_build= dbsnp_build=";
    my $tumor_copy = Genome::Model::Command::Copy->create(
        model => $tumor_model,
        overrides => [
        'name='.$new_tumor_model_name,
        'auto_build_alignments=0',
        'processing_profile=name='.$new_pp,
        'reference_sequence_build='.$new_ref_build_id,
        'annotation_reference_build=',
        'region_of_interest_set_name=',
        'dbsnp_build=',
        ],
    );
    $tumor_copy->dump_status_messages(1);
    $tumor_copy->execute or die "copy failed";
    my $new_tumor_model = $tumor_copy->_new_model;
    my $foo = Genome::Model->get($new_tumor_model->id);
    print $foo->id."\n";
    use Devel::Peek;
    Devel::Peek::Dump($new_tumor_model);
    #start new build and track the build
    my $start_cmd = Genome::Model::Build::Command::Start->create(models => [$new_tumor_model]);
    print "after create cmd at this pt\n";
    $start_cmd->dump_status_messages(1);
    unless ($start_cmd->execute) {
        die "couldn't start tumor model copy\n";
    }
    my @builds = $start_cmd->builds;
    for my $build (@builds) {
        my $event = $build->the_master_event;
        my $event_id = $event->id;
        my $event_class = $event->class;
        while ($event->event_status eq 'Running' || $event->event_status eq 'Scheduled') {
            sleep 600;
            $event = $event_class->load($event_id);
        }
        unless ($event->event_status eq 'Succeeded') {
            $self->error_message('Copy of tumor build not successful.');
            return;
        }
    }

    return 1;
}
1;


=cut
my $define_cmd = Genome::Model::Command::Define::ImportedReferenceSequence->create(
);
unless($define_cmd->execute) {
    #fail
}
my $build_id = $define_cmd->result_build_id;
my $build = Genome::Model::Build->get($build_id);
my $event = $build->the_master_event;
my $event_id = $event->id;
my $event_class = $event->class;
while ($event->event_status eq 'Running' || $event->event_status eq 'Scheduled') {
    sleep 60;
    $event = $event_class->load($event_id);
}
unless ($event->event_status eq 'Succeeded') {
    #fail
}
# model copy etc.
my $tumor_model
my $normal_model
# start new ref aligns
my $start_cmd = Genome::Model::Build::Command::Start->create(models => [$normal_model, $tumor_model]);
unless ($start_cmd->execute) {
    #fail
}
my @builds = $start_cmd->builds;
# watch these builds

sub build_status {
    my $build_id = shift

