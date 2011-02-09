package Genome::InstrumentData::AlignmentResult;

use Genome;
use Genome::Info::BamFlagstat;
use Data::Dumper;
use Sys::Hostname;
use IO::File;
use File::Path;
use YAML;
use Time::HiRes;
use POSIX qw(ceil);
use File::Copy;

use warnings;
use strict;


our $BAM_FH;

class Genome::InstrumentData::AlignmentResult {
    is_abstract => 1,
    is=>['Genome::SoftwareResult'],
    sub_classification_method_name => '_resolve_subclass_name',   
    has => [
        instrument_data         => {
                                    is => 'Genome::InstrumentData',
                                    id_by => 'instrument_data_id'
                                },
        reference_build         => {
                                    is => 'Genome::Model::Build::ImportedReferenceSequence',
                                    id_by => 'reference_build_id',
                                },
        reference_name          => { via => 'reference_build', to => 'name', is_mutable => 0, is_optional => 1 },

        aligner                 => { 
                                    calculate_from => [qw/aligner_name aligner_version aligner_params/], 
                                    calculate => q|no warnings; "$aligner_name $aligner_version $aligner_params"| 
                                },
        
        trimmer                 => { 
                                    calculate_from => [qw/trimmer_name trimmer_version trimmer_params/], 
                                    calculate => q|no warnings; "$trimmer_name $trimmer_version $trimmer_params"| 
                                },

        filter                 => { 
                                    calculate_from => [qw/filter_name filter_params force_fragment/], 
                                    calculate => q|no warnings; "$filter_name $filter_params $force_fragment"| 
                                },

        _disk_allocation        => { is => 'Genome::Disk::Allocation', is_optional => 1, is_many => 1, reverse_as => 'owner' },

    ],
    has_input => [
        instrument_data_id      => {
                                    is => 'Number',
                                    doc => 'the local database id of the instrument data (reads) to align',
                                },
        instrument_data_segment_type => {
                                    is => 'String',
                                    doc => 'Type of instrument data segment to limit within the instrument data being aligned (e.g. "read_group")',
                                    is_optional => 1,
        },
        instrument_data_segment_id => {
                                    is => 'String',
                                    doc => 'Identifier for instrument data segment to limit within the instrument data being aligned (e.g. read group ID)',
                                    is_optional => 1,
        },
        reference_build_id      => {
                                    is => 'Number',
                                    doc => 'the reference to use by id',
                                },
    ],
    has_param => [
        test_name               => {
                                    is=>'Text',
                                    is_optional=>1,
                                    doc=>'Assigns a testing tag to the alignments.  These will not be used in pipelines.',
                                },
        aligner_name            => {
                                    is => 'Text', default_value => 'maq',
                                    doc => 'the name of the aligner to use, maq, blat, newbler etc.',
                                },
        aligner_version         => {
                                    is => 'Text',
                                    doc => 'the version of the aligner to use, i.e. 0.6.8, 0.7.1, etc.',
                                    is_optional=>1,
                                },
        aligner_params          => {
                                    is => 'Text',
                                    is_optional=>1,
                                    doc => 'any additional params for the aligner in a single string',
                                },
        force_fragment          => {
                                    is => 'Boolean',    
                                    is_optional=>1,
                                    doc => 'Force this run to be treated as a fragment run, do not do pairing',
                                },
        filter_name             => {
                                    is => 'Text',
                                    doc => 'Filter strategy to use',
                                    is_optional=>1,
                                },
        filter_params           => {
                                    is => 'Text',
                                    doc => 'Filter params to use',
                                    is_optional=>1,
                                },
        trimmer_name            => {
                                    is => 'Text',
                                    doc => 'Trimmer strategy to use',
                                    is_optional=>1,
                                },
        trimmer_version         => {
                                    is => 'Text',
                                    doc => 'Trimmer version to use',
                                    is_optional=>1,
                                },
        trimmer_params          => {
                                    is => 'Text',
                                    is_optional=>1,
                                    doc => 'Trimmer parameters',
                                },
        samtools_version        => {
                                    is=>'Text',
                                    is_optional=>1,
                                    doc=>'Version of samtools to use when creating BAM files',
                                },
        picard_version          => {
                                    is=>'Text',
                                    is_optional=>1,
                                    doc=>'Version of picard to use when creating bam files',
                                },
        n_remove_threshold      => {
                                    is => 'Number',
                                    is_optional=>1,
                                    doc=>'If set, strips reads containing runs of this many Ns'
                                }
    ],
    has_metric => [
        cigar_md_error_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                        doc=>'The number of alignments with CIGAR / MD strings that failed to be parsed completely.'
                                },
        total_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_aligned_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_aligned_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_unaligned_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_unaligned_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_duplicate_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_duplicate_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_inserted_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_deleted_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_hard_clipped_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_hard_clipped_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_soft_clipped_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        total_soft_clipped_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        paired_end_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        paired_end_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        read_1_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        read_1_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        read_2_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        read_2_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        mapped_paired_end_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        mapped_paired_end_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        proper_paired_end_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        proper_paired_end_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        singleton_read_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
        singleton_base_count => {
                                        is=>'Number',
                                        is_optional=>1,
                                },
    ],
    has_transient => [
        temp_staging_directory  => {
                                    is => 'Text',
                                    doc => 'A directory to use for staging the alignment data before putting it on allocated disk.',
                                    is_optional=>1,
                                },
        temp_scratch_directory  => {
                                    is=>'Text',
                                    doc=>'Temp scratch directory',
                                    is_optional=>1,
                                },
        _input_fastq_pathnames => { is => 'ARRAY', is_optional => 1 },
        _input_bfq_pathnames   => { is => 'ARRAY', is_optional => 1 },
        _fastq_read_count      => { is => 'Number',is_optional => 1 },
        _bam_output_fh         => { is => 'IO::File',is_optional => 1 },
    ],
};

sub required_arch_os {
    # override in subclasses if 64-bit is not required
    'x86_64' 
}

sub required_rusage { 
    # override in subclasses
    # e.x.: "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=50000:mem=12000]' -M 1610612736";
    ''
}

sub extra_metrics {
    # this will probably go away: override in subclasses if the aligner has custom metrics
    ()
}

sub _resolve_subclass_name {
    my $class = shift;

    if (ref($_[0]) and $_[0]->isa(__PACKAGE__)) {
        my $aligner_name = $_[0]->aligner_name;
        return join('::', 'Genome::InstrumentData::AlignmentResult', $class->_resolve_subclass_name_for_aligner_name($aligner_name));
    }
    elsif (my $aligner_name = $class->get_rule_for_params(@_)->specified_value_for_property_name('aligner_name')) {
        return join('::', 'Genome::InstrumentData::AlignmentResult', $class->_resolve_subclass_name_for_aligner_name($aligner_name));
    }
    return;
}

sub _resolve_subclass_name_for_aligner_name {
    my ($class,$aligner_name) = @_;
    my @type_parts = split(' ',$aligner_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    return $subclass;
}

sub create { 
    my $class = shift;
    
    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        # this class is abstract, and the super-class re-calls the constructor from the correct subclass
        return $class->SUPER::create(@_);
    }

    # STEP 1: verify the architecture on which we're running
    my $actual_os = Genome::Config->arch_os();
    $class->status_message("OS is $actual_os");
    my $required_os = $class->required_arch_os;
    $class->status_message("Required OS is $required_os");
    unless ($required_os eq $actual_os) {
        die $class->error_message("This logic can only be run on a $required_os machine!  (running on $actual_os)");
    }

    # STEP 2: the base class handles all locking, etc., so it may hang while waiting for a lock
    my $self = $class->SUPER::create(@_);
    return unless $self;

    if (my $output_dir = $self->output_dir) {
        if (-d $output_dir) {
            $self->status_message("BACKFILL DIRECTORY: $output_dir!");
            return $self;
        }
    }

    # STEP 3: ENSURE WE WILL PROBABLY HAVE DISK SPACE WHEN ALIGNMENT COMPLETES
    # TODO: move disk_group, estimated_size, allocation and promotion up into the software result logic
    my $estimated_kb_usage = $self->estimated_kb_usage;
    $self->status_message("Estimated disk for this data set: " . $estimated_kb_usage . " kb");
    $self->status_message("Check for available disk...");
    my @available_volumes = Genome::Disk::Volume->get(disk_group_names => "info_alignments"); 
    $self->status_message("Found " . scalar(@available_volumes) . " disk volumes");
    my $unallocated_kb = 0;
    for my $volume (@available_volumes) {
        $unallocated_kb += $volume->unallocated_kb;
    }
    $self->status_message("Available disk: " . $unallocated_kb . " kb");
    my $factor = 20;
    unless ($unallocated_kb > ($factor * $estimated_kb_usage)) {
        $self->error_message("NOT ENOUGH DISK SPACE!  This step requires $factor x as much disk as the job will use to be available before starting.");
        die $self->error_message();
    }

    # STEP 4: PREPARE THE STAGING DIRECTORY
    $self->status_message("Prepare working directories...");
    $self->_prepare_working_directories;
    $self->status_message("Staging path is " . $self->temp_staging_directory);
    $self->status_message("Working path is " . $self->temp_scratch_directory);

    # STEP 5: PREPARE REFERENCE SEQUENCES
    $self->status_message("Preparing the reference sequences...");
    unless($self->_prepare_reference_sequences) {
        $self->error_message("Reference sequences are invalid.  We can't proceed:  " . $self->error_message);
        die $self->error_message();
    }

    eval {
    
        # STEP 6: PREPARE THE ALIGNMENT FILE (groups file, sequence dictionary)
        # this also prepares the bam output pipe and crams the alignment headers through it.
        $self->status_message("Preparing the all_sequences.sam in scratch");
        unless ($self->prepare_scratch_sam_file) {
            $self->error_message("Failed to prepare the scratch sam file with groups and sequence dictionary");
            die $self->error_message;
        }

        # STEP 7: RUN THE ALIGNER
        $self->status_message("Running aligner...");
        unless ($self->collect_inputs_and_run_aligner ) {
            $self->error_message("Failed to collect inputs and/or run the aligner!");
            die $self->error_message;
        }

        # STEP 8: CREATE BAM IN STAGING DIRECTORY
        if ($self->supports_streaming_to_bam) {
            $self->close_out_streamed_bam_file;
        } else {
            $self->status_message("Constructing a BAM file (if necessary)...");
            unless( $self->create_BAM_in_staging_directory()) {
                $self->error_message("Call to create_BAM_in_staging_directory failed.\n");
                die $self->error_message;
            }
        }
    };

    if ($@) {
        my $error = $@;
        $self->status_message("Oh no!  Caught an exception while in the critical point where the BAM pipe was open: $@");
        if (defined $self->_bam_output_fh) {
            eval {
                $self->_bam_output_fh->close;
            };
            if ($@) {
                $error .= " ... and the input filehandle failed to close due to $@";
            }
        }
    
        die $error;
    }

    # STEP 9-10, validate BAM file (if necessary)
    $self->status_message("Postprocessing & Sanity Checking BAM file (if necessary)...");
    unless ($self->postprocess_bam_file()) {
        $self->error_message("Postprocess BAM file failed");
        die $self->error_message;
    }

    # STEP 11: COMPUTE ALIGNMENT METRICS
    $self->status_message("Computing alignment metrics...");
    $self->_compute_alignment_metrics();

    # STEP 12: PREPARE THE ALIGNMENT DIRECTORY ON NETWORK DISK
    $self->status_message("Preparing the output directory...");
    $self->status_message("Staging disk usage is " . $self->_staging_disk_usage . " KB");
    my $output_dir = $self->output_dir || $self->_prepare_alignment_directory;
    $self->status_message("Alignment output path is $output_dir");

    # STEP 13: PROMOTE THE DATA INTO ALIGNMENT DIRECTORY
    $self->status_message("Moving results to network disk...");
    my $product_path;
    unless($product_path= $self->_promote_validated_data) {
        $self->error_message("Failed to de-stage data into alignment directory " . $self->error_message);
        die $self->error_message;
    }
    
    # STEP 14: RESIZE THE DISK
    # TODO: move this into the actual original allocation so we don't need to do this 
    $self->status_message("Resizing the disk allocation...");
    if ($self->_disk_allocation) {
        unless ($self->_disk_allocation->reallocate) {
            $self->warning_message("Failed to reallocate my disk allocation: " . $self->_disk_allocation->id);
        }
    }
        
    $self->status_message("Alignment complete.");
    return $self;
}

sub prepare_scratch_sam_file {
    my $self = shift;
    
    my $scratch_sam_file = $self->temp_scratch_directory . "/all_sequences.sam";
    
    unless($self->construct_groups_file) {
        $self->error_message("failed to create groups file");
        die $self->error_message;
    }

    my $groups_input_file = $self->temp_scratch_directory . "/groups.sam";
    
    my $seq_dict = $self->get_or_create_sequence_dictionary();
    unless (-s $seq_dict) {
        $self->error_message("Failed to get sequence dictionary");
        die $self->error_message;
    }
    
    my @input_files = ($seq_dict, $groups_input_file);

    $self->status_message("Cat-ing together: ".join("\n",@input_files). "\n to output file ".$scratch_sam_file);
    my $cat_rv = Genome::Sys->cat(input_files=>\@input_files,output_file=>$scratch_sam_file);
    if ($cat_rv ne 1) {
        $self->error_message("Error during cat of alignment sam files! Return value $cat_rv");
        die $self->error_message;
    }
    else {
        $self->status_message("Cat of sam files successful.");
    }
    
    if ($self->supports_streaming_to_bam) {
        my $ref_list  = $self->reference_build->full_consensus_sam_index_path($self->samtools_version);
        my $sam_cmd = sprintf("| %s view -S -b -o %s - ", Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version), $self->temp_scratch_directory . "/raw_all_sequences.bam");
        $self->status_message("Opening $sam_cmd");

        $self->_bam_output_fh(IO::File->new($sam_cmd));
        unless ($self->_bam_output_fh()) {
            $self->error_message("We support streaming for this alignment module, but can't open a pipe to $sam_cmd");
            die $self->error_message;
        }

        my $temp_fh = IO::File->new($scratch_sam_file);
        unless ($temp_fh) {
            $self->error_message("Can't open temp sam header for reading.");
            die $self->error_message;
        }

        binmode $temp_fh;
        while (my $line = <$temp_fh>) {
            $self->_bam_output_fh->print($line);
        }


    }
    
    
    return 1;
}

sub requires_fastqs_to_align {
    my $self = shift;
   
    # n-remove, complex filters, trimmers, and chunked instrument data disqualify bam processing 
    return 1 if ($self->n_remove_threshold);
    return 1 if ($self->filter_name && ($self->filter_name ne 'forward-only' && $self->filter_name ne 'reverse-only'));
    return 1 if ($self->trimmer_name);
    return 1 if ($self->instrument_data_segment_id);
   
    # obviously we need fastq if we don't have a bam 
    return 1 unless (defined $self->instrument_data->bam_path && -e $self->instrument_data->bam_path);

    # disqualify if the aligner can't take a bam
    return 1 unless ($self->accepts_bam_input);
    
    return 0;
}

sub collect_inputs_and_run_aligner {
    my $self = shift;
    
    # STEP 6: UNPACK THE ALIGNMENT FILES
    $self->status_message("Unpacking reads...");
    
    my @inputs;
    
    if ($self->requires_fastqs_to_align) {
        @inputs = $self->_extract_input_fastq_filenames;    
    } else {
        if ($self->instrument_data->is_paired_end) {
            push @inputs, $self->instrument_data->bam_path . ":1";
            push @inputs, $self->instrument_data->bam_path . ":2";
        } else {
            push @inputs, $self->instrument_data->bam_path . ":0";
        }
    }
    
    unless (@inputs) {
        $self->error_message("Failed to gather fastq files: " . $self->error_message);
        die $self->error_message;
    }
    $self->status_message("Got " . scalar(@inputs) . " fastq files");
    if (@inputs > 3) {
        $self->error_message("We don't support aligning with more than 3 inputs (the first 2 are treated as PE and last 1 is treated as SE)");
        die $self->error_message;
    }

    # Perform N-removal if requested

    if ($self->n_remove_threshold) {
        $self->status_message("Running N-remove.  Threshold is " . $self->n_remove_threshold);

        my @n_removed_fastqs;

        for my $input_pathname (@inputs) {
            my $n_removed_file = $input_pathname . ".n-removed.fastq";
            my $n_remove_cmd = Genome::Model::Tools::Fastq::RemoveN->create(n_removed_file=>$n_removed_file, n_removal_threshold=>$self->n_remove_threshold, fastq_file=>$input_pathname); 
            unless ($n_remove_cmd->execute) {
                $self->error_message("Error running RemoveN: " . $n_remove_cmd->error_message);
                die $self->error_message;
            }
           
            my $passed = $n_remove_cmd->passed_read_count();
            my $failed = $n_remove_cmd->failed_read_count();
            $self->status_message("N removal complete: Passed $passed reads & Failed $failed reads");
            if ($passed > 0) { 
                push @n_removed_fastqs, $n_removed_file;
            }
            
            if ($input_pathname =~ m/^\/tmp/) {
                $self->status_message("Removing original file before N removal to save space: $input_pathname");
                unlink($input_pathname);
            }
        }
        if (@inputs == 1 && @n_removed_fastqs == 2) {
            $self->status_message("NOTE: An entire side of the read pairs was filtered away after n-removal.  We'll be running in SE mode from here on out.");
        }

        if (@inputs == 0) {
            $self->error_message("All reads were filtered away after n-removal.  Nothing to do here, bailing out.");
            die $self->error_message;
        }
        
        @inputs = @n_removed_fastqs;
    }

    # STEP 7: DETERMINE HOW MANY PASSES OF ALIGNMENT ARE REQUIRED
    my @passes;
    if (
        defined($self->filter_name) 
        and (
            $self->filter_name eq 'forward-only' 
            or $self->filter_name eq 'reverse-only'
        )
    ) {
        my $filter_name = $self->filter_name;
        if (@inputs == 3) {
            die "cannot handle PE and SE data together with $filter_name only data"
        }
        elsif ($filter_name eq 'forward-only') {
            @passes = ( [ shift @inputs ] );
        }
        elsif ($filter_name eq 'reverse-only') {
            @passes = ( [ pop @inputs ] );
        }
        $self->status_message("Running the aligner with the $filter_name filter.");
    }
    elsif ($self->force_fragment) {
        $self->status_message("Running the aligner in force-fragment mode.");
        @passes = map { [ $_ ] } @inputs; 
    }
    elsif (@inputs == 3) {
        $self->status_message("Running aligner twice: once for PE & once for SE");
        @passes = ( [ $inputs[0], $inputs[1] ], [ $inputs[2] ] );
    }
    elsif (@inputs == 2) {
        $self->status_message("Running aligner in PE mode");
        @passes = ( \@inputs ); 
    }
    elsif (@inputs == 1) {
        $self->status_message("Running aligner in SE mode");
        @passes = ( \@inputs ); 
    }

    # STEP 8: RUN THE ALIGNER, APPEND TO all_sequences.sam IN SCRATCH DIRECTORY
    my $fastq_rd_ct = 0;
    
  
    if ($self->requires_fastqs_to_align) {
    
        for my $pass (@passes) {
            for my $file (@$pass) {
                my $line = `wc -l $file`;
                my ($wc_ct) = $line =~ /^(\d+)\s/;
                unless ($wc_ct) {
                    $self->error_message("Fail to count reads in FASTQ file: $file");
                    return;
                }
                if ($wc_ct % 4) {
                    $self->warning_message("run has a line count of $wc_ct, which is not divisible by four!");
                }
                $fastq_rd_ct += $wc_ct/4;
            }
        }
    } else {
        $fastq_rd_ct = $self->determine_input_read_count_from_bam;       
    }
    unless ($fastq_rd_ct) {
        $self->error_message("Failed to get a read count before aligning.");
        return;
    }
        

    for my $pass (@passes) {
        $self->status_message("Aligning @$pass...");
        unless ($self->_run_aligner_chunked(@$pass)) {
            if (@$pass == 2) {
                $self->error_message("Failed to run aligner on first PE pass");
                die $self->error_message;
            }
            elsif (@$pass == 1) {
                $self->error_message("Failed to run aligner on final SE pass");
                die $self->error_message;
            }
            else {
                $self->error_message("Failed to run aligner on odd number of passes??");
                die $self->error_message;
            }
        }
    }

    unless ($fastq_rd_ct) {
        $self->error_message('Unable to count reads in FASTQ files');
        return;
    }

    $self->_fastq_read_count($fastq_rd_ct);

    for (@inputs) {
       if ($_ =~ m/^\/tmp\/.*\.fastq$/) {
        $self->status_message("Unlinking fastq file to save space now that we've aligned: $_");
       } 
    }

    return 1;
}

sub determine_input_read_count_from_bam {
    my $self = shift;
    
    
    my $bam_file = $self->instrument_data->bam_path;
    my $output_file = $self->temp_scratch_directory . "/input_bam.flagstat";
    
    my $cmd = Genome::Model::Tools::Sam::Flagstat->create(
        bam_file       => $bam_file,
        output_file    => $output_file,
        include_stderr => 1,
    );
    
    unless ($cmd and $cmd->execute) {
        $self->error_message('Failed to create or execute flagstat command.');
        return;
    }
    
    my $stats = Genome::Info::BamFlagstat->get_data($output_file);
    
    unless($stats) {
        $self->status_message('Failed to get flagstat data  on input sequences from '.$output_file);
        return;
    }
    
    my $total_reads = 0;
    
    if ($self->filter_name) {
        my $filter_name = $self->filter_name;
        
        if ($filter_name eq 'forward-only') {
            $total_reads += $stats->{reads_marked_as_read1};
        } elsif ($filter_name eq 'reverse-only') {
            $total_reads += $stats->{reads_marked_as_read2};
        } else {
            $self->error_message("don't know how to handle $filter_name when counting reads in the bam.");
        }
    } else {
        $total_reads += $stats->{total_reads};
    }
    
    return $total_reads;
}



sub close_out_streamed_bam_file {
    my $self = shift;
    $self->status_message("Closing bam file...");
    $self->_bam_output_fh->flush;
    $self->_bam_output_fh->close;
    $self->_bam_output_fh(undef);

    $self->status_message("Sorting by name to do fixmate...");
    my $bam_file = $self->temp_scratch_directory . "/raw_all_sequences.bam";
    my $final_bam_file = $self->temp_staging_directory . "/all_sequences.bam";
    my $samtools = Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version);

    my $tmp_file = $bam_file.'.sort';
    #402653184 bytes = 3 Gb 
    my $rv = system "$samtools sort -n -m 402653184 $bam_file $tmp_file";
    $self->error_message("Sort by name failed") and return if $rv or !-s $tmp_file.'.bam';

    $self->status_message("Now running fixmate");
    $rv = system "$samtools fixmate $tmp_file.bam $tmp_file.fixmate";
    $self->error_message("fixmate failed") and return if $rv or !-s $tmp_file.'.fixmate';
    unlink "$tmp_file.bam";

    $self->status_message("Now putting things back in chr/pos order");
    $rv = system "$samtools sort -m 402653184 $tmp_file.fixmate $tmp_file.fix";
    $self->error_message("Sort by position failed") and return if $rv or !-s $tmp_file.'.fix.bam';
    
    unlink "$tmp_file.fixmate";
    unlink $bam_file;

    move "$tmp_file.fix.bam", $final_bam_file;
    return 1;
}

sub create_BAM_in_staging_directory {
    my $self = shift;
    # STEP 9: CONVERT THE ALL_SEQUENCES.SAM into ALL_SEQUENCES.BAM
    unless($self->_process_sam_files) {
        $self->error_message("Failed to process sam files into bam files. " . $self->error_message);
        die $self->error_message;
    }

    return 1;
}

sub postprocess_bam_file {
    my $self = shift;
    
    #STEPS 8:  CREATE BAM.FLAGSTAT
    $self->status_message("Creating all_sequences.bam.flagstat ...");
    unless ($self->_create_bam_flagstat) {
        $self->error_message('Fail to create bam flagstat');
        die $self->error_message;
    }

    #STEPS 9: VERIFY BAM IS NOT TRUNCATED BY FLAGSTAT
    $self->status_message("Verifying the bam...");
    unless ($self->_verify_bam) {
        $self->error_message('Fail to verify the bam');
        die $self->error_message;
    }
    
    #request by RT#62311 for submission and data integrity
    $self->status_message('Creating all_sequences.bam.md5 ...');
    unless ($self->_create_bam_md5) {
        $self->error_message('Fail to create bam md5');
        die $self->error_message;
    }
    return 1;
}

sub _run_aligner_chunked {
    my $self = shift;

    unless ($self->can('input_chunk_size')) {
        return $self->_run_aligner(@_);
    }

    my @reads = @_;

    if (@reads > 2 || @reads == 0) {
        $self->error_message("Chunker can only accept one or two read sets, but it got " . scalar @reads . ". aborting");
        die $self->error_message;
    }

    my $chunk_size = $self->input_chunk_size;

    $self->status_message("Running in chunked mode.  Each pass will be in $chunk_size read chunks.");
    if (@reads == 2) {
        $chunk_size = ceil($chunk_size/2);
        $self->status_message("Chunking paired end reads.  Taking $chunk_size per pass.");
    }
    
    
    my @read_fhs;
    for my $read (@reads) {
        my $fh = IO::File->new("<" . $read);
        unless ($fh) {
            $self->error_message("Failed to open read file $read for chunking");
            die $self->error_message;
        }
        push @read_fhs, $fh;
    }

    my $successful_passes = 0;

    while(1) {
        my @chunks;
        my $cnt = 0;
        
        for my $i (0..$#read_fhs) {
            my $lines_read = 0;
            my $in_fh = $read_fhs[$i];
            my $chunk_path = Genome::Sys->base_temp_directory . "/chunked-read-" . $i . ".fastq";
            $self->status_message("Prepping chunk: $chunk_path");
            my $chunk_fh = IO::File->new(">" . $chunk_path);
            unless($chunk_fh) {
                $self->error_message("Failed to open for writing the chunked read file: $chunk_path ...  Aborting");
                die $self->error_message;
            }
            push @chunks, $chunk_path;
            while (my $row = <$in_fh>) { 
                print $chunk_fh $row; 
                $lines_read++; 
                $cnt++;

                # stop when we hit chunk size
                last if ($lines_read >= ($chunk_size*4));
            }
            $chunk_fh->close;
            if ($lines_read %4 != 0) {
                $self->error_message("Failed to read lines in multiples of 4, is the input file truncated?");
                die $self->error_message;
            }
            $self->status_message("Read " . $lines_read/4 . " reads for file $chunk_path");

        }

        # If we're done reading, return if we successfully aligned anything in previous passes
        # This covers the case where we happened to read up to the very end of the file and stopped without getting an EOF
        # that is, the file is an exact multiple of the chunk size
        if ($cnt == 0) {
            return ($successful_passes > 0);
        }

        my @remaining_fhs = grep {!eof $_} @read_fhs;
        print scalar(@remaining_fhs) .  " is the remaining set\n";
        if (@remaining_fhs > 0 && @remaining_fhs < @reads) {
            $self->error_message("It looks like the read files are not the same length.  We've exhausted one but not the other.");
            die $self->error_message;
        }

        my $start_time = [Time::HiRes::gettimeofday()];
        $self->status_message("Beginning alignment of " . $cnt/4 . " reads");
        my $res = $self->_run_aligner(@chunks);
        if (!$res) {
            $self->error_message("Failed to run aligner!");
            die $self->error_message;
        }
        my ($user, $system, $child_user, $child_system) = times;
        $self->status_message("wall clock time was ". Time::HiRes::tv_interval($start_time). "\n".
        "user time for $$ was $user\n".
        "system time for $$ was $system\n".
        "user time for all children was $child_user\n".
        "system time for all children was $child_system\n");
        $successful_passes++;
        for (@chunks) {
            unlink($_);
        }

        # if we hit the EOF in this pass, then stop
        if (@remaining_fhs == 0) {
            $self->status_message("Done chunking and aligning read chunks.");
            last;
        }
    }

    1;
}


sub _compute_alignment_metrics {
    my $self = shift;
    my $bam = $self->temp_staging_directory . "/all_sequences.bam";
    my $out = `bash -c "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/gsc/var/tmp/genome/lib:/gsc/pkg/boost/boost_1_42_0/lib /gsc/var/tmp/genome/bin/alignment-summary-v1.2.6 --bam=\"$bam\" --ignore-cigar-md-errors"`;
    unless ($? == 0) {
        $self->error_message("Failed to compute alignment metrics.");
        die $self->error_message;
    }
    my $res = YAML::Load($out);
    unless (ref($res) eq "HASH") {
        $self->error_message("Failed to parse YAML hash from alignment_summary_cpp output.");
        die $self->error_message;
    }
    # ehvatum TODO: stop using samtools flagstat to detect truncation
#   $self->alignment_file_truncated     ($res->{truncated});
    $self->cigar_md_error_count         ($res->{cigar_md_error});
    $self->total_read_count             ($res->{total});
    $self->total_base_count             ($res->{total_bp});
    $self->total_aligned_read_count     ($res->{total_aligned});
    $self->total_aligned_base_count     ($res->{total_aligned_bp});
    $self->total_unaligned_read_count   ($res->{total_unaligned});
    $self->total_unaligned_base_count   ($res->{total_unaligned_bp});
    $self->total_duplicate_read_count   ($res->{total_duplicate});
    $self->total_duplicate_base_count   ($res->{total_duplicate_bp});
    $self->total_inserted_base_count    ($res->{total_inserted_bp});
    $self->total_deleted_base_count     ($res->{total_deleted_bp});
    $self->total_hard_clipped_read_count($res->{total_hard_clipped});
    $self->total_hard_clipped_base_count($res->{total_hard_clipped_bp});
    $self->total_soft_clipped_read_count($res->{total_soft_clipped});
    $self->total_soft_clipped_base_count($res->{total_soft_clipped_bp});
    $self->paired_end_read_count        ($res->{paired_end});
    $self->paired_end_base_count        ($res->{paired_end_bp});
    $self->read_1_count                 ($res->{read_1});
    $self->read_1_base_count            ($res->{read_1_bp});
    $self->read_2_count                 ($res->{read_2});
    $self->read_2_base_count            ($res->{read_2_bp});
    $self->mapped_paired_end_read_count ($res->{mapped_paired_end});
    $self->mapped_paired_end_base_count ($res->{mapped_paired_end_bp});
    $self->proper_paired_end_read_count ($res->{proper_paired_end});
    $self->proper_paired_end_base_count ($res->{proper_paired_end_bp});
    $self->singleton_read_count         ($res->{singleton});
    $self->singleton_base_count         ($res->{singleton_bp});
    return;
}


sub alignment_directory {
    # TODO: refactor to just use output_dir.
    my $self = shift;
    return $self->output_dir;
}


sub _create_bam_flagstat {
    my $self = shift;
    
    my $bam_file    = $self->temp_staging_directory . '/all_sequences.bam'; 
    my $output_file = $bam_file . '.flagstat';

    unless (-s $bam_file) {
        $self->error_message('BAM file ' . $bam_file . ' does not exist or is empty');
        return;
    }

    if (-e $output_file) {
        $self->warning_message('Flagstat file '.$output_file.' exists. Now overwrite');
        unlink $output_file;
    }

    my $cmd = Genome::Model::Tools::Sam::Flagstat->create(
        bam_file       => $bam_file,
        output_file    => $output_file,
        include_stderr => 1,
    );

    unless ($cmd and $cmd->execute) {
        $self->error_message('Failed to create or execute flagstat command.');
        return;
    }
    return 1;
}


sub _verify_bam {
    my $self = shift;
    
    my $bam_file  = $self->temp_staging_directory . '/all_sequences.bam';
    my $flag_file = $bam_file . '.flagstat';
    my $flag_stat = Genome::Info::BamFlagstat->get_data($flag_file);
    
    unless($flag_stat) {
        $self->status_message('Fail to get flagstat data from '.$flag_file);
        return;
    }
    
    if (exists $flag_stat->{errors}) {
        my @errors = @{$flag_stat->{errors}};
        
        for my $error (@errors) {
            if ($error =~ 'Truncated file') {
                $self->error_message('Bam file: ' . $bam_file . ' appears to be truncated');
                return;
            } 
            else {
                $self->status_message('Continuing despite error messages from flagstat: ' . $error);
            }
        }
    }

    if (!exists $flag_stat->{total_reads} || $flag_stat->{total_reads} == 0) {
        $self->error_message("Bam file $bam_file has no reads reported (neither aligned nor unaligned).");
        return;
    } 

    unless ($self->_check_read_count($flag_stat->{total_reads})) {
        $self->error_message("Bam file $bam_file failed read_count checking");
        return;
    }

    return 1;
}

sub _check_read_count {
    my ($self, $bam_rd_ct) = @_;
    my $fq_rd_ct = $self->_fastq_read_count;
    my $check = "Read count from bam: $bam_rd_ct and fastq: $fq_rd_ct";

    unless ($fq_rd_ct == $bam_rd_ct) {
        $self->error_message("$check does not match.");
        return;
    }
    $self->status_message("$check matches.");
    return 1;
}


sub _create_bam_md5 {
    my $self = shift;

    my $bam_file = $self->temp_staging_directory . '/all_sequences.bam';
    my $md5_file = $bam_file . '.md5';
    my $cmd      = "md5sum $bam_file > $md5_file";

    my $rv  = Genome::Sys->shellcmd(
        cmd                        => $cmd, 
        input_files                => [$bam_file],
        output_files               => [$md5_file],
        skip_if_output_is_present  => 0,
    ); 
    $self->error_message("Fail to run: $cmd") and return unless $rv == 1;
    return 1;
}


sub _promote_validated_data {
    my $self = shift;

    #my $container_dir = File::Basename::dirname($self->output_dir);
    my $staging_dir = $self->temp_staging_directory;
    my $output_dir  = $self->output_dir;

    $self->status_message("Now de-staging data from $staging_dir into $output_dir"); 

    my $call = sprintf("rsync -avzL %s/* %s", $staging_dir, $output_dir);

    my $rv = system($call);
    $self->status_message("Running Rsync: $call");

    unless ($rv == 0) {
        $self->error_message("Did not get a valid return from rsync, rv was $rv for call $call.  Cleaning up and bailing out");
        rmpath($output_dir);
        die $self->error_message;
    }

    chmod 02775, $output_dir;
    for my $subdir (grep { -d $_  } glob("$output_dir/*")) {
        chmod 02775, $subdir;
    }
   
    # Make everything in here read-only 
    for my $file (grep { -f $_  } glob("$output_dir/*")) {
        chmod 0444, $file;
    }

    $self->status_message("Files in $output_dir: \n" . join "\n", glob($output_dir . "/*"));

    return $output_dir;
}

sub _process_sam_files {
    my $self = shift;

    my $groups_input_file;

    # if a bam file is already staged at the end of _run_aligner, trust it to be correct.
    if (-e $self->temp_staging_directory . "/all_sequences.bam") {
        return 1;
    }
    
    my $sam_input_file = $self->temp_scratch_directory . "/all_sequences.sam";

    unless (-e $sam_input_file) {
        $self->error_message("$sam_input_file is nonexistent.  Can't convert!");
        die $self->error_message;
    }
        
    # things which don't produce sam natively must provide an unaligned reads file.
    my $unaligned_input_file = $self->temp_scratch_directory . "/all_sequences_unaligned.sam";

    if (-s $unaligned_input_file) {
        $self->status_message("Looks like there are unaligned reads not in the main input file.  ");
        my @input_files = ($sam_input_file, $unaligned_input_file);
        $self->status_message("Cat-ing the unaligned list $unaligned_input_file to the sam file $sam_input_file");
        my $cat_rv = Genome::Sys->cat(input_files=>[$unaligned_input_file],output_file=>$sam_input_file,append_mode=>1);
        if ($cat_rv ne 1) {
            $self->error_message("Error during cat of alignment sam files! Return value $cat_rv");
            die $self->error_message;
        } else {
            $self->status_message("Cat of sam files successful.");
        }      
        
        unlink($unaligned_input_file);
    }

    my $per_lane_sam_file_rg = $sam_input_file;
   
    if ($self->requires_read_group_addition) {
        $per_lane_sam_file_rg = $self->temp_scratch_directory . "/all_sequences_rg.sam";
        my $add_rg_cmd = Genome::Model::Tools::Sam::AddReadGroupTag->create(
            input_file     => $sam_input_file,
            output_file    => $per_lane_sam_file_rg,
            read_group_tag => $self->instrument_data->id,
        );

        unless ($add_rg_cmd->execute) {
            $self->error_message("Adding read group to sam file failed!");
            die $self->error_message;
        }
        $self->status_message("Read group add completed, new file is $per_lane_sam_file_rg");

        $self->status_message("Removing non-read-group combined sam file: " . $sam_input_file);
        unlink($sam_input_file);
    } 

    #For the sake of new bam flagstat that need MD tags added. Some
    #aligner like maq doesn't output MD tag in sam file, now add it
    my $final_sam_file;
    
    if ($self->fillmd_for_sam) {
        my $sam_path = Genome::Model::Tools::Sam->path_for_samtools_version($self->samtools_version);
        my $ref_seq  = $self->reference_build->full_consensus_path('fa');
        $final_sam_file = $self->temp_scratch_directory . '/all_sequences.fillmd.sam';
       
        my $cmd = "$sam_path fillmd -S $per_lane_sam_file_rg $ref_seq 1> $final_sam_file 2>/dev/null";

        my $rv  = Genome::Sys->shellcmd(
            cmd                          => $cmd, 
            input_files                  => [$per_lane_sam_file_rg, $ref_seq],
            output_files                 => [$final_sam_file],
            skip_if_output_is_present    => 0,
        ); 
        $self->error_message("Fail to run: $cmd") and return unless $rv == 1;
        unlink $per_lane_sam_file_rg;
    }
    else {
        $final_sam_file = $per_lane_sam_file_rg;
    }
    
    my $ref_list  = $self->reference_build->full_consensus_sam_index_path($self->samtools_version);
    unless ($ref_list) {
        $self->error_message("Failed to get MapToBam ref list: $ref_list");
        return;
    }

    if (-e "/opt/fscache/" . $ref_list) {
        $ref_list = "/opt/fscache/" . $ref_list;
    }

    my $per_lane_bam_file = $self->temp_staging_directory . "/all_sequences.bam";

    my $to_bam = Genome::Model::Tools::Sam::SamToBam->create(
        bam_file => $per_lane_bam_file,
        sam_file => $final_sam_file,
        keep_sam => 0,
        fix_mate => 1,
        index_bam => 1,
        ref_list => $ref_list,
        use_version => $self->samtools_version,
    );
    unless($to_bam->execute) {
        $self->error_message("There was an error converting the Sam file $final_sam_file to $per_lane_bam_file.");
        die $self->error_message;
    }

    $self->status_message("Conversion successful.  File is: $per_lane_bam_file");

    return 1;

}


sub _gather_params_for_get_or_create {
    my $class = shift;
    my $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($class, @_);

    my $aligner_name = $bx->value_for('aligner_name');
    my $subclass = join '::', 'Genome::InstrumentData::AlignmentResult', $class->_resolve_subclass_name_for_aligner_name($aligner_name);

    my %params = $bx->params_list;
    my %is_input;
    my %is_param;
    my $class_object = $subclass->__meta__;
    for my $key ($subclass->property_names) {
        my $meta = $class_object->property_meta_for_name($key);
        if ($meta->{is_input} && exists $params{$key}) {
            $is_input{$key} = $params{$key};
        } elsif ($meta->{is_param} && exists $params{$key}) {
            $is_param{$key} = $params{$key}; 
        }

    }
    
    my $inputs_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($subclass, %is_input);
    my $params_bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($subclass, %is_param);

    my %software_result_params = (#software_version=>$params_bx->value_for('aligner_version'),
                                  params_id=>$params_bx->id,
                                  inputs_id=>$inputs_bx->id,
                                  subclass_name=>$subclass);
    
    return {
        software_result_params => \%software_result_params,
        subclass => $subclass,
        inputs=>\%is_input,
        params=>\%is_param,
    };
    
}

   
sub _prepare_working_directories {
    my $self = shift;

    return $self->temp_staging_directory if ($self->temp_staging_directory);

    my $base_temp_dir = Genome::Sys->base_temp_directory();

    my $hostname = hostname;
    my $user = $ENV{'USER'};
    my $basedir = sprintf("alignment-%s-%s-%s-%s", $hostname, $user, $$, $self->id);
    my $tempdir = Genome::Sys->create_temp_directory($basedir);
    unless($tempdir) {
        die "failed to create a temp staging directory for completed files";
    }
    $self->temp_staging_directory($tempdir);

    my $scratch_basedir = sprintf("scratch-%s-%s-%s", $hostname, $user, $$);
    my $scratch_tempdir =  Genome::Sys->create_temp_directory($scratch_basedir);
    $self->temp_scratch_directory($scratch_tempdir);
    unless($scratch_tempdir) {
        die "failed to create a temp scrach directory for working files";
    }

    return 1;
} 


sub _staging_disk_usage {

    my $self = shift;
    my $usage;
    unless ($usage = Genome::Sys->disk_usage_for_path($self->temp_staging_directory)) {
        $self->error_message("Failed to get disk usage for staging: " . Genome::Sys->error_message);
        die $self->error_message;
    }

    return $usage;
}

sub _prepare_alignment_directory {

    my $self = shift;

    my $subdir = $self->resolve_alignment_subdirectory;
    unless ($subdir) {
        $self->error_message("failed to resolve subdirectory for instrument data.  cannot proceed.");
        die $self->error_message;
    }
    
    my %allocation_get_parameters = (
        disk_group_name => 'info_alignments',
        allocation_path => $subdir,
    );

    my %allocation_create_parameters = (
        %allocation_get_parameters,
        kilobytes_requested => $self->_staging_disk_usage,
        owner_class_name => $self->class,
        owner_id => $self->id
    );
    
    my $allocation = Genome::Disk::Allocation->allocate(%allocation_create_parameters);
    unless ($allocation) {
        $self->error_message("Failed to get disk allocation with params:\n". Dumper(%allocation_create_parameters));
        die($self->error_message);
    }

    my $output_dir = $allocation->absolute_path;
    unless (-d $output_dir) {
        $self->error_message("Allocation path $output_dir doesn't exist!");
        die $self->error_message;
    }
    
    $self->output_dir($output_dir);
    
    return $output_dir;
}

sub estimated_kb_usage {
    30000000;
    #die "unimplemented method: please define estimated_kb_usage in your alignment subclass.";
}

sub resolve_alignment_subdirectory {
    my $self = shift;
    my $instrument_data = $self->instrument_data;
    my $staged_basename = File::Basename::basename($self->temp_staging_directory);
    # TODO: the first subdir is actually specified by the disk management system.
    my $directory = join('/', 'alignment_data',$instrument_data->id,$staged_basename);
    return $directory;
}


sub _extract_input_fastq_filenames {
    my $self = shift;

    my $instrument_data = $self->instrument_data;
    
    my %segment_params;
    
    if (defined $self->instrument_data_segment_type) {
        # sanity check this can be segmented
        if (! $self->instrument_data->can('get_segments') && $self->instrument_data->get_segments > 0) {
            $self->error_message("requested to align a given segment, but this instrument data either can't be segmented or has no segments.");
            die $self->error_message;
        }
        
        # only read groups for now
        if ($self->instrument_data_segment_type ne 'read_group') {
            $self->error_message("specified a segment type we don't support, " . $self->instrument_data_segment_type . ". we only support read group at present.");
            die $self->error_message;
        }
        
        if (defined $self->filter_name) {
            $self->error_message("filtering reads is currently not supported with segmented inputs, FIXME.");
            die $self->error_message;
        }
        
        $segment_params{read_group_id} = $self->instrument_data_segment_id;
    }

    my @input_fastq_pathnames;
    if ($self->_input_fastq_pathnames) {
        @input_fastq_pathnames = @{$self->_input_fastq_pathnames};
        my $errors;
        for my $input_fastq (@input_fastq_pathnames) {
            unless (-e $input_fastq && -f $input_fastq && -s $input_fastq) {
                $self->error_message('Missing or zero size sanger fastq file: '. $input_fastq);
                die($self->error_message);
            }
        }
    } 
    else {
        my %params;
        
        # FIXME - getting a warning about undefined string with 'eq'
        if (! defined($self->filter_name)) {
            $self->status_message('No special filter for this assignment');
        }
        elsif ($self->filter_name eq 'forward-only') {
            # forward reads only
            $self->status_message('forward-only filter applied for this assignment');
        }
        elsif ($self->filter_name eq 'reverse-only') {
            # reverse reads only
            $self->status_message('reverse-only filter applied for this assignment');
        }
        else {
            die 'Unsupported filter: "' . $self->filter_name . '"!';
        }
    
        $DB::single = 1;
        my @illumina_fastq_pathnames = $instrument_data->dump_sanger_fastq_files(%params, %segment_params);
        my $counter = 0;
        for my $input_fastq_pathname (@illumina_fastq_pathnames) {
            if ($self->trimmer_name) {
                unless ($self->trimmer_name eq 'trimq2_shortfilter') {
                    my $trimmed_input_fastq_pathname = Genome::Sys->create_temp_file_path('trimmed-sanger-fastq-'. $counter);
                    my $trimmer;
                    if ($self->trimmer_name eq 'fastx_clipper') {
                        #THIS DOES NOT EXIST YET
                        $trimmer = Genome::Model::Tools::Fastq::Clipper->create(
                            params => $self->trimmer_params,
                            version => $self->trimmer_version,
                            input => $input_fastq_pathname,
                            output => $trimmed_input_fastq_pathname,
                        );
                    } 
                    elsif ($self->trimmer_name eq 'trim5') {
                        $trimmer = Genome::Model::Tools::Fastq::Trim5->create(
                            length => $self->trimmer_params,
                            input => $input_fastq_pathname,
                            output => $trimmed_input_fastq_pathname,
                        );
                    } 
                    elsif ($self->trimmer_name eq 'bwa_style') {
                        my ($trim_qual) = $self->trimmer_params =~ /--trim-qual-level\s*=?\s*(\S+)/;
                        $trimmer = Genome::Model::Tools::Fastq::TrimBwaStyle->create(
                            trim_qual_level => $trim_qual,
                            fastq_file      => $input_fastq_pathname,
                            out_file        => $trimmed_input_fastq_pathname,
                            qual_type       => 'sanger',  #hardcoded for now
                            report_file     => $self->temp_staging_directory.'/trim_bwa_style.report.'.$counter,
                        );
                    }
                    elsif ($self->trimmer_name =~ /trimq2_(\S+)/) {
                        #This is for trimq2 no_filter style
                        #move trimq2.report to alignment directory
                        
                        my %params = (
                            fastq_file  => $input_fastq_pathname,
                            out_file    => $trimmed_input_fastq_pathname,
                            report_file => $self->temp_staging_directory.'/trimq2.report.'.$counter,
                            trim_style  => $1,
                        );
                        my ($qual_level, $string) = $self->_get_trimq2_params;
                 
                        my $param = $self->trimmer_params;
                        my ($primer_sequence) = $param =~ /--primer-sequence\s*=?\s*(\S+)/;
                        $params{trim_qual_level} = $qual_level if $qual_level;
                        $params{trim_string}     = $string if $string;
                        $params{primer_sequence} = $primer_sequence if $primer_sequence;
                        $params{primer_report_file} = $self->temp_staging_directory.'/trim_primer.report.'.$counter if $primer_sequence;
        
                        $trimmer = Genome::Model::Tools::Fastq::Trimq2::Simple->create(%params);
                    } 
                    elsif ($self->trimmer_name eq 'random_subset') {
                        my $seed_phrase = $instrument_data->run_name .'_'. $instrument_data->id;
                        $trimmer = Genome::Model::Tools::Fastq::RandomSubset->create(
                            input_read_1_fastq_files => [$input_fastq_pathname],
                            output_read_1_fastq_file => $trimmed_input_fastq_pathname,
                            limit_type => 'reads',
                            limit_value => $self->trimmer_params,
                            seed_phrase => $seed_phrase,
                        );
                    } 
                    elsif ($self->trimmer_name eq 'normalize') {
                        my $params = $self->trimmer_params;
                        my ($read_length,$reads) = split(':',$params);
                        my $trim = Genome::Model::Tools::Fastq::Trim->execute(
                            read_length => $read_length,
                            orientation => 3,
                            input => $input_fastq_pathname,
                            output => $trimmed_input_fastq_pathname,
                        );
                        unless ($trim) {
                            die('Failed to trim reads using test_trim_and_random_subset');
                        }
                        my $random_input_fastq_pathname = Genome::Sys->create_temp_file_path('random-sanger-fastq-'. $counter);
                        $trimmer = Genome::Model::Tools::Fastq::RandomSubset->create(
                            input_read_1_fastq_files => [$trimmed_input_fastq_pathname],
                            output_read_1_fastq_file => $random_input_fastq_pathname,
                            limit_type  => 'reads',
                            limit_value => $reads,
                            seed_phrase => $instrument_data->run_name .'_'. $instrument_data->id,
                        );
                        $trimmed_input_fastq_pathname = $random_input_fastq_pathname;
                    } 
                    else {
                        # TODO: modularize the above and refactor until they work in this logic:
                        # Then ensure that the trimmer gets to work on paired files, and is 
                        # a more generic "preprocess_reads = 'foo | bar | baz' & "[1,2],[],[3,4,5]"
                        my $params = $self->trimmer_params;
                        my @params = eval("no strict; no warnings; $params");
                        if ($@) {
                            die "error in params: $@\n$params\n";
                        }

                        my $class_name = 'Genome::Model::Tools::FastQual::Trimmer';
                        my @words = split(' ',$self->trimmer_name);
                        for my $word (@words) {
                            my @parts = map { ucfirst($_) } split('-',$word);
                            $class_name .= "::" . join('',@parts);
                        }
                        eval {
                            $trimmer = $class_name->create(
                                input => [$input_fastq_pathname],
                                output => [$trimmed_input_fastq_pathname],
                                @params,
                            );
                        };
                        unless ($trimmer) {
                            $self->error_message(
                                sprintf(
                                    "Unknown read trimmer_name %s.  Class $class_name params @params. $@",
                                    $self->trimmer_name,
                                    $class_name
                                )
                            );
                            die($self->error_message);
                        }
                    }
                    unless ($trimmer) {
                        $self->error_message('Failed to create fastq trim command');
                        die($self->error_message);
                    }
                    unless ($trimmer->execute) {
                        $self->error_message('Failed to execute fastq trim command '. $trimmer->command_name);
                        die($self->error_message);
                    }
                    if ($self->trimmer_name eq 'normalize') {
                        my @empty = ();
                        $trimmer->_index(\@empty);
                    }
                    $input_fastq_pathname = $trimmed_input_fastq_pathname;
                }
            }
            push @input_fastq_pathnames, $input_fastq_pathname;
            $counter++;
        }

        # this previously happened at the beginning of _run_aligner
        @input_fastq_pathnames = $self->run_trimq2_filter_style(@input_fastq_pathnames) 
            if $self->trimmer_name and $self->trimmer_name eq 'trimq2_shortfilter';

        $self->_input_fastq_pathnames(\@input_fastq_pathnames);
    }
    return @input_fastq_pathnames;
}


sub input_bfq_filenames {
    my $self = shift;
    my @input_fastq_pathnames = @_;

    my @input_bfq_pathnames;
    if ($self->_input_bfq_pathnames) {
        @input_bfq_pathnames = @{$self->_input_bfq_pathnames};
        for my $input_bfq (@input_bfq_pathnames) {
            unless (-s $input_bfq) {
                $self->error_message('Missing or zero size sanger bfq file: '. $input_bfq);
                die $self->error_message;
            }
        }
    } 
    else {
        my $counter = 0;
        for my $input_fastq_pathname (@input_fastq_pathnames) {
            my $input_bfq_pathname = Genome::Sys->create_temp_file_path('sanger-bfq-'. $counter++);
            #Do we need remove sanger fastq here ?
            unless (Genome::Model::Tools::Maq::Fastq2bfq->execute(
                fastq_file => $input_fastq_pathname,
                bfq_file   => $input_bfq_pathname,
            )) {
                $self->error_message('Failed to execute fastq2bfq quality conversion.');
                die $self->error_message;
            }
            unless (-s $input_bfq_pathname) {
                $self->error_message('Failed to validate the conversion of sanger fastq file '. $input_fastq_pathname .' to sanger bfq.');
                die $self->error_message;
            }
            push @input_bfq_pathnames, $input_bfq_pathname;
        }
        $self->_input_bfq_pathnames(\@input_bfq_pathnames);
    }
    return @input_bfq_pathnames;
}


sub qualify_trimq2 {
    my $self = shift;
    my $trimmer_name = $self->trimmer_name;

    return 1 unless $trimmer_name and $trimmer_name =~ /^trimq2/;
    $self->status_message('trimq2 will be used as fastq trimmer');

    my ($style) = $trimmer_name =~ /trimq2_(\S+)/;
    unless ($style =~ /^(shortfilter|smart1|hard)$/) {
        $self->error_message("unrecognized trimq2 trimmer name: $trimmer_name");
        return;
    }
    
    my $ver = $self->instrument_data->analysis_software_version;
    unless ($ver) {
        $self->error_message("Unknown analysis software version for instrument data: ".$self->instrument_data->id);
        return;
    }
    
    if ($ver =~ /SolexaPipeline\-0\.2\.2\.|GAPipeline\-0\.3\.|GAPipeline\-1\.[01]/) {#hardcoded Illumina piepline version for now see G::I::Solexa
        $self->error_message ('Instrument data : '.$self->instrument_data->id.' not from newer Illumina analysis software version.');
        return;
    }
    return 1;
}

    
sub _get_trimq2_params {
    my $self = shift;

    my $param = $self->trimmer_params; #for trimq2_shortfilter, input something like "32:#" (length:string) in processing profile as trimmer_params, for trimq2_smart1, input "20:#" (quality_level:string)
    if ($param !~ /:/){
        $param = '::';
    }
    my ($first_param, $string) = split /\:/, $param;

    return ($first_param, $string);
}

    
sub get_trimq2_reports {
    return glob(shift->alignment_directory."/*trimq2.report*");
}

sub _get_base_counts_from_trimq2_report {
    my ($self, $report) = @_;
    my $last_line = `tail -1 $report`;
    my ($ct, $trim_ct);

    my ($style) = $self->trimmer_name =~ /trimq2_(\S+)/;
    
    if ($style =~ /^(smart1|hard)$/) {#Simple, no_filter style
        ($ct, $trim_ct) = $last_line =~ /^\s+(\d+)\s+\d+\s+(\d+)\s+/;
    }
    elsif ($style eq 'shortfilter') {
        ($ct, $trim_ct) = $last_line =~ /^\s+(\d+)\s+\d+\s+\d+\s+(\d+)\s+/;
    }
    else {
        $self->error_message("unrecognized trimq2 style: $style");
        return;
    }
    
    return ($ct, $trim_ct) if $ct and $trim_ct;
    $self->error_message("Failed to get base counts after trim for report: $report");
    return;
}
    

sub calculate_base_counts_after_trimq2 {
    my $self    = shift;
    my @reports = $self->get_trimq2_reports;
    my $total_ct       = 0;
    my $total_trim_ct  = 0;

    unless (@reports == 2 or @reports == 1) {
        $self->error_message("Incorrect trimq2 report count: ".@reports);
        return;
    }
    
    #Trimq2::Simple,  trimq2_smart1, get two report
    #Trimq2::PairEnd/Fragment, trimq2_shortfilter, get one report

    for my $report (@reports) {
        my ($ct, $trim_ct) = $self->_get_base_counts_from_trimq2_report($report);
        return unless $ct and $trim_ct;
        $total_ct += $ct;
        $total_trim_ct += $trim_ct;
    }
    return ($total_ct, $total_trim_ct);
}

sub run_trimq2_filter_style {
    my ($self, @fq_files) = @_;
    my ($length, $string) = $self->_get_trimq2_params;

    my $tmp_dir = File::Temp::tempdir(
        'Trimq2_filter_styleXXXXXX',
        DIR     => $self->temp_scratch_directory,
        CLEANUP => 1,
    );

    my %params = (
        output_dir  => $tmp_dir,
        report_file => $self->temp_staging_directory.'/trimq2.report',
    );
    
    $params{length_limit} = $length if $length; #gmt trimq2 takes 32 as default length_limit
    $params{trim_string}  = $string if $string; #gmt trimq2 takes #  as default trim_string
    
    my @trimq2_files = ();
    
    if ($self->instrument_data->is_paired_end) {
        unless (@fq_files == 2) {
            $self->error_message('Need 2 fastq files for pair-end trimq2. But get :',join ',',@fq_files);
            return;
        }
        my ($p1, $p2);
        #The names of temp files return from above method input_fastq_filenames
        #will end as either 0 or 1
        for my $file (@fq_files) {
            if ($file =~ /\-0\.fastq$/) {   #hard coded fastq file name for now
                $p1 = $file;
            }
            elsif ($file =~ /\-1\.fastq$/) {
                $p2 = $file;
            }
            else {
                $self->error_message("file names of pair end fastq do not match either -0 or -1");
            }
        }
        unless ($p1 and $p2) {
            $self->error_message("There must be both -0 and -1 fastq files existing for pair_end trimq2");
            return;
        }

        %params = (
            %params,
            pair1_fastq_file => $p1,
            pair2_fastq_file => $p2,
        );
        
        my $trimmer = Genome::Model::Tools::Fastq::Trimq2::PairEnd->create(%params);        
        my $rv = $trimmer->execute;
        
        unless ($rv == 1) {
            $self->error_message("Running Trimq2 PairEnd failed");
            return;
        }
        push @trimq2_files, $trimmer->pair1_out_file, $trimmer->pair2_out_file, $trimmer->pair_as_frag_file;
    }
    else {
        unless (@fq_files == 1) {
            $self->error_message('Need 1 fastq file for fragment trimq2. But get:', join ',', @fq_files);
            return;
        }
        
        %params = (
            %params,
            fastq_file => $fq_files[0],
        );

        my $trimmer = Genome::Model::Tools::Fastq::Trimq2::Fragment->create(%params);
        my $rv = $trimmer->execute;

        unless ($rv == 1) {
            $self->error_message('Running Trimq2 Fragment failed');
            return;
        }
        push @trimq2_files, $trimmer->out_file;
    }

    return @trimq2_files;
}

sub trimq2_filtered_to_unaligned_sam {
    my $self = shift;
    my $alignment_directory = shift || $self->temp_scratch_directory;

    unless ($self->trimmer_name eq 'trimq2_shortfilter') {
        $self->error_message('trimq2_filtered_to_unaligned method only applies to trimq2_shortfilter as trimmer');
        return;
    }
    
    my @filtered = glob($alignment_directory."/*.filtered.fastq");

    unless (@filtered) {
        $self->warning_message('There is no trimq2.filtered.fastq under alignment directory: '. $alignment_directory);
        return;
    }

    my $out_fh = File::Temp->new(
        TEMPLATE => 'filtered_unaligned_XXXXXX', 
        DIR      => $alignment_directory, 
        SUFFIX   => '.sam',
    );
    
    my $filler = "\t*\t0\t0\t*\t*\t0\t0\t";
    my $seq_id = $self->instrument_data->id;
    my ($pair1, $pair2, $frag) = ("\t69", "\t133", "\t4");
    my ($rg_tag, $pg_tag)      = ("\tRG:Z:", "\tPG:Z:");
    
    FILTER: for my $file (@filtered) {#for now there are 3 types: pair_end, fragment, pair_as_fragment    
        unless (-s $file) {
            $self->warning_message("trimq2 filtered file: $file is empty");
            next;
        }
        
        my $fh = Genome::Sys->open_file_for_reading($file);

        if ($file =~ /\.pair_end\./) { #filtered output from G::M::T::F::Trimq2::PairEnd
            while (my $head1 = $fh->getline) {
                my $seq1  = $fh->getline;
                my $sep1  = $fh->getline;
                my $qual1 = $fh->getline;

                my $head2 = $fh->getline;
                my $seq2  = $fh->getline;
                my $sep2  = $fh->getline;
                my $qual2 = $fh->getline;

                chomp ($seq1, $qual1, $seq2, $qual2);

                my ($name1) = $head1 =~ /^@(\S+)\/[12]\s/; # read name in sam file doesn't contain /1, /2
                my ($name2) = $head2 =~ /^@(\S+)\/[12]\s/;
            
                unless ($name1 eq $name2) {
                    $self->error_message("Pair-end names conflict : $name1 , $name2");
                    return;
                }
                
                $out_fh->print($name1.$pair1.$filler.$seq1."\t".$qual1.$rg_tag.$seq_id.$pg_tag.$seq_id."\n");
                $out_fh->print($name2.$pair2.$filler.$seq2."\t".$qual2.$rg_tag.$seq_id.$pg_tag.$seq_id."\n");
            }
        }
        else {
            FRAG: while (my $head = $fh->getline) {
                my $seq  = $fh->getline;
                my $sep  = $fh->getline;
                my $qual = $fh->getline;

                chomp ($seq, $qual);
                my $name;

                if ($file =~ /\.fragment\./) { #filtered ouput from G::M::T::F::Trimq2::Fragment
                    ($name) = $head =~ /^@(\S+?)(\/[12])?\s/;
                }
                elsif ($file =~ /\.pair_as_fragment\./) {
                #filtered output from G::M::T::F::Trimq2::PairEnd, since these are filtered pair_as_frag, their
                #mates are used for alignment as fragment. For now, keep their original name with /1, /2 to
                #differentiate
                    ($name) = $head =~ /^@(\S+)\s/;
                }
                else {
                    $self->warning_message("Unrecognized trimq2 filtered file: $file");
                    last FRAG;
                    $fh->close;
                    next FILTER;
                }
                $out_fh->print($name.$frag.$filler.$seq."\t".$qual.$rg_tag.$seq_id."\n");
            }       
        }
        $fh->close;
    }
    $out_fh->close;
    
    return $out_fh->filename;
}


sub _prepare_reference_sequences {
    my $self = shift;
    my $reference_build = $self->reference_build;

    my $ref_basename = File::Basename::fileparse($reference_build->full_consensus_path('fa'));
    my $reference_fasta_path = sprintf("%s/%s", $reference_build->data_directory, $ref_basename);

    unless(-e $reference_fasta_path) {
        $self->error_message("Alignment reference path $reference_fasta_path does not exist");
        die $self->error_message;
    }

    #my $reference_fasta_index_path = $reference_fasta_path . ".fai";
    
    #unless(-e $reference_fasta_index_path) {
    #    $self->error_message("Alignment reference index path $reference_fasta_index_path does not exist. Use 'samtools faidx' to create this");
    #    die $self->error_message;
    #}

    return 1;
}

sub get_or_create_sequence_dictionary {
    my $self = shift;

    my $species = "unknown";
    if ($self->instrument_data->id > 0) {
        $self->status_message("Sample id: ".$self->instrument_data->sample_id);
        my $sample = Genome::Sample->get($self->instrument_data->sample_id);
        if ( defined($sample) ) {
            $species =  $sample->species_name;
            if (!$species || $species eq ""  ) {
                $species = "unknown";
            }
        }
    }
    else {
        $species = 'Homo sapiens'; #to deal with solexa.t
    }

    $self->status_message("Species from alignment: ".$species);

    my $ref_build = $self->reference_build;
    my $seq_dict = $ref_build->get_sequence_dictionary("sam",$species,$self->picard_version);

    return $seq_dict;
}

sub construct_groups_file {

    my $self = shift;
    my $output_file = shift || $self->temp_scratch_directory . "/groups.sam";
    
    
    my $aligner_command_line = $self->aligner_params_for_sam_header;

    my $insert_size_for_header;
    if ($self->instrument_data->can('median_insert_size') && $self->instrument_data->median_insert_size) {
        $insert_size_for_header= $self->instrument_data->median_insert_size;
    }
    else {
        $insert_size_for_header = 0;
    }

    my $description_for_header;
    if ($self->instrument_data->is_paired_end) {
        $description_for_header = 'paired end';
    }
    else {
        $description_for_header = 'fragment';
    }


    # build the header
    my $id_tag = $self->instrument_data->id;
    my $pu_tag = sprintf("%s.%s",$self->instrument_data->run_identifier,$self->instrument_data->subset_name);
    my $lib_tag = $self->instrument_data->library_name;
    my $date_run_tag = $self->instrument_data->run_start_date_formatted;
    my $sample_tag = $self->instrument_data->sample_name;
    my $aligner_version_tag = $self->aligner_version;
    my $aligner_cmd =  $aligner_command_line;

    my $platform = $self->instrument_data->sequencing_platform;
    $platform = ($platform eq 'solexa' ? 'illumina' : $platform);

                 #@RG     ID:2723755796   PL:illumina     PU:30945.1      LB:H_GP-0124n-lib1      PI:0    DS:paired end   DT:2008-10-03   SM:H_GP-0124n   CN:WUGSC
                 #@PG     ID:0    VN:0.4.9        CL:bwa aln -t4
    my $rg_tag = "\@RG\tID:$id_tag\tPL:$platform\tPU:$pu_tag\tLB:$lib_tag\tPI:$insert_size_for_header\tDS:$description_for_header\tDT:$date_run_tag\tSM:$sample_tag\tCN:WUGSC\n";
    my $pg_tag = "\@PG\tID:$id_tag\tVN:$aligner_version_tag\tCL:$aligner_cmd\n";

    $self->status_message("RG: $rg_tag");
    $self->status_message("PG: $pg_tag");
    
    my $header_groups_fh = IO::File->new(">>".$output_file) || die "failed opening groups file for writing";
    print $header_groups_fh $rg_tag;
    print $header_groups_fh $pg_tag;
    $header_groups_fh->close;

    unless (-s $output_file) {
        $self->error_message("Failed to create groups file");
        die $self->error_message;
    }

    return 1;


}

sub aligner_params_for_sam_header {
    die "You must implement aligner_params_for_sam_header in your AlignmentResult subclass. This specifies the parameters used to align the reads";
}

sub fillmd_for_sam {
    #Maybe this can be set to return 0 as default.
    die 'Must implement fillmd_for_sam in AlignmentResult subclass. return either 1 or 0';
}

sub verify_alignment_data {
    return 1;
}

sub alignment_bam_file_paths {
    my $self = shift;

    return glob($self->alignment_directory . "/*.bam");
}

sub requires_read_group_addition {
    return 1;
}

sub supports_streaming_to_bam {
    0;
}

sub accepts_bam_input {
    0;
}

1;

