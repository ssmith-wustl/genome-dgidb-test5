package Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Picard;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use File::Copy;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Picard {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries'],
};

sub help_brief {
    "TBD";
}

sub help_synopsis {
    return <<"EOS"
    TBD 
EOS
}

sub help_detail {
    return <<EOS 
    TBD
EOS
}


sub execute {
    my $self = shift;
    my $now = UR::Time->now;
 
    $self->dump_status_messages(1);
 
    my $alignments_dir = $self->build->accumulated_alignments_directory;
    $self->status_message("Starting DeduplicateLibraries::Picard");
    $self->status_message("Accumulated alignments directory: ".$alignments_dir);
  
    unless (-e $alignments_dir) { 
        unless ($self->create_directory($alignments_dir)) {
            #doesn't exist can't create it...quit
            $self->error_message("Failed to create directory '$alignments_dir':  $!");
            return;
        }
        chmod 02775, $alignments_dir;
    } else {
        unless (-d $alignments_dir) {
            $self->error_message("File already exists for directory '$alignments_dir':  $!");
            return;
        }
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

    # Picard fails when merging BAMs aligned against the transcriptome
    my $merge_software = $self->model->merge_software;
    my $rmdup_version = $self->model->rmdup_version;
    my $samtools_version = $self->model->samtools_version;
    my $rmdup_name = $self->model->rmdup_name;
    unless (defined($merge_software) ) {
        $self->error_message("Merge software not defined for dedup module. Returning.");
        return;
    }
    unless (defined($rmdup_version) ) {
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
    } else {
        $self->status_message("Merge of aligned bam files successful.");
    }
   
   # these are already sorted coming out of the initial merge, so don't bother re-sorting

    my $metrics_file = $self->build->rmdup_metrics_file;
    my $markdup_log_file = $self->build->rmdup_log_file; 

    my $tmp_dir = File::Temp->newdir( "tmp_XXXXX",
                                  DIR => $alignments_dir, 
                                  CLEANUP => 1 );

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
   
   #rename the index file to match the final markdup file name
   my @index_names = <$alignments_dir/*.bai>;
  
   if (scalar(@index_names) eq 1) { 
        my $index_name = $index_names[0];
        my $new_index_name = $bam_merged_output_file.".bai";
        my $rename_rv = rename($index_name,$new_index_name);
        if ($rename_rv eq 1) {
            $self->status_message("Rename of index from $index_name to $new_index_name is successful");
        } else {
            $self->error_message("Rename of index from $index_name to $new_index_name has failed.");
            #not failing here because this is not a critical error.  this can be renamed manually if needed.
        } 
   } else {
            $self->error_message("Could not find an appropriate index file to rename.  Doing nothing.");
            #not failing here because this is not a critical error.  this can be regenerated manually if needed.
   }

   $now = UR::Time->now;
   $self->status_message("<<< Completing MarkDuplicates at $now.");
   $self->status_message("*** All processes completed. ***");

   return $self->verify_successful_completion();
}


sub verify_successful_completion {

    my $self = shift;
    my $build = $self->build;
            
    unless (-s $build->whole_rmdup_bam_file) {
	$self->error_message("Can't verify successful completeion of Deduplication step. ".$build->whole_rmdup_bam_file." does not exist!");	  	
	return;
    }

    #look at the markdups metric file

    return 1;

}


1;
