package Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::Picard;

use strict;
use warnings;

use Genome;
use File::Basename;
use File::Copy;
use IO::File;
use File::stat;

class Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::Picard {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries'],
};

sub execute {
    my $self = shift;
    my $now  = UR::Time->now;
 
    $self->dump_status_messages(1);
    $self->status_message("Starting DeduplicateLibraries::Picard");

    my $alignments_dir = $self->resolve_accumulated_alignments_path;

    $self->status_message("Accumulated alignments directory: ".$alignments_dir);
   
    unless (-e $alignments_dir) { 
       $self->error_message("Alignments dir didn't get allocated/created, can't continue '$alignments_dir':  $!");
       return;
    }

    my $bam_merged_output_file = $self->build->whole_rmdup_bam_file; 
    if (-e $bam_merged_output_file) {
        $self->status_message("A merged and rmdup'd bam file has been found at: $bam_merged_output_file");
        $self->status_message("If you would like to regenerate this file, please delete it and rerun.");
        $now = UR::Time->now;
        $self->status_message("Skipping the rest of DeduplicateLibraries::Samtools at $now");
        $self->status_message("*** All processes skipped. ***");
        return 1;
    } 

    #get the instrument data assignments
    my @bam_files;
    my @idas = $self->build->instrument_data_assignments;
    for my $ida (@idas) {
        my @bam_file = $ida->alignment->alignment_bam_file_paths;
        push(@bam_files, @bam_file);
    } 
    $self->status_message("Collected files for merge and dedup: ".join("\n",@bam_files));

    if (scalar @bam_files == 1 and $self->model->read_aligner_name =~ /^Imported$/i) {
        $self->status_message('Get 1 imported bam '.$bam_files[0]);
        
        unless (Genome::Utility::FileSystem->create_symlink($bam_files[0], $bam_merged_output_file)) {
            $self->error_message("Failed to symlink $bam_files[0] to $bam_merged_output_file");
            return;
        }
        return $self->verify_successful_completion();
    }

    # Picard fails when merging BAMs aligned against the transcriptome
    my $merge_software   = $self->model->merge_software;
    my $rmdup_version    = $self->model->rmdup_version;
    my $samtools_version = $self->model->samtools_version;
    my $rmdup_name       = $self->model->rmdup_name;
    
    unless (defined $merge_software) {
        $self->error_message("Merge software not defined for dedup module. Returning.");
        return;
    }
    unless (defined $rmdup_version ) {
        $self->error_message("Rmdup version not defined for dedup module. Returning.");
        return;
    }
    $self->status_message("Using merge software $merge_software");
    $self->status_message("Using rmdup version $rmdup_version");
    $self->status_message("Using rmdup version $rmdup_name");
    my $pp_name = $self->model->processing_profile_name;
    $self->status_message("Using pp: ".$pp_name);
    
    #my $merge_software;
    #if ($self->model->dna_type eq 'cdna' && $self->model->reference_sequence_name eq 'XStrans_adapt_smallRNA_ribo') {
    #    $merge_software = 'samtools';
    #} else {
    #    $merge_software = 'picard';
    #}

    my $merged_fh = File::Temp->new(SUFFIX => ".bam", DIR => $alignments_dir);
    my $merged_file = $merged_fh->filename;

    my $merge_cmd = Genome::Model::Tools::Sam::Merge->create(
        files_to_merge => \@bam_files,
        merged_file => $merged_file,
        is_sorted => 1,
        bam_index => 0,
        software => $merge_software,
        use_version => $samtools_version,
        use_picard_version => $rmdup_version,
    ); 

    my $merge_rv = $merge_cmd->execute();

    $self->status_message("Merge return value:".$merge_rv);

    if ($merge_rv ne 1)  {
        $self->error_message("Error merging: ".join("\n", @bam_files));
        $self->error_message("Output target: $merged_file");
        $self->error_message("Using software: ".$merge_software);
        $self->error_message("Version: ".$rmdup_version);
        $self->error_message("You may want to check permissions on the files you are trying to merge.");
        return;
    } 
    else {
        $self->status_message("Merge of aligned bam files successful.");
    }
   
   # these are already sorted coming out of the initial merge, so don't bother re-sorting

    my $metrics_file = $self->build->rmdup_metrics_file;
    my $markdup_log_file = $self->build->rmdup_log_file; 

    my $tmp_dir = File::Temp->newdir( 
        "tmp_XXXXX",
        DIR     => $alignments_dir, 
        CLEANUP => 1,
    );

    my $mark_dup_cmd = Genome::Model::Tools::Sam::MarkDuplicates->create(
       file_to_mark => $merged_file,
       marked_file => $bam_merged_output_file,
       metrics_file => $metrics_file,
       remove_duplicates => 0,
       tmp_dir => $tmp_dir->dirname,
       log_file => $markdup_log_file, 
    ); 

    my $mark_dup_rv = $mark_dup_cmd->execute;

    if ($mark_dup_rv ne 1)  {
        $self->error_message("Error Marking Duplicates!");
        $self->error_message("Return value: ".$mark_dup_rv);
        $self->error_message("Check parameters and permissions in the RUN command above.");
        return;
    }

    $now = UR::Time->now;
    $self->status_message("<<< Completing MarkDuplicates at $now.");

    #generate the bam index file
    my $index_cmd = Genome::Model::Tools::Sam::IndexBam->create(
        bam_file => $bam_merged_output_file
    );
    my $index_cmd_rv = $index_cmd->execute;
    
    $self->warning_message("Failed to create bam index for $bam_merged_output_file")
        unless $index_cmd_rv == 1;
    #not failing here because this is not a critical error.  this can be regenerated manually if needed.

    $self->status_message("*** All processes completed. ***");

    return $self->verify_successful_completion();
}


sub verify_successful_completion {
    my $self  = shift;
    my $build = $self->build;
            
    unless (-s $build->whole_rmdup_bam_file) {
	    $self->error_message("Can't verify successful completeion of Deduplication step. ".$build->whole_rmdup_bam_file." does not exist!");	  	
	    return;
    }

    #look at the markdups metric file
    return 1;
}

sub calculate_required_disk_allocation_kb {
    my $self = shift;

    $self->status_message("calculating how many bam files will get incorporated...");

    my @idas = $self->build->instrument_data_assignments;
    my @build_bams;
    for my $ida (@idas) {
        my @alignments = $ida->alignments;
        for my $alignment (@alignments) {
            my @aln_bams = $alignment->alignment_bam_file_paths;
            push @build_bams, @aln_bams;
        }
    }
    my $total_size;
    
    for (@build_bams) {
        $total_size += stat($_)->size;
    }

    #take the total size plus a 10% safety margin
    # 2x total size; full build merged bam, full build deduped bam
    $total_size = sprintf("%.0f", ($total_size/1024)*1.1); 

    $total_size = ($total_size * 2);

    return $total_size;
}



1;
