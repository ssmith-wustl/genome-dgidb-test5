package Genome::InstrumentData::Alignment::Maq;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Alignment::Maq {
    is => ['Genome::InstrumentData::Alignment'],
    has_constant => [
                     aligner_name => { value => 'maq' },
    ],
};

sub sanger_bfq_filenames {
    my $self = shift;

    my @sanger_bfq_pathnames;
    if ($self->{_sanger_bfq_pathnames}) {
        @sanger_bfq_pathnames = $self->{_sanger_bfq_pathnames};
        my $errors;
        for my $sanger_bfq (@sanger_bfq_pathnames) {
            unless (-e $sanger_bfq && -f $sanger_bfq && -s $sanger_bfq) {
                $self->error_message('Missing or zero size sanger bfq file: '. $sanger_bfq);
                $self->die_and_clean_up($self->error_message);
            }
        }
    } else {
        my @sanger_fastq_pathnames = $self->sanger_fastq_filenames;
        my $counter = 0;
        for my $sanger_fastq_pathname (@sanger_fastq_pathnames) {
            my $sanger_bfq_pathname = $self->create_temp_file_path('sanger-bfq-'. $counter++);
            unless (Genome::Model::Tools::Maq::Fastq2bfq->execute(
                                                                  fastq_file => $sanger_fastq_pathname,
                                                                  bfq_file => $sanger_bfq_pathname,
                                                              )) {
                $self->error_message('Failed to execute fastq2bfq quality conversion.');
                $self->die_and_clean_up($self->error_message);
            }
            unless (-e $sanger_bfq_pathname && -f $sanger_bfq_pathname && -s $sanger_bfq_pathname) {
                $self->error_message('Failed to validate the conversion of sanger fastq file '. $sanger_fastq_pathname .' to sanger bfq.');
                $self->die_and_clean_up($self->error_message);
            }
            push @sanger_bfq_pathnames, $sanger_bfq_pathname;
        }
        $self->{_sanger_bfq_pathnames} = \@sanger_bfq_pathnames;
    }
    return @sanger_bfq_pathnames;
}

sub get_alignment_statistics {
    my $self = shift;
    my $aligner_output_file = shift;
    unless ($aligner_output_file) {
        $aligner_output_file = $self->aligner_output_file_path;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }

    my $fh = IO::File->new($aligner_output_file);
    unless($fh) {
        $self->error_message("unable to open maq's alignment output file:  " . $aligner_output_file);
        return;
    }
    my @lines = $fh->getlines;
    $fh->close;

    my ($line_of_interest)=grep { /total, isPE, mapped, paired/ } @lines;
    unless ($line_of_interest) {
        $self->error_message('Aligner summary statistics line not found');
        return;
    }
    my ($comma_separated_metrics) = ($line_of_interest =~ m/= \((.*)\)/);
    my @values = split(/,\s*/,$comma_separated_metrics);

    my %hashy_hash_hash;
    $hashy_hash_hash{total}=$values[0];
    $hashy_hash_hash{isPE}=$values[1];
    $hashy_hash_hash{mapped}=$values[2];
    $hashy_hash_hash{paired}=$values[3];
    return \%hashy_hash_hash;
}


sub verify_aligner_successful_completion {
    my $self = shift;
    my $aligner_output_file = shift;
    
    my $instrument_data = $self->instrument_data;
    if ($instrument_data->is_paired_end) {
        my $stats = $self->get_alignment_statistics($aligner_output_file);
        unless ($stats) {
            return $self->_aligner_output_file_complete($aligner_output_file);
        }
        if ($self->force_fragment) {
            if ($$stats{'isPE'} != 0) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as fragment data according to aligner output '. $aligner_output_file);
                return;
            }
        }  else {
            if ($$stats{'isPE'} != 1) {
                $self->error_message('Paired-end instrument data '. $instrument_data->id .' was not aligned as paired end data according to aligner output '. $aligner_output_file);
                return;
            }
        }
    }
    return $self->_aligner_output_file_complete($aligner_output_file);
}

sub _aligner_output_file_complete {
    my $self = shift;
    my $aligner_output_file = shift;

    unless ($aligner_output_file) {
        $aligner_output_file = $self->aligner_output_file_path;
    }
    unless (-s $aligner_output_file) {
        $self->error_message("Aligner output file '$aligner_output_file' not found or zero size.");
        return;
    }
    my $aligner_output_fh = IO::File->new($aligner_output_file);
    unless ($aligner_output_fh) {
        $self->error_message("Can't open aligner output file $aligner_output_file: $!");
        return;
    }
    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
        if (m/\[match_index_sorted\] no reasonable reads are available. Exit!/) {
            $aligner_output_fh->close();
            return 2;
        }
    }
    return;
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
    return grep { -e $_ && $_ !~ /aligner_output/ && $_ !~ /mapview/ }
            glob($self->alignment_directory .'/*.map*');
}

sub alignment_bam_file_paths {
    my $self = shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    my @bam_files = grep { -e $_ && $_ !~ /merged_rmdup/} glob($self->alignment_directory .'/*.bam');
    
    if ( scalar(@bam_files) > 0 ) {
        $self->status_message("Found ".scalar(@bam_files)." BAM files.");
        return @bam_files;
    } 
    else {
        $self->status_message('No BAM files found.  Creating from MAP files.');
        my @map_files = $self->alignment_file_paths;
        
        if ( scalar(@map_files) > 0 ) {
            $self->status_message("Found ".scalar(@map_files)." MAP files.  Creating BAM files.");
            $self->status_message("map files:\n".join("\n",@map_files));
            
            my $ref_build = $self->reference_build;
            my $ref_list  = $ref_build->full_consensus_sam_index_path;
            unless ($ref_list) {
                $self->error_message("Failed to get MapToBam ref list: $ref_list");
                return;
            }
            
            my $error_count = 0;
            
            for my $map_file (@map_files) {
                if (-s $map_file) {
                    $self->status_message("Map file: $map_file exists. Converting to BAM.");
                } 
                else {
                    $self->error_message("Map file: $map_file DOES NOT EXIST. Returning."); 
                    return;
                }
                
                $self->status_message("Aligner version: ".$self->aligner_version);

                my $lib_name = $self->instrument_data->library_name;
                my $lib_tag  = defined $lib_name ? $lib_name : '';
                
                $self->status_message("library name/tag: $lib_tag");
                
                my $map_to_bam = Genome::Model::Tools::Maq::MapToBam->create(
                    map_file    => $map_file,
                    use_version => $self->aligner_version,
                    lib_tag     => $lib_tag,
                    ref_list    => $ref_list,
                    index_bam   => 0,
                );
                my $bam_file = $map_to_bam->bam_file_path;
                my $rv = $map_to_bam->execute;
                
                if ($rv == 1) {
                    $self->status_message("Conversion succeeded.");
                    
                    if (-e $bam_file) {
                        push @bam_files, $bam_file;
                    }
                    else {
                        $self->error_message("Somehow bam file: $bam_file not existing");
                        $error_count++;
                    }
                } 
                else {
                    $self->error_message("Error converting MAP file: $map_file to BAM file.  Return value: $rv");
                    $error_count++;
                }
            }
            if ($error_count == 0 ) {
                $self->status_message("All MAP files converted successfully to BAM files.");
                return @bam_files;
            } 
            else {
                $self->error_message("There were $error_count error(s) converting map files to bam files.");
            }  
        } 
        else {
            $self->error_message("No MAP files found.  Can't create BAM files.");
        }
        return;
    }
}

#a glob for subsequence alignment files
sub alignment_file_paths_for_subsequence_name {
    my $self = shift;
    my $subsequence_name = shift;
    unless (defined($subsequence_name)) {
        $self->error_message('No subsequence_name passed to method alignment_file_paths_for_subsequence_name.');
        return;
    }
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    my @files = grep { -e $_ && $_ !~ /aligner_output/ }
            glob($self->alignment_directory ."/${subsequence_name}.map*");
    return @files;

    # Now try the old format: $refseqid_{unique,duplicate}.map.$eventid
    #my $glob_pattern = sprintf('%s/%s_*.map.*', $alignment_dir, $ref_seq_id);
    #@files = grep { $_ and -e $_ } (
    #    glob($glob_pattern)
    #);
    #return @files;
}

#####ALIGNER OUTPUT#####
#a glob for existing aligner output files
sub aligner_output_file_paths {
    my $self=shift;
    return unless $self->alignment_directory;
    return unless -d $self->alignment_directory;
    return grep { -e $_ } glob($self->alignment_directory .'/*.map.aligner_output*');
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
    my $file = "/alignments_lane_${lane}.map.aligner_output";
    return $file;
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

sub verify_alignment_data {
    my $self = shift;

    my $alignment_dir = $self->alignment_directory;
    return unless $alignment_dir;
    return unless -d $alignment_dir;

    unless ( $self->arch_os =~ /64/ ) {
        die('Failed to verify_alignment_data.  Must run from 64-bit architecture.');
    }

    my $lock;
    unless ($self->_resource_lock) {
        $lock = $self->lock_alignment_resource;
    } else {
        $lock = $self->_resource_lock;
    }

    unless ($self->output_files) {
        $self->status_message('No output files found in alignment directory: '. $alignment_dir);
        return;
    }

    my $reference_build = $self->reference_build;
    my ($alignment_file) = $self->alignment_file_paths_for_subsequence_name('all_sequences');
    my $errors = 0;
    my $verified_no_reads = 0;
    unless ($alignment_file) {
        my @subsequence_names = grep { $_ ne 'all_sequences' } $reference_build->subreference_names(reference_extension => 'bfa');
        unless  (@subsequence_names) {
            @subsequence_names = 'all_sequences';
        }
        for my $subsequence_name (@subsequence_names) {
            ($alignment_file) = $self->alignment_file_paths_for_subsequence_name($subsequence_name);
            unless ($alignment_file) {
                my @possible_aligner_output_shortcuts = $self->aligner_output_file_paths;
                for my $possible_aligner_output_shortcut (@possible_aligner_output_shortcuts) {
                    my $found_aligner_output_file = $self->check_for_path_existence($possible_aligner_output_shortcut);
                    if (!$found_aligner_output_file) {
                        $self->error_message("Missing aligner output file '$possible_aligner_output_shortcut'.");
                        $errors++;
                    }
                    my $verify = $self->verify_aligner_successful_completion($possible_aligner_output_shortcut);
                    if ($verify == 2) {
                        $self->status_message('No reasonable reads are available');
                        $verified_no_reads = 1;
                    } else {
                        $errors++;
                        $self->error_message('No alignment file found for subsequence '. $subsequence_name .' in alignment directory '. $self->alignment_directory);
                    }
                }
            }
        }
    }
    unless ($verified_no_reads) {
        my $validate = Genome::Model::Tools::Maq::Mapvalidate->execute(
            map_file => $alignment_file,
            output_file => '/dev/null',
            use_version => $self->aligner_version,
        );
        unless ($validate) {
            $errors++;
            $self->error_message('Failed to run maq mapvalidate on alignment file: '. $alignment_file);
        }
        my @possible_unaligned_shortcuts= $self->unaligned_reads_list_paths;
        for my $possible_unaligned_shortcut (@possible_unaligned_shortcuts) {
            my $found_unaligned_reads_file = $self->check_for_path_existence($possible_unaligned_shortcut);
            if (!$found_unaligned_reads_file) {
                $self->error_message("Missing unaligned reads file '$possible_unaligned_shortcut'");
                $errors++;
            } elsif (!-s $possible_unaligned_shortcut) {
                $self->error_message("Unaligned reads file '$possible_unaligned_shortcut' found but zero size");
                $errors++;
            }
        }
        my @possible_aligner_output_shortcuts = $self->aligner_output_file_paths;
        for my $possible_aligner_output_shortcut (@possible_aligner_output_shortcuts) {
            my $found_aligner_output_file = $self->check_for_path_existence($possible_aligner_output_shortcut);
            if (!$found_aligner_output_file) {
                $self->error_message("Missing aligner output file '$possible_aligner_output_shortcut'.");
                $errors++;
            } elsif (!$self->verify_aligner_successful_completion($possible_aligner_output_shortcut)) {
                $errors++;
            }
        }
    }
    if ($errors) {
        my @output_files = $self->output_files;
        if (@output_files) {
            my $msg = 'REFUSING TO CONTINUE with files in place in alignment directory:' ."\n";
            $msg .= join("\n",@output_files) ."\n";
            $self->die_and_clean_up($msg);
        }
        return;
    }
    $self->status_message('Alignment data verified: '. $alignment_dir);

    unless ($self->unlock_alignment_resource) {
        $self->error_message('Failed to unlock alignment resource '. $lock);
        return;
    }
    return 1;
}

sub find_or_generate_alignment_data {
    my $self = shift;

    unless ($self->verify_alignment_data) {
        $self->_run_aligner();
    } else {
        $self->status_message("Existing alignment data is available and deemed correct.");
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
    my $instrument_data = $self->instrument_data;
    my $reference_build = $self->reference_build;
    my $alignment_directory = $self->alignment_directory;

    $self->status_message("OUTPUT PATH: $alignment_directory\n");
    my $is_paired_end;
    my $upper_bound_on_insert_size;
    my $median_insert;
    if ($instrument_data->is_paired_end && !$self->force_fragment) {
        my $sd_above = $instrument_data->sd_above_insert_size;
        $median_insert = $instrument_data->median_insert_size;
        $upper_bound_on_insert_size= ($sd_above * 5) + $median_insert;
        unless($upper_bound_on_insert_size > 0) {
            $self->status_message("Unable to calculate a valid insert size to run maq with. Using 600 (hax)");
            $upper_bound_on_insert_size= 600;
        }
        # TODO: extract additional details from the read set
        # about the insert size, and adjust the maq parameters.
        $is_paired_end = 1;
    }
    else {
        $is_paired_end = 0;
    }

    my $adaptor_file = $instrument_data->resolve_adaptor_file;
    unless ($adaptor_file) {
        $self->die_and_clean_up("Failed to resolve adaptor file!");
    }

    # these are general params not infered from the above
    my $aligner_params = $self->aligner_params;


    # we resolve these first, since we might just print the paths we work with then exit
    my @input_pathnames = $self->sanger_bfq_filenames;
    $self->status_message("SANGER BFQ PATHS: @input_pathnames\n");

    # prepare the refseq
    my $ref_seq_file =  $reference_build->full_consensus_path('bfa');
    unless ($ref_seq_file && -e $ref_seq_file) {
        $self->error_message("Reference build full consensus path '$ref_seq_file' does not exist.");
        $self->die_and_clean_up($self->error_message);
    }
    $self->status_message("REFSEQ PATH: $ref_seq_file\n");

    # input/output files
    my $alignment_file = $alignment_directory .'/all_sequences.map';


    # RESOLVE A STRING OF ALIGNMENT PARAMETERS
    if ($is_paired_end) {
        if ($median_insert < 1000){
		$aligner_params .= ' -a '. $upper_bound_on_insert_size;
		$self->status_message("Median insert size ($median_insert) less than 1000, setting -a");
	}
	elsif ($median_insert >= 1000){
		$aligner_params .= ' -A '. $upper_bound_on_insert_size;
		$self->status_message("Median insert size ($median_insert) greater than or equal to 1000, setting -A");
	}
	else {
	#in the future we need to make an intelligent decision about setting -a vs -A based on the intended insert size;
	#we should only be here in the case where gerald failed to calculate a median insert size
	# TODO: extract additional details from the read set (that is what the guy at line 477 thought)
	}
    }

    # TODO: this doesn't really work, so leave it out
    if ($adaptor_file) {
        $aligner_params .= ' -d '. $adaptor_file;
    }
    else {
        Carp::confess("No adaptor file?");
    }

    # prevent randomness!  seed the generator based on the flow cell not the clock
    my $seed = 0; 
    for my $c (split(//,$instrument_data->flow_cell_id || $self->instrument_data_id)) {
        $seed += ord($c)
    }
    $seed = $seed % 65536;
    $self->status_message("Seed for maq's random number generator is $seed.");
    $aligner_params .= " -s $seed ";

    # NOT SURE IF THIS IS USED BUT COULD BE IMPLEMENTED
    #if ( defined($self->duplicate_mismatch_file) ) {
    #    $duplicate_mismatch_option = '-H '.$self->duplicate_mismatch_file;
    #}

    my $files_to_align = join(' ',@input_pathnames);
    my $cmdline = Genome::Model::Tools::Maq->path_for_maq_version($self->aligner_version)
        . sprintf(' map %s -u %s %s %s %s > ',
                  $aligner_params,
                  $self->unaligned_reads_list_path,
                  $alignment_file,
                  $ref_seq_file,
                  $files_to_align)
            . $self->aligner_output_file_path . ' 2>&1';
    my @input_files = ($ref_seq_file, @input_pathnames);
    if ($adaptor_file) {
        push @input_files, $adaptor_file;
    }
    my @output_files = ($alignment_file, $self->unaligned_reads_list_path, $self->aligner_output_file_path);
    Genome::Utility::FileSystem->shellcmd(
                                          cmd                         => $cmdline,
                                          input_files                 => \@input_files,
                                          output_files                => \@output_files,
                                      );

    unless ($self->verify_aligner_successful_completion($self->aligner_output_file_path)) {
        $self->error_message('Failed to verify maq successful completion from output file '. $self->aligner_output_file_path);
        $self->die_and_clean_up($self->error_message);
    }

    # in some cases maq will "work" but not make an unaligned reads file
    # this happens when all reads are filtered out
    # make an empty file to represent our zero-item list of unaligned reads
    unless (-e $self->unaligned_reads_list_path) {
        if (my $fh = IO::File->new(">".$self->unaligned_reads_list_path)) {
            $self->status_message("Made empty unaligned reads file since that file is was not generated by maq.");
        } else {
            $self->error_message("Failed to make empty unaligned reads file!: $!");
        }
    }

    # TODO: Move this logic into a diff utility that performs the "sanitization"
    # make a sanitized version of the aligner output for comparisons
    my $output = $self->open_file_for_reading($self->aligner_output_file_path);
    my $clean = $self->open_file_for_writing($self->aligner_output_file_path . '.sanitized');
    while (my $row = $output->getline) {
        $row =~ s/\% processed in [\d\.]+/\% processed in N/;
        $row =~ s/CPU time: ([\d\.]+)/CPU time: N/;
        $clean->print($row);
    }
    $output->close;
    $clean->close;

    my @found = $self->alignment_file_paths_for_subsequence_name('all_sequences');
    unless (@found) {
        $self->error_message("Failed to find map file for all_sequences!");
        my @files = glob($alignment_directory . '/*');
        $self->error_message("Files in dir are:\n\t" . join("\n\t",@files) . "\n");
        $self->die_and_clean_up('Failed to find map files after alignment');
    }

    unless ($self->process_low_quality_alignments) {
        $self->error_message('Failed to process_low_quality_alignments');
        $self->die_and_clean_up($self->error_message);
    }

    $self->status_message('Converting map to bam after alignment.');
    my @bam_files = $self->alignment_bam_file_paths;
    unless (@bam_files) {
        $self->error_message('Could not convert MAP files to BAM files in directory '. $self->alignment_directory);
        $self->die_and_clean_up($self->error_message);
    }
    
    unless ($self->verify_alignment_data) {
        $self->error_message('Failed to verify existing alignment data in directory '. $self->alignment_directory);
        $self->die_and_clean_up($self->error_message);
    }
    $self->status_message('Finished aligning!');

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
            $result = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                in => $unaligned_reads_file, 
                fastq => $unaligned_reads_file . '.1.fastq',
                reverse_fastq => $unaligned_reads_file . '.2.fastq'
            );
        }
        else {
            $result = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                in => $unaligned_reads_file, 
                fastq => $unaligned_reads_file . '.fastq'
            );
        }
        unless ($result) {
            $self->die_and_clean_up("Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_file");
        }
    }
    else {
        foreach my $unaligned_reads_files_entry (@unaligned_reads_files){
            if ($self->_alignment->instrument_data->is_paired_end && !$self->force_fragment) {
                $result = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                    in => $unaligned_reads_files_entry, 
                    fastq => $unaligned_reads_files_entry . '.1.fastq',
                    reverse_fastq => $unaligned_reads_files_entry . '.2.fastq'
                );
            }
            else {
                $result = Genome::Model::Tools::Maq::UnalignedDataToFastq->execute(
                    in => $unaligned_reads_files_entry, 
                    fastq => $unaligned_reads_files_entry . '.fastq'
                );
            }
            unless ($result) {
                $self->die_and_clean_up("Failed Genome::Model::Tools::Maq::UnalignedDataToFastq for $unaligned_reads_files_entry");
            }
        }
    }

    unless (-s $unaligned_reads_file || @unaligned_reads_files) {
        $self->error_message("Could not find any unaligned reads files.");
        return;
    }

    return 1;
}



1;
