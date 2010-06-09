package Genome::InstrumentData::AlignmentResult;

use Genome;
use Data::Dumper;
use Sys::Hostname;
use IO::File;
use File::Path;
use YAML;

use warnings;
use strict;

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
        reference_name          => { via => 'reference_build', to => 'name', is_mutable => 0 },

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
        reference_build_id            => {
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
    ],
    has_metric => [
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
        _sanger_fastq_pathnames => { is => 'ARRAY', is_optional => 1 },
        _sanger_bfq_pathnames   => { is => 'ARRAY', is_optional => 1 },
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
        $unallocated_kb += $available_volumes[0]->unallocated_kb 
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

    #STEPS 6-9: CREATE BAM IN STAGING DIRECTORY
    $self->status_message("Constructing a BAM file...");
    unless( $self->create_BAM_in_staging_directory()) {
        $self->error_message("Call to create_BAM_in_staging_directory failed.\n");
        die $self->error_message;
    }

    # STEP 10: COMPUTE ALIGNMENT METRICS
    $self->status_message("Computing alignment metrics...");
    $self->_compute_alignment_metrics();

    # STEP 11: PREPARE THE ALIGNMENT DIRECTORY ON NETWORK DISK
    $self->status_message("Preparing the output directory...");
    my $output_dir = $self->output_dir || $self->_prepare_alignment_directory;
    $self->status_message("Alignment output path is $output_dir");

    # STEP 12: PROMOTE THE DATA INTO ALIGNMENT DIRECTORY
    $self->status_message("Moving results to network disk...");
    my $product_path;
    unless($product_path= $self->_promote_validated_data) {
        $self->error_message("Failed to de-stage data into alignment directory " . $self->error_message);
        die $self->error_message;
    }
    
    # STEP 13: RESIZE THE DISK
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

sub create_BAM_in_staging_directory {
    my $self = shift;
    
    # STEP 6: UNPACK THE ALIGNMENT FILES
    $self->status_message("Unpacking reads...");
    my @fastqs = $self->_extract_sanger_fastq_filenames;
    unless (@fastqs) {
        $self->error_message("Failed to gather fastq files: " . $self->error_message);
        die $self->error_message;
    }
    $self->status_message("Got " . scalar(@fastqs) . " fastq files");
    if (@fastqs > 3) {
        $self->error_message("We don't support aligning with more than 3 inputs (the first 2 are treated as PE and last 1 is treated as SE)");
        die $self->error_message;
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
        if (@fastqs == 3) {
            die "cannot handle PE and SE data together with $filter_name only data"
        }
        elsif ($filter_name eq 'forward-only') {
            @passes = ( [ shift @fastqs ] );
        }
        elsif ($filter_name eq 'reverse-only') {
            @passes = ( [ pop @fastqs ] );
        }
        $self->status_message("Running the aligner with the $filter_name filter.");
    }
    elsif ($self->force_fragment) {
        $self->status_message("Running the aligner in force-fragment mode.");
        @passes = map { [ $_ ] } @fastqs; 
    }
    elsif (@fastqs == 3) {
        $self->status_message("Running aligner twice: once for PE & once for SE");
        @passes = ( [ $fastqs[0], $fastqs[1] ], [ $fastqs[2] ] );
    }
    elsif (@fastqs == 2) {
        $self->status_message("Running aligner in PE mode");
        @passes = ( \@fastqs ); 
    }
    elsif (@fastqs == 1) {
        $self->status_message("Running aligner in SE mode");
        @passes = ( \@fastqs ); 
    }

    # STEP 8: RUN THE ALIGNER, APPEND TO all_sequences.sam IN SCRATCH DIRECTORY
    for my $pass (@passes) {
        $self->status_message("Aligning @$pass...");
        unless ($self->_run_aligner(@$pass)) {
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

    # STEP 9: CONVERT THE ALL_SEQUENCES.SAM into ALL_SEQUENCES.BAM
    $self->status_message("Building a combined BAM file...");
    unless($self->_process_sam_files) {
        $self->error_message("Failed to process sam files into bam files. " . $self->error_message);
        die $self->error_message;
    }



    return 1;
}

sub _compute_alignment_metrics {
    my $self = shift;
    my $bam = $self->temp_staging_directory . "/all_sequences.bam";
    my $out = `bash -c "LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/gsc/pkg/boost/boost_1_42_0/lib:/gscuser/ehvatum/repo/alignment_summary_cpp/yaml-cpp/build /gsc/var/tmp/alignment_summary_cpp_v1.2.1 --bam=\"$bam\""`;
    unless ($? == 0) {
        $self->error_message("Failed to compute alignment metrics.");
        die $self->error_message;
    }
    my $res = YAML::Load($out);
    unless (ref($res) eq "HASH") {
        $self->error_message("Failed to parse YAML hash from alignment_summary_cpp output.");
        die $self->error_message;
    }
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

sub _promote_validated_data {
    my $self = shift;

    #my $container_dir = File::Basename::dirname($self->output_dir);
    my $staging_dir = $self->temp_staging_directory;
    my $output_dir  = $self->output_dir;

    $self->status_message("Now de-staging data from $staging_dir into $output_dir"); 

    my $call = sprintf("rsync -avz %s/* %s", $staging_dir, $output_dir);

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

    unless($self->construct_groups_file) {
        $self->error_message("failed to create groups file");
        die $self->error_message;
    }

    $groups_input_file = $self->temp_scratch_directory . "/groups.sam";
    my $sam_input_file = $self->temp_scratch_directory . "/all_sequences.sam";

    unless (-e $sam_input_file) {
        $self->error_message("$sam_input_file is nonexistent.  Can't convert!");
        die $self->error_message;
    }

    # things which don't produce sam natively must provide an unaligned reads file.
    my $unaligned_input_file = $self->temp_scratch_directory . "/all_sequences_unaligned.sam";

    my $seq_dict = $self->get_or_create_sequence_dictionary();
    unless (-s $seq_dict) {
        $self->error_message("Failed to get sequence dictionary");
        die $self->error_message;
    }

    my @sam_components = ();

    my $per_lane_sam_file = $self->temp_scratch_directory . "/all_sequences_combined.sam";

    for my $file ($groups_input_file, $sam_input_file, $unaligned_input_file) {
        unless ($file) {
            next;
        }
        if (!-s $file) {
            $self->warning_message("$file is empty/nonexistent, will not be incorporated in final sam file");
            next;
        }
        push @sam_components, $file;
    }

    # throw the seq dictionary header on first.
    my @input_files = ($seq_dict, @sam_components);

    $self->status_message("Cat-ing together: ".join("\n",@input_files). "\n to output file ".$per_lane_sam_file);
    my $cat_rv = Genome::Utility::FileSystem->cat(input_files=>\@input_files,output_file=>$per_lane_sam_file);
    if ($cat_rv ne 1) {
        $self->error_message("Error during cat of alignment sam files! Return value $cat_rv");
        die $self->error_message;
    }
    else {
        $self->status_message("Cat of sam files successful.");
    }

    for (@sam_components) {
        $self->status_message("Removing since it's no longer needed: $_\n");
        unlink($_);
    }

    my $per_lane_sam_file_rg = $self->temp_scratch_directory . "/all_sequences_rg.sam";
   
    my $add_rg_cmd = Genome::Model::Tools::Sam::AddReadGroupTag->create(
            input_file     => $per_lane_sam_file,
            output_file    => $per_lane_sam_file_rg,
            read_group_tag => $self->instrument_data->id,
        );

    unless ($add_rg_cmd->execute) {
        $self->error_message("Adding read group to sam file failed!");
        die $self->error_message;
    }
    $self->status_message("Read group add completed, new file is $per_lane_sam_file_rg");

    $self->status_message("Removing non-read-group combined sam file: " . $per_lane_sam_file);
    unlink($per_lane_sam_file);

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
        sam_file => $per_lane_sam_file_rg,
        keep_sam => 0,
        fix_mate => 1,
        index_bam => 1,
        ref_list => $ref_list,
        use_version => $self->samtools_version,
    );
    unless($to_bam->execute) {
        $self->error_message("There was an error converting the Sam file $per_lane_sam_file to $per_lane_bam_file.");
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

    my $base_temp_dir = Genome::Utility::FileSystem->base_temp_directory();

    my $hostname = hostname;
    my $user = $ENV{'USER'};
    my $basedir = sprintf("alignment-%s-%s-%s-%s", $hostname, $user, $$, $self->id);
    my $tempdir = Genome::Utility::FileSystem->create_temp_directory($basedir);
    unless($tempdir) {
        die "failed to create a temp staging directory for completed files";
    }
    $self->temp_staging_directory($tempdir);

    my $scratch_basedir = sprintf("scratch-%s-%s-%s", $hostname, $user, $$);
    my $scratch_tempdir =  Genome::Utility::FileSystem->create_temp_directory($scratch_basedir);
    $self->temp_scratch_directory($scratch_tempdir);
    unless($scratch_tempdir) {
        die "failed to create a temp scrach directory for working files";
    }

    return 1;
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
        kilobytes_requested => $self->estimated_kb_usage,
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


sub _extract_sanger_fastq_filenames {
    my $self = shift;

    my $instrument_data = $self->instrument_data;

    my @sanger_fastq_pathnames;
    if ($self->_sanger_fastq_pathnames) {
        @sanger_fastq_pathnames = @{$self->_sanger_fastq_pathnames};
        my $errors;
        for my $sanger_fastq (@sanger_fastq_pathnames) {
            unless (-e $sanger_fastq && -f $sanger_fastq && -s $sanger_fastq) {
                $self->error_message('Missing or zero size sanger fastq file: '. $sanger_fastq);
                $self->die_and_clean_up($self->error_message);
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

        my @illumina_fastq_pathnames = $instrument_data->fastq_filenames(%params);
        my $counter = 0;
        for my $illumina_fastq_pathname (@illumina_fastq_pathnames) {
            my $sanger_fastq_pathname = Genome::Utility::FileSystem->create_temp_file_path('sanger-fastq-'. $counter);
            if ($instrument_data->resolve_quality_converter eq 'sol2sanger') {
                my $aligner_version;
                if ($self->aligner_name eq 'maq') {
                    $aligner_version = $self->aligner_version;
                } 
                else {
                    $aligner_version = '0.7.1', ### default to most recent
                }
                unless (Genome::Model::Tools::Maq::Sol2sanger->execute(
                    use_version       => $aligner_version,
                    solexa_fastq_file => $illumina_fastq_pathname,
                    sanger_fastq_file => $sanger_fastq_pathname,
                )) {
                    $self->error_message('Failed to execute sol2sanger quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            } 
            elsif ($instrument_data->resolve_quality_converter eq 'sol2phred') {
                unless (Genome::Model::Tools::Fastq::Sol2phred->execute(
                    fastq_file => $illumina_fastq_pathname,
                    phred_fastq_file => $sanger_fastq_pathname,
                )) {
                    $self->error_message('Failed to execute sol2phred quality conversion.');
                    $self->die_and_clean_up($self->error_message);
                }
            }
            unless (-e $sanger_fastq_pathname && -f $sanger_fastq_pathname && -s $sanger_fastq_pathname) {
                $self->error_message('Failed to validate the conversion of solexa fastq file '. $illumina_fastq_pathname .' to sanger quality scores');
                $self->die_and_clean_up($self->error_message);
            }

            if ($self->trimmer_name) {
                unless ($self->trimmer_name eq 'trimq2_shortfilter') {
                    my $trimmed_sanger_fastq_pathname = Genome::Utility::FileSystem->create_temp_file_path('trimmed-sanger-fastq-'. $counter);
                    my $trimmer;
                    if ($self->trimmer_name eq 'fastx_clipper') {
                        #THIS DOES NOT EXIST YET
                        $trimmer = Genome::Model::Tools::Fastq::Clipper->create(
                            params => $self->trimmer_params,
                            version => $self->trimmer_version,
                            input => $sanger_fastq_pathname,
                            output => $trimmed_sanger_fastq_pathname,
                        );
                    } 
                    elsif ($self->trimmer_name eq 'trim5') {
                        $trimmer = Genome::Model::Tools::Fastq::Trim5->create(
                            length => $self->trimmer_params,
                            input => $sanger_fastq_pathname,
                            output => $trimmed_sanger_fastq_pathname,
                        );
                    } 
                    elsif ($self->trimmer_name =~ /trimq2_(\S+)/) {
                        #This is for trimq2 no_filter style
                        #move trimq2.report to alignment directory
                        
                        my %params = (
                            fastq_file  => $sanger_fastq_pathname,
                            out_file    => $trimmed_sanger_fastq_pathname,
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
                            input_read_1_fastq_files => [$sanger_fastq_pathname],
                            output_read_1_fastq_file => $trimmed_sanger_fastq_pathname,
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
                            input => $sanger_fastq_pathname,
                            output => $trimmed_sanger_fastq_pathname,
                        );
                        unless ($trim) {
                            die('Failed to trim reads using test_trim_and_random_subset');
                        }
                        my $random_sanger_fastq_pathname = Genome::Utility::FileSystem->create_temp_file_path('random-sanger-fastq-'. $counter);
                        $trimmer = Genome::Model::Tools::Fastq::RandomSubset->create(
                            input_read_1_fastq_files => [$trimmed_sanger_fastq_pathname],
                            output_read_1_fastq_file => $random_sanger_fastq_pathname,
                            limit_type  => 'reads',
                            limit_value => $reads,
                            seed_phrase => $instrument_data->run_name .'_'. $instrument_data->id,
                        );
                        $trimmed_sanger_fastq_pathname = $random_sanger_fastq_pathname;
                    } 
                    else {
                        $self->error_message('Unknown read trimmer_name '. $self->trimmer_name);
                        $self->die_and_clean_up($self->error_message);
                    }
                    unless ($trimmer) {
                        $self->error_message('Failed to create fastq trim command');
                        $self->die_and_clean_up($self->error_message);
                    }
                    unless ($trimmer->execute) {
                        $self->error_message('Failed to execute fastq trim command '. $trimmer->command_name);
                        $self->die_and_clean_up($self->error_message);
                    }
                    if ($self->trimmer_name eq 'normalize') {
                        my @empty = ();
                        $trimmer->_index(\@empty);
                    }
                    $sanger_fastq_pathname = $trimmed_sanger_fastq_pathname;
                }
            }
            push @sanger_fastq_pathnames, $sanger_fastq_pathname;
            $counter++;
        }

        # this previously happened at the beginning of _run_aligner
        @sanger_fastq_pathnames = $self->run_trimq2_filter_style(@sanger_fastq_pathnames) 
            if $self->trimmer_name and $self->trimmer_name eq 'trimq2_shortfilter';

        $self->_sanger_fastq_pathnames(\@sanger_fastq_pathnames);
    }
    return @sanger_fastq_pathnames;
}


sub sanger_bfq_filenames {
    my $self = shift;
    my @sanger_fastq_pathnames = @_;

    my @sanger_bfq_pathnames;
    if ($self->_sanger_bfq_pathnames) {
        @sanger_bfq_pathnames = @{$self->_sanger_bfq_pathnames};
        for my $sanger_bfq (@sanger_bfq_pathnames) {
            unless (-s $sanger_bfq) {
                $self->error_message('Missing or zero size sanger bfq file: '. $sanger_bfq);
                die $self->error_message;
            }
        }
    } 
    else {
        my $counter = 0;
        for my $sanger_fastq_pathname (@sanger_fastq_pathnames) {
            my $sanger_bfq_pathname = Genome::Utility::FileSystem->create_temp_file_path('sanger-bfq-'. $counter++);
            #Do we need remove sanger fastq here ?
            unless (Genome::Model::Tools::Maq::Fastq2bfq->execute(
                fastq_file => $sanger_fastq_pathname,
                bfq_file   => $sanger_bfq_pathname,
            )) {
                $self->error_message('Failed to execute fastq2bfq quality conversion.');
                die $self->error_message;
            }
            unless (-s $sanger_bfq_pathname) {
                $self->error_message('Failed to validate the conversion of sanger fastq file '. $sanger_fastq_pathname .' to sanger bfq.');
                die $self->error_message;
            }
            push @sanger_bfq_pathnames, $sanger_bfq_pathname;
        }
        $self->_sanger_bfq_pathnames(\@sanger_bfq_pathnames);
    }
    return @sanger_bfq_pathnames;
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
        #The names of temp files return from above method sanger_fastq_filenames
        #will end as either 0 or 1
        for my $file (@fq_files) {
            if ($file =~ /\-0$/) {   #hard coded fastq file name for now
                $p1 = $file;
            }
            elsif ($file =~ /\-1$/) {
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
        
        my $fh = Genome::Utility::FileSystem->open_file_for_reading($file);

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

    my $reference_fasta_index_path = $reference_fasta_path . ".fai";
    
    unless(-e $reference_fasta_index_path) {
        $self->error_message("Alignment reference index path $reference_fasta_index_path does not exist. Use 'samtools faidx' to create this");
        die $self->error_message;
    }

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
            if ( $species eq "" || $species eq undef ) {
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
    my $aligner_command_line = $self->aligner_params_for_sam_header;

    my $insert_size_for_header;
    if ($self->instrument_data->median_insert_size) {
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
    my $pu_tag = sprintf("%s.%s",$self->instrument_data->flow_cell_id,$self->instrument_data->lane);
    my $lib_tag = $self->instrument_data->library_name;
    my $date_run_tag = $self->instrument_data->run_start_date_formatted;
    my $sample_tag = $self->instrument_data->sample_name;
    my $aligner_version_tag = $self->aligner_version;
    my $aligner_cmd =  $aligner_command_line;

                 #@RG     ID:2723755796   PL:illumina     PU:30945.1      LB:H_GP-0124n-lib1      PI:0    DS:paired end   DT:2008-10-03   SM:H_GP-0124n   CN:WUGSC
                 #@PG     ID:0    VN:0.4.9        CL:bwa aln -t4
    my $rg_tag = "\@RG\tID:$id_tag\tPL:illumina\tPU:$pu_tag\tLB:$lib_tag\tPI:$insert_size_for_header\tDS:$description_for_header\tDT:$date_run_tag\tSM:$sample_tag\tCN:WUGSC\n";
    my $pg_tag = "\@PG\tID:$id_tag\tVN:$aligner_version_tag\tCL:$aligner_cmd\n";

    $self->status_message("RG: $rg_tag");
    $self->status_message("PG: $pg_tag");
    
    my $header_groups_fh = IO::File->new(">".$self->temp_scratch_directory."/groups.sam") || die "failed opening groups file for writing";
    print $header_groups_fh $rg_tag;
    print $header_groups_fh $pg_tag;
    $header_groups_fh->close;

    unless (-s $self->temp_scratch_directory."/groups.sam") {
        $self->error_message("Failed to create groups file");
        die $self->error_message;
    }

    return 1;


}

sub aligner_params_for_sam_header {
    die "You must implement aligner_params_for_sam_header in your AlignmentResult subclass. This specifies the parameters used to align the reads";
}

sub verify_alignment_data {
    return 1;
}

sub alignment_bam_file_paths {
    my $self = shift;

    return glob($self->alignment_directory . "/*.bam");
}


sub delete {
    my $self = shift;

    my $allocation = Genome::Disk::Allocation->get(owner_id=>$self->id, owner_class_name=>ref($self));
    if ($allocation) {
        my $path = $allocation->absolute_path;
        unless (rmtree($path)) {
            $self->error_message("could not rmtree $path");
            return;
       }

       $allocation->deallocate; 
    }

    $self->SUPER::delete(@_);
}


1;

