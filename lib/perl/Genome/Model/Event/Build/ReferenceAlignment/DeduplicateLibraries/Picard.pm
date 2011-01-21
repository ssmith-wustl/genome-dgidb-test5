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

sub shortcut {
    my $self = shift;
    $self->status_message('Looking for existing merged BAM for our alignments...');

    #first check the previous build of our own model
    my $model = $self->model;
    if(my $build = $self->_find_compatible_build_in_model($model)) {
        return $self->_link_result_from_build($build);
    }

    #try other models of the same subject
    my $processing_profile = $model->processing_profile;
    my @candidate_processing_profiles = Genome::ProcessingProfile::ReferenceAlignment->get(
        %{ $processing_profile->processing_profile_params_for_alignment },
        merger_name => $model->merger_name,
        merger_version => $model->merger_version,
        merger_params => $model->merger_params,
        duplication_handler_name => $model->duplication_handler_name,
        duplication_handler_version => $model->duplication_handler_version,
        duplication_handler_params => $model->duplication_handler_params,
        samtools_version => $model->samtools_version,
    );

    my @processing_profile_ids = map($_->id, @candidate_processing_profiles);
    my @candidate_models = Genome::Model::ReferenceAlignment->get(
        subject_id => $model->subject_id,
        subject_class_name => $model->subject_class_name,
        reference_sequence_build => $model->reference_sequence_build,
        'genome_model_id !=' => $model->id,
        processing_profile_id => \@processing_profile_ids,
    );
    for my $model (@candidate_models) {
        if(my $build = $self->_find_compatible_build_in_model($model)){
            return $self->_link_result_from_build($build);
        }
    }

    $self->status_message('No suitable builds found for shortcutting.');
    return;
}

#see if this other model has a build that already computed the result we need
sub _find_compatible_build_in_model {
    my $self = shift;
    my $candidate_model = shift;
    my $build = $self->build;

    #load these all at once
    $candidate_model->instrument_data_assignments;

    my @build_idas = $build->instrument_data_assignments;
    @build_idas = sort { $a->instrument_data_id <=> $b->instrument_data_id } @build_idas;
    my @build_alignments = map { $build->model->processing_profile->results_for_instrument_data_assignment($_) } $build->instrument_data_assignments;

    my @candidate_builds = $candidate_model->completed_builds;
    BUILD: for my $candidate_build (reverse sort {$a->id <=> $b->id} @candidate_builds) {
        next if $candidate_build eq $build; #We can't use ourself to shortcut. (This shouldn't happen anyway, since we're not completed.)

        my @candidate_idas = $candidate_build->instrument_data_assignments;

        next BUILD unless scalar(@candidate_idas) == scalar(@build_idas);
        @candidate_idas = sort { $a->instrument_data_id <=> $b->instrument_data_id } @candidate_idas;

        for my $i (0..$#build_idas) {
            next BUILD if $build_idas[$i]->instrument_data_id != $candidate_idas[$i]->instrument_data_id;
            next BUILD if ($build_idas[$i]->filter_desc || '') ne ($candidate_idas[$i]->filter_desc  || '');
        }

        #okay, both builds have same instrument data assignments--as last check, try to load the individual alignments
        my @candidate_alignments = map { $build->model->processing_profile->results_for_instrument_data_assignment($_) } $build->instrument_data_assignments;

        next BUILD unless scalar(@candidate_alignments) == scalar(@build_alignments);
        for my $i (0..$#build_alignments) {
            next BUILD unless $build_alignments[$i] eq $candidate_alignments[$i];
        }

        #passed all checks--this build can be used to shortcut
        $self->status_message('Found candidate build: ' . $build->__display_name__);
        return $candidate_build;
    }

    #exhausted builds--give up
    return;
}

sub _link_result_from_build {
    my $self = shift;
    my $build = shift;

    my $target_bam = $build->whole_rmdup_bam_file;
    unless(-e $target_bam) {
        $self->error_message('BAM file not found on target build (' . $build->__display_name__ . '): ' . $target_bam);
        return;
    }

    if(-l $target_bam) {
        $target_bam = readlink($target_bam);
        unless(-e $target_bam) {
            $self->error_message('BAM file symlink target not found on target build (' . $build->__display_name__ . '): ' . $target_bam);
            return;
        }
    }

    my $accumulated_alignments_directory = $self->build->accumulated_alignments_directory;
    unless(-d $accumulated_alignments_directory || -l $accumulated_alignments_directory) {
        Genome::Utility::FileSystem->create_directory($accumulated_alignments_directory);
    }

    $self->status_message('Going to link ' . $target_bam);

    my @ext = ('.bai', '.flagstat', '');
    for my $ext (@ext) {
        unless(-e $target_bam . $ext) {
            $self->error_message('Did not find ' . $target_bam . $ext);
            return;
        }
    }

    my $whole_rmdup_bam_file = $self->build->whole_rmdup_bam_file;
    for my $ext (@ext) {
        Genome::Utility::FileSystem->create_symlink($target_bam . $ext, $whole_rmdup_bam_file . $ext)
            unless -e ($whole_rmdup_bam_file . $ext);
    }

    #make a note in the other build that its BAM is used externally
    my $in_use_file = $target_bam . '.in_use';
    Genome::Utility::FileSystem->shellcmd(
        cmd => 'echo ' . $self->build->id . ' >> ' . $in_use_file,
        output_files => [$in_use_file],
        skip_if_output_present => 0,
    );

    $self->status_message('Successfully shortcut duplication.');
    return 1;
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

    my @alignments = $self->_get_alignment_objects;

    for my $alignment (@alignments) {
        my @bams = $alignment->alignment_bam_file_paths;
        unless(scalar @bams) {
            # TODO: change this to not have a special retval.
            if($alignment->aligner_name eq 'maq' and $alignment->verify_aligner_successful_completion eq 2) {
                $self->status_message("No bam for alignment of instrument data #" . $alignment->instrument_data_id . " due to 'no reasonable reads'");
            } else {
                $self->error_message("Couldn't find bam for alignment of instrument data #" . $alignment->instrument_data_id);
                return;
            }
        }
        if(scalar @bams > 1) {
            $self->warning_message("Found multiple bam files for alignment of instrument data #" . $alignment->instrument_data_id);
        }
        $self->status_message("bam file paths: ". join ":", @bams);
        push @bam_files, @bams;
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
    my $merger_name      = $self->model->merger_name;
    my $merger_version   = $self->model->merger_version;
    my $merger_params    = $self->model->merger_params;
    my $dedup_name       = $self->model->duplication_handler_name;
    my $dedup_version    = $self->model->duplication_handler_version;
    my $dedup_params     = $self->model->duplication_handler_params;
    my $samtools_version = $self->model->samtools_version;

    unless (defined $merger_name) {
        $self->error_message("Merger_name not defined for dedup module. Returning.");
        return;
    }
    unless (defined $dedup_version ) {
        $self->error_message("duplication_handler_version not defined for dedup module. Returning.");
        return;
    }
    $self->status_message("Using merger name $merger_name, merger version $merger_version, dedup name $dedup_name, dedup version $dedup_version");
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
        merger_name => $merger_name,
        merger_version => $merger_version,
        merger_params  => $merger_params,
        use_version => $samtools_version, #if merger_name is samtools, use_version will be reset to $merger_verison to be consistent
        max_jvm_heap_size => $self->max_jvm_heap_size,
    ); 

    my $merge_rv = $merge_cmd->execute();
    $self->status_message("Merge return value:".$merge_rv);

    if ($merge_rv != 1)  {
        $self->error_message("Error merging: ".join("\n", @bam_files));
        $self->error_message("Output target: $merged_file");
        $self->error_message("Using software: ".$merger_name);
        $self->error_message("Version: ".$dedup_version);
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
            dedup_version => $dedup_version,
            dedup_params  => $dedup_params,
            max_jvm_heap_size => $self->max_jvm_heap_size,
        );
        
        my $mark_dup_cmd = Genome::Model::Tools::Sam::MarkDuplicates->create(%mark_duplicates_params);
        my $mark_dup_rv  = $mark_dup_cmd->execute;

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
        unlink("$merged_file");
        unlink("$merged_file.flagstat");
    
        $now = UR::Time->now;
        $self->status_message("<<< Completing MarkDuplicates at $now.");
    }
    
    $self->status_message("Indexing the final BAM file...");
    my $index_cmd = Genome::Model::Tools::Sam::IndexBam->create(
        bam_file    => $bam_merged_output_file,
        use_version => $self->_sam_use_version,
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
            use_version    => $self->_sam_use_version,
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


sub _sam_use_version {
    my $self = shift;

    if ($self->model->merger_name eq 'samtools') {
        return $self->model->merger_version;
    }
    return $self->model->samtools_version;
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

sub _get_alignment_objects {
    my $self = shift;

    my @idas = $self->build->instrument_data_assignments;
    $self->status_message("Found " . scalar(@idas) . " assigned instrument data");
    unless (@idas) {
        $self->error_message("No instrument data assigned to this build!!!???");
        return;
    }


    my @alignments;
    for my $ida (@idas) {

        my @alignment_events = grep {$_->instrument_data_id == $ida->instrument_data_id} grep {$_->isa('Genome::Model::Event::Build::ReferenceAlignment::AlignReads')} $self->build->events;
    
        # if this is not a chunked alignment
        if (@alignment_events == 1) {
            push @alignments, $self->model->processing_profile->results_for_instrument_data_assignment($ida);
        } else {
            my @chunk_ids = map {$_->instrument_data_segment_id} @alignment_events;
            my @chunk_types = map {$_->instrument_data_segment_type} @alignment_events;
            
            unless (scalar @chunk_ids == scalar @chunk_types) {
                $self->error_message("List of chunk ids is not same length as chunk types.  Bailing out");
                return;
            }
        
            for my $i (0...$#chunk_ids) {
                push @alignments, $self->model->processing_profile->results_for_instrument_data_assignment($ida, instrument_data_segment_id=>$chunk_ids[$i], instrument_data_segment_type=>$chunk_types[$i]);
            }
        }
    }

    return @alignments;
}

sub calculate_required_disk_allocation_kb {
    my $self = shift;

    $self->status_message("calculating how many bam files will get incorporated...");

    my $build = $self->build;
    my $model = $build->model;
    my $processing_profile = $model->processing_profile;
    my @idas = $build->instrument_data_assignments;
    $self->status_message("Found " . scalar(@idas) . " assigned instrument data");

    my @alignments = $self->_get_alignment_objects;

    my @build_bams;
    for my $alignment (@alignments) {
        my @aln_bams = $alignment->alignment_bam_file_paths;
        unless (@aln_bams) {
            $self->status_message("alignment $alignment has no bams at " . $alignment->output_dir);
        }
        $self->status_message("Counting bams: " . join ",", @aln_bams);
        push @build_bams, @aln_bams;
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
