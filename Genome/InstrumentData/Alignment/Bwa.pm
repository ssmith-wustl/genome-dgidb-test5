package Genome::InstrumentData::Alignment::Bwa;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Bwa {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
                     aligner_name => { value => 'bwa' },
    ],
};

sub _resolve_subclass_name_for_aligner_name {
	return "Genome::InstrumentData::Alignment::Bwa";
}

# TODO: FILL ME IN
sub get_alignment_statistics {
    my $self = shift;
    my $aligner_output_file = shift;
    return {};
}


sub verify_aligner_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;
        
    unless ($aligner_output_file) {
        $aligner_output_file = $self->aligner_output_file_path;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }
    
    unless (-s $self->alignment_file) {
	$self->error_message("Alignment file " . $self->alignment_file . " not found or zero size.");
	return;
    }

    return 1;
}

sub output_files {
    my $self = shift;
    my @output_files;
    for my $method ('alignment_file_paths', 'aligner_output_file_paths','unaligned_reads_list_paths','unaligned_reads_fastq_paths') {
        push @output_files, $self->$method;
    }
    return @output_files;
}

#####ALIGNMENTS#####
#a glob for all alignment files
sub alignment_file_paths {
    my $self = shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ && $_ !~ /aligner_output/ }
            glob($self->alignment_directory .'/*.bam*');
}
sub alignment_bam_file_paths {
    my $self = shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    my @bam_files = grep { -e $_ && $_ !~ /merged_rmdup/} glob($self->alignment_directory .'/*.bam');

    return @bam_files;
}

#####ALIGNER OUTPUT#####
#a glob for existing aligner output files
sub aligner_output_file_paths {
    my $self=shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*.bwa.aligner_output*');
}

#the fully quallified file path for aligner output
sub aligner_output_file_path {
    my $self = shift;
    my $file = $self->alignment_directory . $self->aligner_output_file_name;
    return $file;
}

sub aligner_output_file_name {
    my $self = shift;
    my $lane = $self->instrument_data->subset_name;
    my $file = "/alignments_lane_${lane}.bwa.aligner_output";
    return $file;
}

sub input_pathnames {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    my %params;
    if ($self->force_fragment) {
        if ($self->instrument_data_id eq $self->_fragment_seq_id) {
            $params{paired_end_as_fragment} = 2;
        } else {
            $params{paired_end_as_fragment} = 1;
        }
    }
    my @illumina_fastq_pathnames = $instrument_data->fastq_filenames(%params);
    return @illumina_fastq_pathnames;
}

sub formatted_aligner_params {
    my $self = shift;
    my $params = $self->aligner_params || ":::";
    
    my @spar = split /\:/, $params;
    
    
    return ('bwa_aln_params' => $spar[0], 'bwa_samse_params' => $spar[1], 'bwa_sampe_params' => $spar[2]);
    
}

sub alignment_file {
    my $self = shift;
    return $self->alignment_directory .'/all_sequences.bam';
}

#####UNALIGNED READS LIST#####
#a glob for existing unaligned reads list files
sub unaligned_reads_list_paths {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } grep { $_ !~ /\.fastq$/ } glob($self->alignment_directory .'/*'.
                                                         $subset_name .'_sequence.unaligned*');
}

#the fully quallified file path for unaligned reads
sub unaligned_reads_list_path {
    my $self = shift;
    return $self->alignment_directory . $self->unaligned_reads_list_file_name;
}

sub unaligned_reads_list_file_name {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return "/s_${subset_name}_sequence.unaligned";
}

#####UNALIGNED READS FASTQ#####
#a glob for existing unaligned reads fastq files

sub unaligned_reads_fastq_paths  {
    my $self=shift;
    my $subset_name = $self->instrument_data->subset_name;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*'.
                               $subset_name .'_sequence.unaligned*.fastq');
}

#the fully quallified file path for unaligned reads fastq
sub unaligned_reads_fastq_path {
    my $self = shift;
    return $self->alignment_directory . $self->unaligned_reads_fastq_file_name;
}

sub unaligned_reads_fastq_file_name {
    my $self = shift;
    my $subset_name = $self->instrument_data->subset_name;
    return "/s_${subset_name}_sequence.unaligned.fastq";
}


sub find_or_generate_alignment_data {
    my $self = shift;
    
    unless ($self->samtools_version) {
        $self->warning_message('samtools version is not defined, the default version will be used');
        $self->samtools_version(Genome::Model::Tools::Sam->default_samtools_version);
    }
    unless ($self->picard_version) {
        $self->status_message('Picard version is not defined, the default version will be used');
        $self->picard_version(Genome::Model::Tools::Sam->default_picard_version);
    }
    
    $self->status_message('Samtools version: '.$self->samtools_version);
    $self->status_message('Picard version: '.$self->picard_version);

    unless ($self->verify_alignment_data) {
        $self->status_message("Could not validate alignments.  Running aligner.");
        return $self->_run_aligner();
    } else {
        $self->status_message("Existing alignment data is available and deemed correct.");
        $self->status_message("Alignment directory: ".$self->alignment_directory);
    }

    return 1;
}


sub verify_alignment_data {
    my $self = shift;

    my $lock;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;
    
    unless ($self->_resource_lock) {
	    $lock = $self->lock_alignment_resource;
    } else {
	    $lock = $self->_resource_lock;
    }
    
    unless ($self->output_files) {
        $self->status_message('No output files found in alignment directory: '. $alignment_dir);
        return;
    }
    
    unless (-e $self->alignment_file) {
	    $self->status_message('No output files found in alignment directory: '. $alignment_dir . " missing file: " . $self->alignment_file);
	    return;
    }

    my $vh = Genome::Model::Tools::Sam::ValidateHeader->create(input_file=>$self->alignment_file,
                                                               use_version=>$self->samtools_version);
    unless ($vh->execute) {   
	$self->status_message("Alignment file " . $self->alignment_file . " does not have a valid header.");
        return;
    }

    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
 
    return 1;
}

sub _run_aligner {
    my $self = shift;
    
    my $lock;

    unless ($self->_resource_lock) {
	    $lock = $self->lock_alignment_resource;
    } else {
	    $lock = $self->_resource_lock;
    }

    #delete everything in the alignment_dir
    $self->remove_alignment_directory_contents;

    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;

    $self->status_message("OUTPUT PATH: $alignment_directory\n");

    # these are general params not infered from the above
    my %aligner_params = $self->formatted_aligner_params;
    
    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $self->sanger_fastq_filenames;
    $self->status_message("INPUT PATH(S): @input_pathnames\n");
    
    
    # establish ourselves a scratch dir
    my $tmp_dir = File::Temp::tempdir( CLEANUP => 1 );
    
    my $ref_basename = File::Basename::fileparse($reference_build->full_consensus_path('fa'));
    my $reference_fasta_path = sprintf("%s/%s",
				       $reference_build->data_directory,
				       $ref_basename);

    
    my $reference_fasta_index_path = $reference_fasta_path . ".fai";
    
    # make sure we have the necessary input files, and die off right away if not
    
    unless(-e $reference_fasta_path) {
	$self->error_message("Alignment reference path $reference_fasta_path does not exist");
	$self->die_and_clean_up($self->error_message);
    }
    
    unless(-e $reference_fasta_index_path) {
	$self->error_message("Alignment reference index path $reference_fasta_index_path does not exist. Use 'samtools faidx' to create this");
	$self->die_and_clean_up($self->error_message);
    }
    
    # db disconnect prior to alignment
    Genome::DataSource::GMSchema->disconnect_default_dbh; 

    ### STEP 1: Use "bwa aln" to generate the alignment coordinate file for the input reads (.sai file)
    ### Must be run once for each of the input files
    
    my @sai_intermediate_files;
    my @aln_log_files;
    
    my $bwa_aln_params = (defined $aligner_params{'bwa_aln_params'} ? $aligner_params{'bwa_aln_params'} : "");
    
    foreach my $input (@input_pathnames) {


        my $tmp_sai_file = File::Temp->new( DIR => $tmp_dir, SUFFIX => ".sai" );
	my $tmp_log_file = File::Temp->new( DIR => $tmp_dir, SUFFIX => ".bwa.aln.log");

	
        my $cmdline = Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version)
	    . sprintf( ' aln %s %s %s 1> ',
		       $bwa_aln_params, $reference_fasta_path, $input )
	    . $tmp_sai_file->filename . ' 2>>'
	    . $tmp_log_file->filename;
	
	
        push @sai_intermediate_files, $tmp_sai_file;
	push @aln_log_files, $tmp_log_file;
	
        # run the aligner
        Genome::Utility::FileSystem->shellcmd(
            cmd          => $cmdline,
            input_files  => [ $reference_fasta_path, $input ],
            output_files => [ $tmp_sai_file->filename, $tmp_log_file->filename ],
            skip_if_output_is_present => 0,
	    );
        unless ($self->_verify_bwa_aln_did_happen(sai_file => $tmp_sai_file->filename,
						  log_file => $tmp_log_file->filename)) {
	    $self->error_message("bwa aln did not seem to successfully take place for " . $reference_fasta_path);
	    $self->die_and_clean_up($self->error_message);
	}
    }
    
    #### STEP 2: Use "bwa samse" or "bwa sampe" to perform single-ended or paired alignments, respectively.
    #### Runs once for ALL input files

    # come up with an upper bound on insert size.

    my $bwa_sampe_params = (defined $aligner_params{'bwa_sampe_params'} ? $aligner_params{'bwa_sampe_params'} : "");
    my $bwa_samse_params = (defined $aligner_params{'bwa_samse_params'} ? $aligner_params{'bwa_samse_params'} : "");

    my $is_paired_end;
    my $upper_bound_on_insert_size;
    if ($instrument_data->is_paired_end && !$self->force_fragment) {
        my $sd_above = $instrument_data->sd_above_insert_size;
        my $median_insert = $instrument_data->median_insert_size;
        $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
        unless($upper_bound_on_insert_size > 0) {
            $self->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
            $upper_bound_on_insert_size= 600;
        }

	if ($bwa_sampe_params =~ m/\-a (\d+)/) {
	    $self->status_message("Aligner params specify a -a parameter ($1) as upper bound on insert size.  Using that instead");
	    $upper_bound_on_insert_size=$1;	    
	}
	
	$bwa_sampe_params .= " -a $upper_bound_on_insert_size";

        $is_paired_end = 1;
    }
    else {
        $is_paired_end = 0;
    }

    my $samxe_logfile = File::Temp->new( DIR => $tmp_dir, SUFFIX => ".bwa.samxe.log");
    
    my $sam_command_line = "";
    if ( @input_pathnames == 1 ) {
	
	$sam_command_line = Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version)
	    . sprintf(
	    ' samse %s %s %s %s',
	    $bwa_samse_params, $reference_fasta_path,
	    $sai_intermediate_files[0]->filename,
	    $input_pathnames[0]
	    )
	    . " 2>>"
	    . $samxe_logfile->filename
	
    }
    else {
	
	# paired run
	#my $upper_bound_option     = '-a ' . $self->upper_bound;
	#my $max_occurrences_option = '-o ' . $self->max_occurrences;
	my $paired_options = ""; #$upper_bound_option $max_occurrences_option";
	
	$sam_command_line = Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version)
	    . sprintf(
	    ' sampe %s %s %s %s',
	    $bwa_sampe_params,
	    $reference_fasta_path,
	    join (' ', map {$_->filename} @sai_intermediate_files),
	    join (' ', @input_pathnames)
	    )
	    . " 2>>"
	    . $samxe_logfile->filename
    } 
    
    $self->status_message("Running samXe to get the output alignments");
    
    #BWA is not nice enough to give us an unaligned output file so we need to
    #filter it out on our own
    
    my $sam_map_output_fh =
	File::Temp->new( DIR => $tmp_dir, SUFFIX => ".sam" );
    my $unaligned_output_fh =
	IO::File->new( ">" . $self->unaligned_reads_list_path );

    my $sam_run_output_fh = IO::File->new( $sam_command_line . "|" );
    if ( !$sam_run_output_fh ) {
	$self->error_message("Error running $sam_command_line $!");
	return;
    }
    
    while (<$sam_run_output_fh>) {
	my @line = split /\s+/;
	
	# third column with a * indicates an unaligned read in the SAM format per samtools man page
	if ( $line[2] eq "*" ) {
	    $unaligned_output_fh->print($_);
	}
	else {
            #write out the aligned map, excluding the default header- all lines starting with @.
            my $first_char = substr($line[0],0,1);
	    if ($first_char ne "@") {
                $sam_map_output_fh->print($_);
            }
	}
    }
    
    $unaligned_output_fh->close();
    $sam_map_output_fh->close();
        
     unless ($self->process_low_quality_alignments) {
        $self->error_message('Failed to process_low_quality_alignments');
        $self->die_and_clean_up($self->error_message);
    }
    
        $DB::single = 1;

    my $insert_size_for_header;
    if ($self->instrument_data->median_insert_size) {
        $insert_size_for_header= $self->instrument_data->median_insert_size;
    } else {
        $insert_size_for_header = 0;
    }

    my $description_for_header;
    if ($self->instrument_data->is_paired_end) {
        $description_for_header = 'paired end';
    } else {
        $description_for_header = 'fragment';
    }

    #### Beginning changes for TCGA compliance
 
    my $output_sam_tmp_file = File::Temp->new(SUFFIX=>'.sam', DIR=>$self->alignment_directory);
    unless ($output_sam_tmp_file) {
        $self->error_message("Couldn't open an output file in " . $self->alignment_directory . " to put our all_sequences.bam.  Check disk space and permissions!");
        return;
    }

    my $id_tag = $self->instrument_data->seq_id;
    my $pu_tag = sprintf("%s.%s",$self->instrument_data->flow_cell_id,$self->instrument_data->lane);
    my $lib_tag = $self->instrument_data->library_name;
    my $date_run_tag = $self->instrument_data->run_start_date_formatted;
    my $sample_tag = $self->instrument_data->sample_name;
    my $aligner_version_tag = $self->aligner_version;
    my $aligner_cmd =  sprintf("bwa aln %s", $bwa_aln_params);

                 #@RG     ID:2723755796   PL:illumina     PU:30945.1      LB:H_GP-0124n-lib1      PI:0    DS:paired end   DT:2008-10-03   SM:H_GP-0124n   CN:WUGSC
                 #@PG     ID:0    VN:0.4.9        CL:bwa aln -t4
    my $rg_tag = "\@RG\tID:$id_tag\tPL:illumina\tPU:$pu_tag\tLB:$lib_tag\tPI:$insert_size_for_header\tDS:$description_for_header\tDT:$date_run_tag\tSM:$sample_tag\tCN:WUGSC\n";
    my $pg_tag = "\@PG\tID:$id_tag\tVN:$aligner_version_tag\tCL:$aligner_cmd\n";

    $self->status_message("RG: $rg_tag");
    $self->status_message("PG: $pg_tag");
    my $header_groups_fh = File::Temp->new(SUFFIX=>'.groups', DIR=>$self->alignment_directory);
    print $header_groups_fh $rg_tag;
    print $header_groups_fh $pg_tag;
    $header_groups_fh->close;

    #STEP 4.75:  Cat all together

    my $species;
    if ($instrument_data->id > 0) {
        $self->status_message("Sample id: ".$self->instrument_data->sample_id);
        my $sample = Genome::Sample->get($self->instrument_data->sample_id);
        $species =  $sample->species_name;
    }
    else {
        $species = 'Homo sapiens'; #to deal with solexa.t

    }
    $self->status_message("Species from alignment: ".$species);

    my $ref_build = $self->reference_build;
    my $seq_dict = $ref_build->get_sequence_dictionary("sam",$species,$self->picard_version);
    
    my $per_lane_sam_file = $self->alignment_directory."/tcga_compliant.sam";
    my $per_lane_bam_file = $self->alignment_directory."/tcga_compliant.bam";
    
    my @files_to_merge = ();
    for my $file ($seq_dict, $header_groups_fh->filename, $sam_map_output_fh->filename, $self->unaligned_reads_list_path) {
        if (-z $file) {
            $self->warning_message("$file is empty, will not be used to cat");
            next;
        }
        push @files_to_merge, $file;
    }

    $self->status_message("Cat-ing together: ".join("\n",@files_to_merge). "\n to output file ".$per_lane_sam_file);
    my $cat_rv = Genome::Utility::FileSystem->cat(input_files=>\@files_to_merge,output_file=>$per_lane_sam_file);
    if ($cat_rv ne 1) {
        $self->error_message("Error during cat of alignment sam files! Return value $cat_rv");
        die "Error cat-ing all alignment sam files together.  Return value: $cat_rv";
    } else {
        $self->status_message("Cat of sam files successful.");
    }

    my $per_lane_sam_file_rg = $self->alignment_directory."/tcga_compliant_rg.sam";
    
    my $add_rg_cmd = Genome::Model::Tools::Sam::AddReadGroupTag->create(input_file=>$per_lane_sam_file,
                                                              output_file=>$per_lane_sam_file_rg,
                                                              read_group_tag=>$id_tag,
                                                            );

    my $add_rg_cmd_rv = $add_rg_cmd->execute;
    
    if ($add_rg_cmd_rv ne 1) {
        $self->error_message("Adding read group to sam file failed! Return code: $add_rg_cmd_rv");
    } else {
        $self->status_message("Read group add completed.");
    }

    unlink($per_lane_sam_file);

    #STEP 4.85: Convert perl lane sam to Bam 

    my $to_bam = Genome::Model::Tools::Sam::SamToBam->create(
            bam_file => $per_lane_bam_file, 
            sam_file => $per_lane_sam_file_rg,                                                      
            keep_sam => 0,
            fix_mate => 1,
            index_bam => 0,
            use_version => $self->samtools_version,
    );
    my $rv_to_bam = $to_bam->execute();
    if ($rv_to_bam ne 1) { 
        $self->error_message("There was an error converting the Sam file $per_lane_sam_file to $per_lane_bam_file.  Return value was: $rv_to_bam");
        die "There was an error converting the Sam file $per_lane_sam_file to $per_lane_bam_file.  Return value was: $rv_to_bam";
    } else {
        $self->status_message("Conversion successful.");
    }
 
    #### if it got to here then we've got ourselves a good alignment, let's keep it!
    chmod 0644,$per_lane_bam_file;
    rename($per_lane_bam_file, $self->alignment_file);

    unless (-e $self->alignment_file && -s $self->alignment_file) {
	$self->error_message("Alignment output " . $self->alignment_file . " not found or zero length.  Something went wrong");
	return;
    }



    #### STEP 5: Concat all the log files into one

    my $log_input_fileset = join " ", map {$_->filename} (@aln_log_files, $samxe_logfile);
    my $log_output_file = $self->aligner_output_file_path;
    
    my $concat_log_cmd = sprintf('cat %s > %s',
				   $log_input_fileset,
				   $log_output_file);
    
    Genome::Utility::FileSystem->shellcmd(
            cmd          => $concat_log_cmd,
            input_files  => [ map {$_->filename} (@aln_log_files, $samxe_logfile 	) ],
            output_files => [ $log_output_file ],
            skip_if_output_is_present => 0,
	    );

    unless ($self->verify_aligner_successful_completion($self->aligner_output_file_path)) {
        $self->error_message('Failed to verify bwa successful completion from output file '. $self->aligner_output_file_path);
        $self->die_and_clean_up($self->error_message);
    }

    my $alignment_allocation = $self->get_allocation;

    if ($alignment_allocation) {
        unless ($alignment_allocation->reallocate) {
            $self->error_message('Failed to reallocate disk space for disk allocation: '. $alignment_allocation->id);
            $self->die_and_clean_up($self->error_message);
        }
    }
    
    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }

    $DB::single = 1;
    
    return 1;
}


sub _verify_bwa_aln_did_happen {
    my $self = shift;
    my %p = @_;

    unless (-e $p{sai_file} && -s $p{sai_file}) {
	$self->error_message("Expected SAI file is $p{sai_file} nonexistent or zero length.");
	return;
    }
    
    unless ($self->_inspect_log_file(log_file=>$p{log_file},
				     log_regex=>'(\d+) sequences have been processed')) {
	
	$self->error_message("Expected to see 'X sequences have been processed' in the log file where 'X' must be a nonzero number.");
	return 0;
    }
    
    return 1;
}

sub process_low_quality_alignments {
    my $self = shift;

    my $unaligned_reads_file = $self->unaligned_reads_list_path;
    my @unaligned_reads_files = $self->unaligned_reads_list_paths;

    my @paths;
    my $result;
    if (-s $unaligned_reads_file . '.fastq' && -s $unaligned_reads_file) {
        $self->status_message("SHORTCUTTING: ALREADY FOUND MY INPUT AND OUTPUT TO BE NONZERO");
        return 1;
    }
    elsif (-s $unaligned_reads_file) {
        if ($self->instrument_data->is_paired_end && !$self->force_fragment) {
            $result = Genome::Model::Tools::Bwa::UnalignedDataToFastq->execute(
                in => $unaligned_reads_file, 
                fastq => $unaligned_reads_file . '.1.fastq',
                reverse_fastq => $unaligned_reads_file . '.2.fastq'
            );
        }
        else {
            $result = Genome::Model::Tools::Bwa::UnalignedDataToFastq->execute(
                in => $unaligned_reads_file, 
                fastq => $unaligned_reads_file . '.fastq'
            );
        }
        unless ($result) {
            $self->die_and_clean_up("Failed Genome::Model::Tools::Bwa::UnalignedDataToFastq for $unaligned_reads_file");
        }
    }
    else {
        foreach my $unaligned_reads_files_entry (@unaligned_reads_files){
            if ($self->instrument_data->is_paired_end && !$self->force_fragment) {
                $result = Genome::Model::Tools::Bwa::UnalignedDataToFastq->execute(
                    in => $unaligned_reads_files_entry, 
                    fastq => $unaligned_reads_files_entry . '.1.fastq',
                    reverse_fastq => $unaligned_reads_files_entry . '.2.fastq'
                );
            }
            else {
                $result = Genome::Model::Tools::Bwa::UnalignedDataToFastq->execute(
                    in => $unaligned_reads_files_entry, 
                    fastq => $unaligned_reads_files_entry . '.fastq'
                );
            }
            unless ($result) {
                $self->die_and_clean_up("Failed Genome::Model::Tools::Bwa::UnalignedDataToFastq for $unaligned_reads_files_entry");
            }
        }
    }

    unless (-s $unaligned_reads_file || @unaligned_reads_files) {
        $self->error_message("Could not find any unaligned reads files.");
        return;
    }

    return 1;
}

sub _verify_bwa_samxe_did_happen {
    my $self = shift;
    my %p = @_;
    
    unless (-e $p{aligned_reads_file} && -e $p{unaligned_reads_file}) {
	$self->error_message("bwa samXe output incomplete.  Missing an aligned or unaligned reads file, or both");
	return;
    }
    
    if (!-s $p{aligned_reads_file} && !-s $p{unaligned_reads_file}) {
	$self->error_message("bwa samXe output is incorrect.  The aligned and unaligned reads files should not both be zero!");
	return;
    }
    
    unless ($self->_inspect_log_file(log_file=>$p{log_file},
				     log_regex=>'print alignments')) {
	$self->error_message("Did not find expected output in bwa samXe log file output");
	return;
    }
    
    return 1;
}

sub _inspect_log_file {
    my $self = shift;
    my %p = @_;

    my $aligner_output_fh = IO::File->new($p{log_file});
    unless ($aligner_output_fh) {
        $self->error_message("Can't open expected log file to verify completion " . $p{log_file} . "$!"
        );
        return;
    }
    
    my $check_nonzero = 0;
    
    my $log_regex = $p{log_regex};
    if ($log_regex =~ m/\(\\d\+\)/) {
	
	$check_nonzero = 1;
    }

    while (<$aligner_output_fh>) {
        if (m/$log_regex/) {
            $aligner_output_fh->close();
            if ( !$check_nonzero || $1 > 0 ) {
                return 1;
            }
            return;
        }
    }

    return;
}


