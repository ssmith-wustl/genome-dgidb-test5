package Genome::Model::Tools::Validation::LongIndelsPartOne;

use warnings;
use strict;
use Genome;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Validation::LongIndelsPartOne {
    is => 'Command',
    has_input => [
    long_indel_bed_file => {
        is => 'String',
        doc => 'unsorted, unannotated 3bp indel file in BED format!!! BED format!!!',
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
    This tool performs the first 5 steps of the 3bp indel validation process outlined on this wiki page: https://gscweb.gsc.wustl.edu/wiki/Medical_Genomics/Nimblegen_Solid_Phase_Capture_Validation/Analysis#.3E3bp_Indels. It then prints out a command which the user may use to run two builds for remapping validation data to a new reference sequence containing indel contigs, and also prints a follow-up command to run to complete the final steps of the 3bp indel process. It also prints out some details for any future manual review tickets of these indels, so save the STDOUT. Remember to address the optional parameters if you are not using HG18 build36.
EOS
}

sub execute {

    my $self = shift;

    #parse input params
    my $indels_full_path = $self->long_indel_bed_file;
    my $output_dir = $self->output_dir;
    my $ref_seq_build_id = $self->reference_sequence_build_id;
    my $ref_seq_build = Genome::Model::Build->get($ref_seq_build_id);
    my $ref_seq_fasta = $ref_seq_build->full_consensus_path('fa');
    my $sample_id = $self->sample_identifier;

    #sort indels
    my ($indels_filename_only) = fileparse($indels_full_path);
    my $sort_output = $output_dir . "/" . $indels_filename_only . ".sorted";
    my $sort_cmd = Genome::Model::Tools::Snp::Sort->create(
        output_file => $sort_output,
        snp_file => $indels_full_path,
    );
    unless ($sort_cmd->execute) {
        die "Sort of indels failed.\n";
    }
    $sort_cmd->delete;

    #annotate indels
    my $anno_output = $sort_output . ".anno";
    my $anno_cmd = Genome::Model::Tools::Annotate::TranscriptVariants->create(
        output_file => $anno_output,
        annotation_filter => "top",
        variant_bed_file => $sort_output,
        #variant_file => $sort_output,
        reference_transcripts => $self->reference_transcripts,
    );
    unless ($anno_cmd->execute) {
        die "Annotation of sorted indels failed.\n";
    }
    $anno_cmd->delete;

    #prepare assembly input
    my $assembly_input = $anno_output . ".assembly_input";
    my $prepare_ass_input_cmd = Genome::Model::Tools::Validation::AnnotationToAssemblyInput->create(
        annotation_file => $anno_output,
        output_file => $assembly_input,
    );
    unless ($prepare_ass_input_cmd->execute) {
        die "annotation-to-assembly-input failed.\n";
    }
    $prepare_ass_input_cmd->delete;

    #secure BAM paths from input params
    my $normal_model = Genome::Model->get($self->normal_val_model_id) or die "Could not find normal model with id $self->normal_val_model_id.\n";
    my $tumor_model = Genome::Model->get($self->tumor_val_model_id) or die "Could not find tumor model with id $self->tumor_val_model_id.\n";
    my $normal_build = $normal_model->last_succeeded_build or die "Could not find last succeeded build from normal model $self->normal_val_model_id.\n";
    my $tumor_build = $tumor_model->last_succeeded_build or die "Could not find last succeeded build from tumor model $self->tumor_val_model_id.\n";
    my $normal_bam = $normal_build->whole_rmdup_bam_file or die "Cannot find normal .bam.\n";
    my $tumor_bam = $tumor_build->whole_rmdup_bam_file or die "Cannot find tumor .bam.\n";

    #run tigra on the list of predicted indels in the normal BAM
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
        reference_file => $ref_seq_fasta,
    );
    unless ($normal_assembly_cmd->execute) {
        die "Normal SV assembly-validation failed (normal.bkpt.fa compromised).\n";
    }
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
        reference_file => $ref_seq_fasta,
    );
    unless ($tumor_assembly_cmd->execute) {
        die "Tumor SV assembly-validation failed (tumor.bkpt.fa compromised).\n";
    }
    $tumor_assembly_cmd->delete;

    #build contigs for remapping based on the assembly results
    my $contigs_file = $output_dir . "/contigs.fa";
    my $contig_cmd = Genome::Model::Tools::Validation::BuildRemappingContigs->create(
        input_file => $assembly_input,
        normal_assembly_breakpoints_file => $normal_breakpoint_file,
        tumor_assembly_breakpoints_file => $tumor_breakpoint_file,
        output_file => $contigs_file,
        contig_size => '500',
    );
    unless ($contig_cmd->execute) {
        die "Failed to build contigs for remapping.\n";
    }
    $contig_cmd->delete;

    #create reference sequence using the new contigs (define new reference and track new reference build)
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

    #copy tumor and normal validation models to align data to new reference
    my $new_pp = "dlarson bwa0.5.9 -q 5 indel contig test picard1.42";
    my $new_tumor_model_name = $sample_id . "-Tumor-3bpIndel-Validation";
    my $new_normal_model_name = $sample_id . "-Normal-3bpIndel-Validation";

    #new tumor model
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
    my $new_tumor_model_id = $new_tumor_model->id;

    #new normal model
    my $normal_copy = Genome::Model::Command::Copy->create(
        model => $normal_model,
        overrides => [
        'name='.$new_normal_model_name,
        'auto_build_alignments=0',
        'processing_profile=name='.$new_pp,
        'reference_sequence_build='.$new_ref_build_id,
        'annotation_reference_build=',
        'region_of_interest_set_name=',
        'dbsnp_build=',
        ],
    );
    $normal_copy->dump_status_messages(1);
    $normal_copy->execute or die "copy failed";
    my $new_normal_model = $normal_copy->_new_model;
    my $new_normal_model_id = $new_normal_model->id;

    #final notices to user
    print "\n\n\n###################### IMPORTANT INFORMATION ######################\n\n";

    #alert user to run builds for these copied models
    print "To start alignments against the new reference sequence which contains the indel contigs, please run this command from genome stable:\n\ngenome model build start $new_tumor_model_id $new_normal_model_id\n\n";

    #alert user to run LongIndelsPartTwo upon the completion of the new tumor and normal contig builds
    print "Upon the successful completion of these builds, please bsub the following command (saving STDOUT) to finish the rest of the steps for 3bp indel validation:\n\n";
    if ($ref_seq_build_id eq '101947881') { #if you are using the default, build 36, for both tools
        print "gmt validation long-indels-part-two --normal-val-model-copy-id $new_normal_model_id --tumor-val-model-copy-id $new_tumor_model_id --output-dir $output_dir\n\n";
    }
    else { #if you are using some other reference build (37)
        print "gmt validation long-indels-part-two --normal-val-model-copy-id $new_normal_model_id --tumor-val-model-copy-id $new_tumor_model_id --output-dir $output_dir --tier-file-location <PUT YOUR TIERING FILES HERE>\n\n";
    }

    #print details for a manual review ticket
    my $new_ref_build_fa = $new_ref_build->full_consensus_path('fa');
    print "And lastly, for your manual review tickets, you will want to include these details, along with further info printed in the STDOUT of 'gmt validation long-indels-part-two':\n\n";
    print "Original tumor validation BAM: $tumor_bam\n";
    print "Original normal validation BAM: $normal_bam\n";
    print "New reference sequence with contigs: $new_ref_build_fa\n";

    return 1;
}

1;
