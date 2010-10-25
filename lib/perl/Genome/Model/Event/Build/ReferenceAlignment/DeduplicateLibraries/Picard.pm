package Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::Picard;

use strict;
use warnings;

use Genome;
use Genome::Info::BamFlagstat;
use File::Basename;
use File::Copy;
use IO::File;
use File::stat;

my $MAX_JVM_HEAP_SIZE = 12;

class Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::Picard {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries'],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=90000:mem=16000]' -M 16000000";
}

sub max_jvm_heap_size {
    return $MAX_JVM_HEAP_SIZE;
}

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

    my $build = $self->build;
    my $model = $build->model;
    my $processing_profile = $model->processing_profile;

    #get the instrument data assignments
    my @bam_files;
    my @idas = $self->build->instrument_data_assignments;
    $self->status_message("Found " . scalar(@idas) . " assigned instrument data");
    unless (@idas) {
        $self->error_message("No instrument data assigned to this build!!!???  Quitting...");
        return;
    }

    for my $ida (@idas) {
        my @alignments = $processing_profile->results_for_instrument_data_assignment($ida);
        $self->status_message("Found " . scalar(@alignments) . " alignment sets for instrument data " . $ida->__display_name__);
        for my $alignment (@alignments) {
            my @bams = $alignment->alignment_bam_file_paths;
            unless(scalar @bams) {
                # TODO: change this to not have a special retval.
                if($alignment->aligner_name eq 'maq' and $alignment->verify_aligner_successful_completion eq 2) {
                    $self->status_message("No bam for alignment of instrument data #" . $ida->instrument_data_id . " due to 'no reasonable reads'");
                } else {
                    $self->error_message("Couldn't find bam for alignment of instrument data #" . $ida->instrument_data_id);
                    return;
                }
            }
            if(scalar @bams > 1) {
                $self->warning_message("Found multiple bam files for alignment of instrument data #" . $ida->instrument_data_id);
            }
            $self->status_message("bam file paths: ". @bams);
            push @bam_files, @bams;
        }
    } 
    $self->status_message("Collected files for merge and dedup: ".join("\n",@bam_files));
    if (@bam_files == 0) {
        $self->error_message("NO BAM FILES???  Quitting");
        return;
    }
    
    $self->status_message('Checking bams...');
    my $individual_flagstat_total = 0;
    for my $bam_file (@bam_files) {
        $individual_flagstat_total += $self->_bam_flagstat_total($bam_file); 
    }
    $self->status_message('Bam flagstat complete (individual total: ' . $individual_flagstat_total);
    
    my $bam_merged_output_file = $self->build->whole_rmdup_bam_file; 
    
    #Check if we already have a complete merged and rmdup'd bam
    if (-e $bam_merged_output_file) {
        $self->status_message("A merged and rmdup'd bam file has been found at: $bam_merged_output_file");
        
        $self->status_message("Checking that merged and rmdup'd bam contains expected alignment count.");
        
        my $dedup_flagstat_total = $self->_bam_flagstat_total($bam_merged_output_file);
        
        #$self->status_message("If you would like to regenerate this file, please delete it and rerun.");
        $now = UR::Time->now;
        
        if($dedup_flagstat_total eq $individual_flagstat_total) {
            $self->status_message("Dedup total ($dedup_flagstat_total) matches sum of individual BAMs.");
            $self->status_message("Skipping the rest of DeduplicateLibraries::Picard at $now");
            $self->status_message("*** All processes skipped. ***");
            return 1;
        } else {
            $self->status_message("The found merged and rmdup'd bam file didn't match (dedup: $dedup_flagstat_total).  Deleting and regenerating.");
            unlink($bam_merged_output_file);
        }

    }    

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

    Genome::DataSource::GMSchema->disconnect_default_dbh; 
  
    my $merged_fh = File::Temp->new(SUFFIX => ".bam", DIR => $alignments_dir );
    my $merged_file = $merged_fh->filename;

    my $merge_cmd = Genome::Model::Tools::Sam::Merge->create(
        files_to_merge => \@bam_files,
        merged_file => $merged_file,
        is_sorted => 1,
        bam_index => 0,
        software => $merge_software,
        use_version => $samtools_version,
        use_picard_version => $rmdup_version,
        max_jvm_heap_size => $self->max_jvm_heap_size,
    ); 

    my $merge_rv = $merge_cmd->execute();
    $self->status_message("Merge return value:".$merge_rv);

    if ($merge_rv != 1)  {
        $self->error_message("Error merging: ".join("\n", @bam_files));
        $self->error_message("Output target: $merged_file");
        $self->error_message("Using software: ".$merge_software);
        $self->error_message("Version: ".$rmdup_version);
        $self->error_message("You may want to check permissions on the files you are trying to merge.");
        return;
    } 

    $self->status_message("Checking that merged bam contains expected alignment count.");
    my $merged_flagstat_total = $self->_bam_flagstat_total($merged_file);
    unless($merged_flagstat_total == $individual_flagstat_total) {
        $self->error_message("Alignment counts of individual bams and merged bam don't match!");
        $self->error_message("(Individual sumtotal: " . $individual_flagstat_total . ", Merged total: " . $merged_flagstat_total);
        return;
    }    
    $self->status_message("Merge of aligned bam files successful.");

    my $flagstat_file = $merged_file . '.flagstat';
    my $flagstat_hashref = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_file);
    $self->status_message("Flagstat results: " . Data::Dumper::Dumper($flagstat_hashref));
    my $reads_mapped = $flagstat_hashref->{reads_mapped};
    $self->status_message("Mapped read count after merge is " . $reads_mapped);
   
    if ($reads_mapped == 0) {
        # all reads are unmapped
        $self->status_message("Skipping marking duplicates since no reads aligned, and the tool crashes in this case.");
        rename($merged_file, $bam_merged_output_file);
        rename($merged_file . '.flagstat', $bam_merged_output_file . '.flagstat');
    }
    else {
        # some reads mapped, mark duplicates within a library
        my $metrics_file = $self->build->rmdup_metrics_file;
        my $markdup_log_file = $self->build->rmdup_log_file; 
    
        my $tmp_dir = File::Temp->newdir( 
            "tmp_XXXXX",
            DIR     => $alignments_dir, 
            CLEANUP => 1,
        );
        
        my $result_tmp_dir = File::Temp->newdir( 
            "tmp_XXXXX",
            DIR     => $alignments_dir, 
            CLEANUP => 1,
        );
       
        # fix permissions on this temp dir so others can clean it up later if need be
        chmod(0775,$tmp_dir);
        chmod(0775,$result_tmp_dir);
        
        my $dedup_temp_file = $result_tmp_dir . '/dedup.bam';
        my %mark_duplicates_params = (
            file_to_mark => $merged_file,
           marked_file => $dedup_temp_file,
           metrics_file => $metrics_file,
           remove_duplicates => 0,
           tmp_dir => $tmp_dir->dirname,
           log_file => $markdup_log_file, 
           use_picard_version => $rmdup_version,
           max_jvm_heap_size => $self->max_jvm_heap_size,
        );
        if (defined($processing_profile->picard_max_sequences_for_disk_read_ends_map)) {
            $mark_duplicates_params{max_sequences_for_disk_read_ends_map} = $processing_profile->picard_max_sequences_for_disk_read_ends_map;
        }
        my $mark_dup_cmd = Genome::Model::Tools::Sam::MarkDuplicates->create(%mark_duplicates_params);
    
        my $mark_dup_rv = $mark_dup_cmd->execute;
        if ($mark_dup_rv != 1)  {
            $self->error_message("Error Marking Duplicates!");
            $self->error_message("Return value: ".$mark_dup_rv);
            $self->error_message("Check parameters and permissions in the RUN command above.");
            return;
        } 
    
        $self->status_message("Checking that deduplicated bam contains expected alignment count.");
        my $dedup_flagstat_total = $self->_bam_flagstat_total($dedup_temp_file);
        unless($individual_flagstat_total == $dedup_flagstat_total) {
            $self->error_message("Alignment counts of dedup bam and individual bams don't match!");
            $self->error_message("(Dedup total: " . $dedup_flagstat_total . ", Individual total: " . $individual_flagstat_total);
            return;
        }
        $self->status_message("Deduplicated bam count verified.");
        
        rename($dedup_temp_file, $bam_merged_output_file);
        rename($dedup_temp_file . '.flagstat', $bam_merged_output_file . '.flagstat');
    
        $now = UR::Time->now;
        $self->status_message("<<< Completing MarkDuplicates at $now.");
    }
    
    $self->status_message("Indexing the final BAM file...");
    my $index_cmd = Genome::Model::Tools::Sam::IndexBam->create(
        bam_file => $bam_merged_output_file
    );
    my $index_cmd_rv = $index_cmd->execute;
    
    $self->warning_message("Failed to create bam index for $bam_merged_output_file")
        unless $index_cmd_rv == 1;
    #not failing here because this is not a critical error.  this can be regenerated manually if needed.

    $self->create_bam_md5;

    for my $file (grep {-f $_} glob($build->accumulated_alignments_directory . "/*")) {
        $self->status_message("Setting $file to read-only");
        chmod 0444, $file;
    }

    $self->status_message("*** All processes completed. ***");

    return $self->verify_successful_completion();
}

sub _bam_flagstat_total {
    my $self      = shift;
    my $bam_file  = shift;
    my $flag_file = $bam_file . '.flagstat';
    
    unless (-s $flag_file) {
        my $cmd = Genome::Model::Tools::Sam::Flagstat->create(
            bam_file       => $bam_file,
            output_file    => $flag_file,
            include_stderr => 1,
        );
        
        unless($cmd and $cmd->execute) {
            $self->error_message("Fail to create or execute flagstat command on bam file: $bam_file");
            return;
        }
    }
    
    my $flagstat_data = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flag_file);
        
    unless($flagstat_data) {
        $self->error_message('No output from samtools flagstat');
        return;
    }
    
    if(exists $flagstat_data->{errors}) {
        for my $error (@{ $flagstat_data->{errors} }) {
            if($error =~ m/Truncated file/) {
                $self->error_message('Flagstat output for ' . $bam_file . ' indicates possible truncation.');
            }
        }
    }
    
    my $total = $flagstat_data->{total_reads};
    
    $self->status_message('flagstat for ' . $bam_file . ' reports ' . $total . ' in total');    
    return $total;
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

    my $build = $self->build;
    my $model = $build->model;
    my $processing_profile = $model->processing_profile;
    my @idas = $model->instrument_data_assignments;
    $self->status_message("Found " . scalar(@idas) . " assigned instrument data");

    my @build_bams;
    for my $ida (@idas) {
        my @alignments = $processing_profile->results_for_instrument_data_assignment($ida);
        $self->status_message($ida->__display_name__ . " has @alignments\n");
        for my $alignment (@alignments) {
            my @aln_bams = $alignment->alignment_bam_file_paths;
            unless (@aln_bams) {
                $self->status_message("alignment $alignment has no bams at " . $alignment->output);
            }
            push @build_bams, @aln_bams;
        }
    }
    my $total_size;
    
    unless (@build_bams) {
        die "No bams?";
    }

    for (@build_bams) {
        my $size = stat($_)->size;
        $self->status_message("BAM has size: " . $size);
        $total_size += $size;
    }

    #take the total size plus a 10% safety margin
    # 2x total size; full build merged bam, full build deduped bam
    $total_size = sprintf("%.0f", ($total_size/1024)*1.1); 
    $total_size = ($total_size * 2);

    $self->status_message("Allocating $total_size for the combined BAM file (est. size x 2)");

    return $total_size;
}



1;
