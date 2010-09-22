package Genome::ProcessingProfile::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sys::Hostname;

our $UNALIGNED_TEMPDIR = '/tmp'; #'/gscmnt/sata844/info/hmp-mgs-test-temp';

class Genome::ProcessingProfile::MetagenomicCompositionShotgun {
    is => 'Genome::ProcessingProfile',
    has_param => [
        contamination_screen_pp_id => {
            is => 'Integer',
            doc => 'processing profile id to use for contamination screen',
        },
        metagenomic_alignment_pp_id => {
            is => 'Integer',
            doc => 'processing profile id to use for metagenomic alignment',
        },
        merging_strategy => {
            is => 'Text',
            valid_values => [qw/ best_hit bwa /],
            doc => 'strategy used to merge results from metagenomic alignments. valid values : best_hit',
        },
        dust_unaligned_reads => {
            is => 'Boolean',
            default_value => 1, 
            doc => 'flag determining if dusting is performed on unaligned reads from contamination screen step',
        },
        n_removal_cutoff => {
            is => 'Integer',
            default_value => 0,
            doc => "Reads with this amount of n's will be removed from unaligned reads from contamination screen step before before optional dusting",
        },
        mismatch_cutoff => {
            is => 'Integer',
            default_value=> 0,
            doc => 'mismatch cutoff (including softclip) for post metagenomic alignment processing',
        },
        skip_contamination_screen => {
            is => 'Boolean',
            default_value=>0,
            doc => "If this flag is specified, the instrument data assigned to this model will not be human screened, but will undergo dusting and n-removal before undergoing metagenomic alignment",
        },
    ],
    has => [
        _contamination_screen_pp => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            id_by => 'contamination_screen_pp_id',
            doc => 'processing profile to use for contamination screen',
        },
        _metagenomic_alignment_pp => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            id_by => 'metagenomic_alignment_pp_id',
            doc => 'processing profile to use for metagenomic alignment',
        },
        sequencing_platform => {
            doc => 'The sequencing platform from whence the model data was generated',
            calculate_from => ['_contamination_screen_pp'], 
            calculate => q|
                        $_contamination_screen_pp->sequencing_platform;                        |,
        },
    ],
};

sub _resource_requirements_for_execute_build {
    my $self = shift;
    return "-R 'select[model!=Opteron250 && type==LINUX64] rusage[tmp=90000:mem=16000]' -M 16000000";
}

sub _execute_build {
    my ($self, $build) = @_;

    my $model = $build->model;

    # temp hack for debugging
    my $log_model_name = $model->name;
    $self->status_message("Starting build for model $log_model_name");

    my $screen_model;
    my $screen_build;
    my @screened_assignments;

    if ($self->skip_contamination_screen){
        $self->status_message("Skipping contamination screen for instrument data");
    }else{
        $screen_model = $model->_contamination_screen_alignment_model;
        unless ($screen_model) {
            $self->error_message("couldn't grab contamination screen underlying model!");
            return;
        }

        # ENSURE WE HAVE INSTRUMENT DATA
        my @assignments = $model->instrument_data_assignments;
        if (@assignments == 0) {
            die $self->error_message("NO INSTRUMENT DATA ASSIGNED!");
        }

        # ASSIGN ANY NEW INSTRUMENT DATA TO THE CONTAMINATION SCREENING MODEL
        for my $assignment (@assignments) {
            my $instrument_data = $assignment->instrument_data;
            my $screen_assignment = $screen_model->instrument_data_assignment(
                instrument_data_id => $instrument_data->id
            );
            if ($screen_assignment) {
                $self->status_message("Instrument data " . $instrument_data->__display_name__ . " is already assigned to the screening model");
            }
            else {
                $screen_assignment = 
                $screen_model->add_instrument_data_assignment(
                    instrument_data_id => $assignment->instrument_data_id,
                    filter_desc => $assignment->filter_desc,
                );
                if ($screen_assignment) {
                    $self->status_message("Assigning instrument data " . $instrument_data->__display_name__ . " is already to the screening model");
                }
                else {
                    $self->error_message("Failed to assign instrument data " . $instrument_data->__display_name__ . " is already to the screening model");
                    Carp::confess($self->error_message());
                }
            }
        }

        # BUILD HUMAN CONTAMINATION SCREEN MODEL
        $self->status_message("Building contamination screen model if necessary");
        ($screen_build) = $self->build_if_necessary_and_wait($screen_model);
        my ($prev_from_build) = grep {$_->id eq $screen_build->id} $build->from_builds();
        $build->add_from_build(from_build=>$screen_build, role=>'contamination_screen_alignment_build') unless $prev_from_build;;
    }

    # POST-PROCESS THE UNALIGNED READS FROM THE CONTAMINATION SCREEN MODEL

    my @imported_instrument_data_for_metagenomic_models;
    if ($self->skip_contamination_screen){
        #if skipping contamination_screen, we need to extract the originally assigned imported instrument data and process and reimport it for the metagenomic screen.
        #sra data is stored in fastq/sangerqual format, so these just need to be extracted, dusted, n-removed
        my @sra_assignments = $self->instrument_data_assignments; 
        for my $assignment(@sra_assignments){
            my @post_processed_reads = $self->_process_sra_instrument_data($assignment);
            #TODO, this doesn't need to be an array of array refs, since we should get a 1 to 1 sra inst_data to post-processed imported inst_data, but this is how it's done in the original pipeline, where the 1 to 1 convention doesn't hold.  We're sticking to this standard for now.
            push @imported_instrument_data_for_metagenomic_models, \@post_processed_reads;
        }
        @screened_assignments = @sra_assignments;
    
    }else{
        #if we contamination screened, we'll use the alignment results, extract unaligned reads to a fastq and then post-process, create new imported instrument data
        $self->status_message("Processing and importing instrument data for any new unaligned reads");
        @screened_assignments = $screen_model->instrument_data_assignments;
        my @post_processed_unaligned_reads;
        for my $assignment (@screened_assignments) {
            my @alignment_results = $assignment->results($screen_build);
            if (@alignment_results > 1) {
                $self->error_message( "Multiple alignment_results found for instrument data assignment: " . $assignment->__display_name__);
                return;
            }
            if (@alignment_results == 0) {
                $self->error_message( "No alignment_results found for instrument data assignment: " . $assignment->__display_name__);
                return;
            }
            $self->status_message("Processing instrument data assignment ".$assignment->__display_name__." for unaligned reads import");

            my $alignment_result = $alignment_results[0];
            my @post_processed_unaligned_reads_for_alignment_result = $self->_process_unaligned_reads($alignment_result);
            push @post_processed_unaligned_reads, \@post_processed_unaligned_reads_for_alignment_result
        }

        unless (@post_processed_unaligned_reads == @screened_assignments) {
            Carp::confess("The count of post-processed unaligned reads does not match the count of screened instrument data assignments.");
        }
        @imported_instrument_data_for_metagenomic_models = @post_processed_unaligned_reads;
    }


    # ASSIGN THE POST-PROCESSED READS TO THE METAGENOMIC MODELS
    my @metagenomic_models = $model->_metagenomic_alignment_models;
    for my $metagenomic_model (@metagenomic_models) {
        my %assignments_expected;
        for my $n (0..$#imported_instrument_data_for_metagenomic_models) {
            my $prev_assignment = $screened_assignments[$n];
            my $post_processed_instdata_for_prev_assignment = $imported_instrument_data_for_metagenomic_models[$n];
            for my $instrument_data (@$post_processed_instdata_for_prev_assignment) {
                my $metagenomic_assignment = $metagenomic_model->instrument_data_assignment(
                    instrument_data_id => $instrument_data->id
                );
                if ($metagenomic_assignment) {
                    $self->status_message("Instrument data " . $instrument_data->__display_name__ . " is already assigned to model " . $metagenomic_model->__display_name__);
                }
                else {
                    $metagenomic_assignment = 
                    $metagenomic_model->add_instrument_data_assignment(
                        instrument_data_id => $instrument_data->id,
                        filter_desc => $prev_assignment->filter_desc,
                    );
                    if ($metagenomic_assignment) {
                        $self->status_message("Assigning instrument data " . $instrument_data->__display_name__ . " to model " . $metagenomic_model->__display_name__);
                    }
                    else {
                        $self->error_message("Failed to assign instrument data " . $instrument_data->__display_name__ . " to model " . $metagenomic_model->__display_name__);
                        Carp::confess($self->error_message());
                    }
                }
                $assignments_expected{$metagenomic_assignment->id} = $metagenomic_assignment;
            }
        }

        # ensure there are no other odd assignments on the model besides those expected
        # this can happen if instrument-data is re-processed (deleted)
        for my $assignment ($metagenomic_model->instrument_data_assignments) {
            unless ($assignments_expected{$assignment->id}) {
                my $instrument_data = $assignment->instrument_data;
                if ($instrument_data) {
                    $self->error_message(
                        "Odd assignment found on model " 
                        . $metagenomic_model->__display_name__ 
                        . " for instrument data " 
                        . $instrument_data->__display_name__
                    );
                    Carp::confess($self->error_message);
                }
                else {
                    $self->warning_message(
                        "Odd assignment found on model " 
                        . $model->__display_name__ 
                        . " for MISSING instrument data.  Deleting the assignment."
                    );
                    $assignment->delete;
                }
            }
        }
    }


    # BUILD THE METAGENOMIC REFERENCE ALIGNMENT MODELS
    my @metagenomic_builds = $self->build_if_necessary_and_wait(@metagenomic_models);
    for my $meta_build (@metagenomic_builds){
        my ($prev_meta_from_build) = grep {$_->id eq $meta_build->id} $build->from_builds();
        $build->add_from_build(from_build=>$meta_build, role=>'metagenomic_alignment_build') unless $prev_meta_from_build;
    }
    # SYMLINK ALIGNMENT FILES TO BUILD DIRECTORY
    my $data_directory = $build->data_directory;
    my ($screen_bam, $screen_flagstat) = $self->get_bam_and_flagstat_from_build($screen_build);

    unless ($screen_bam and $screen_flagstat and -e $screen_bam and -e $screen_flagstat){
        die $self->error_message("Bam or flagstat doesn't exist for contamination screen build");
    }
    $self->symlink($screen_bam, "$data_directory/contamination_screen.bam");
    $self->symlink($screen_flagstat, "$data_directory/contamination_screen.bam.flagstat");

    my $counter;
    my @meta_bams;
    for my $meta_build (@metagenomic_builds){
        $counter++;
        my ($meta_bam, $meta_flagstat) =  $self->get_bam_and_flagstat_from_build($meta_build);
        push @meta_bams, $meta_bam;
        unless ($meta_bam and $meta_flagstat and -e $meta_bam and -e $meta_flagstat){
            die $self->error_message("Bam or flagstat doesn't exist for metagenomic alignment build $counter");
        }
        $self->symlink($meta_bam, "$data_directory/metagenomic_alignment$counter.bam");
        $self->symlink($meta_flagstat, "$data_directory/metagenomic_alignment$counter.bam.flagstat");
    }

    # REPORTS

    # enable "verbose" logging so we can actually see status messages from these methods
    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    my $qc_report = Genome::Model::MetagenomicCompositionShotgun::Command::QcReport->create(build_id => $build->id);
    unless($qc_report->execute()) {
        die $self->error_message("Failed to create QC report!");
    }

    my $meta_report = Genome::Model::MetagenomicCompositionShotgun::Command::MetagenomicReport->create(
        build_id => $build->id,
        taxonomy_file => '/gscmnt/sata409/research/mmitreva/databases/Bact_Arch_Euky.taxonomy.txt',
        viral_taxonomy_file => '/gscmnt/sata409/research/mmitreva/databases/viruses_taxonomy_feb_25_2010.txt',
    );
    unless($meta_report->execute()) {
        die $self->error_message("metagenomic report execution died or did not return 1:$@");
    }

    my $validate_build = Genome::Model::MetagenomicCompositionShotgun::Command::Validate->create(build_id => $build->id);
    unless($validate_build->execute()) {
        die $self->error_message("Failed to validate build!");
    }

    return 1;
}

sub extract_unaligned_reads_from_alignment_result {
    my ($self, $alignment_result) = @_;
    my ($frag_fastq, $fwd_fastq, $rev_fastq);

    my $output_dir = "$UNALIGNED_TEMPDIR/unaligned_reads/" . $alignment_result->id;
    if (-d $output_dir) {
        die $self->error_message("Directory ($output_dir) already exists?!?!");
    }
    elsif (mktree $output_dir) {
        die $self->error_message("Failed to create directory $output_dir : $!");
    }

    my $bam = $alignment_result->output_dir . '/all_sequences.bam';
    unless (-s $bam) {
        die $self->error_message("Failed to find expected BAM file $bam\n");
    }

    $self->status_message("Preparing imported instrument data for import path $output_dir");
    my $extract_unaligned = Genome::Model::Tools::BioSamtools::BamToUnalignedFastq->create(
        bam_file => $bam,
        output_directory => $output_dir,
    );
    $self->execute_or_die($extract_unaligned);

    my @files = glob("$output_dir/*_sequence.txt");
    if (@files != 3) {
        die $self->error_message("Found more than three FastQ files in $output_dir!");
    }
    for my $file (@files) {
        $frag_fastq = $file if ($file =~ /s_\d_sequence.txt$/);
        $fwd_fastq  = $file if ($file =~ /s_\d_1_sequence.txt$/);
        $rev_fastq  = $file if ($file =~ /s_\d_2_sequence.txt$/);
    }
    my @fastq_files = ($frag_fastq, $fwd_fastq, $rev_fastq);

    my @missing = grep {! -e $_} grep { defined($_) and length($_) } @fastq_files;
    if (@missing){
        die $self->error_message(join(", ", @missing)." unaligned files missing after bam extraction");
    }

    $self->status_message("Extracted unaligned reads from bam file(" . join(', ', @fastq_files) . ").");
    return (@fastq_files, $output_dir);
}

sub get_imported_instrument_data_or_upload_paths {  #TODO not finished, not currently used
    my ($self, $orig_inst_data, @paths) = @_;
    my @inst_data;
    my @upload_paths;
    my @locks;
    my $tmp_dir;
    my $subdir;

    # check for previous unaligned reads
    $self->status_message("Checking for previously imported unaligned and post-processed reads from: $tmp_dir/$subdir");
    for my $path (@paths) {
        my $inst_data = Genome::InstrumentData::Imported->get(original_data_path => $path);
        if ($inst_data) {
            $self->status_message("imported instrument data already found for path $path, skipping");
            push @inst_data, $inst_data;
        }
        else {
            for my $sub_path (split(',', $path)) {
                my $lock_path = '/gsc/var/lock/' . $orig_inst_data->id . '/' . basename($sub_path);
                my $lock = lock_or_die($lock_path);
                push @locks, $lock;
            }
            push @upload_paths, $path;
        }
    }

    if (@upload_paths) {
        for my $path (@upload_paths) {
            $self->status_message("planning to upload for $path");
        }
        return @upload_paths;
    }
    else {
        $self->status_message("skipping read processing since all data is already processed and uploaded");
        return @inst_data;
    }
    return \@inst_data, \@upload_paths;
}

sub upload_instrument_data_and_unlock {
    my ($self, $orig_inst_data, $locks_ref, $upload_ref);
    my @locks = @$locks_ref;
    my @upload_paths = @$upload_ref;

    $self->status_message("uploading new instrument data from the post-processed unaligned reads...");    
    my @properties_from_prior = qw/
    run_name 
    subset_name 
    sequencing_platform 
    median_insert_size 
    sd_above_insert_size
    library_name
    sample_name
    /;
    my @errors;
    my %properties_from_prior;
    for my $property_name (@properties_from_prior) {
        my $value = $orig_inst_data->$property_name;
        no warnings;
        $self->status_message("Value for $property_name is $value");
        $properties_from_prior{$property_name} = $value;
    }

    my @instrument_data;
    for my $original_data_path (@upload_paths) {
        if ($original_data_path =~ /,/){
            $properties_from_prior{is_paired_end} = 1;
        }else{
            $properties_from_prior{is_paired_end} = 0;
        }
        my %params = (
            %properties_from_prior,
            source_data_files => $original_data_path,
            import_format => 'illumina fastq',
        );
        $self->status_message("importing fastq with the following params:" . Data::Dumper::Dumper(\%params));


        my $command = Genome::InstrumentData::Command::Import::Fastq->create(%params);
        unless ($command) {
            $self->error_message( "Couldn't create command to import unaligned fastq instrument data!");
        };
        my $result = $command->execute();
        unless ($result) {
            die $self->error_message( "Error importing data from $original_data_path! " . Genome::InstrumentData::Command::Import::Fastq->error_message() );
        }            
        $self->status_message("committing newly created imported instrument data");
        $DB::single = 1;
        $self->status_message("UR_DBI_NO_COMMIT: ".$ENV{UR_DBI_NO_COMMIT});
        UR::Context->commit(); # warning: most code should NEVER do this in a pipeline

        my $instrument_data = Genome::InstrumentData::Imported->get(
            original_data_path => $original_data_path
        );
        unless ($instrument_data) {
            die $self->error_message( "Failed to find new instrument data $original_data_path!");
        }
        if ($instrument_data->__changes__) {
            die "Unsaved changes present on instrument data $instrument_data->{id} from $original_data_path!!!";
        }
        for my $lock (@locks) {
            if ($lock) {
                unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock)) {
                    die $self->error_message("Failed to unlock " . $lock->resource_lock . ".");
                }
            }
        }
        push @instrument_data, $instrument_data;
    }        
    return @instrument_data;
}

sub lock_or_die {
    my ($self, $lock_path) = @_;
    my $lock = Genome::Utility::FileSystem->lock_resource(
        resource_lock => $lock_path,
        max_try => 2,
    );
    if ($lock) {
        $self->status_message("Locked $lock_path successfully.");
        return $lock;
    }
    else {
        die $self->error_message("Failed to lock $lock_path.");
    }
}

sub execute_or_die {
    my ($self, $command) = @_;
    my $class = $command->class;

    $self->status_message("Executing $class, command object details are:\n" . Data::Dumper::Dumper($command));

    if ($command->execute){
        $self->status_message("Execution of $class complete.");
        return 1;
    }
    else {
        die $self->error_message("Failed to execute $class.");
    }
}

sub upload_fastq_and_unlock {
    my ($self, $fastq, $lock) = @_;
}

sub symlink {
    my $self = shift;
    my ($source, $target) = @_;
    if(-l $target && readlink($target) ne $source) {
        die $self->error_message("$target already exists but points to " . readlink($target));
    }
    elsif(! -l $target) {
        Genome::Utility::FileSystem->create_symlink($source, $target);
    }
}

sub get_bam_and_flagstat_from_build{
    my ($self, $build) = @_;
    my $aln_dir = $build->accumulated_alignments_directory;
    $aln_dir =~ /\/build(\d+)\//;
    my $aln_id = $1;
    my @bam_file = glob("$aln_dir/$aln_id*bam");
    unless (@bam_file){
        $self->error_message("no bam file in alignment directory $aln_dir");
        return;
    }
    if (@bam_file > 1){
        $self->error_message("more than one bam file found in alignment directory $aln_dir");
        return;
    }
    my $bam_file = shift @bam_file;
    my $flagstat_file = "$bam_file.flagstat";
    return ($bam_file, $flagstat_file);
}

# todo move to the model class
sub build_if_necessary_and_wait{
    my ($self, @models) = @_;

    my @builds;
    for my $model (@models) {
        my $build;
        if ($self->need_to_build($model)) {
            $self->status_message("Running build for model ".$model->name);
            $build = $self->run_ref_align_build($model);
            unless ($build) {
                $self->error_message("Couldn't create build for model ".$model->name);
                Carp::confess($self->error_message);
            }
        }
        else {
            $self->status_message("Skipping redundant build");
            $build = $model->last_succeeded_build;
        }
        push @builds, $build;
    }

    for my $build (@builds) {
        $self->wait_for_build($build);
        unless ($build->status eq 'Succeeded') {
            $self->error_message("Failed to execute build (status: ".$build->status.") for model ". $build->model_name);
            Carp::confess($self->error_message);
        }
    }

    return @builds;
}

sub run_ref_align_build {
    my ($self, $model) = @_;
    unless ($model and $model->isa("Genome::Model::ReferenceAlignment")){
        $self->error_message("No ImportedReferenceSequence model passed to run_ref_align_build()");
        return;
    }

    $self->status_message("...creating build");
    my $sub_build = Genome::Model::Build->create(
        model_id => $model->id
    );
    unless ($sub_build){
        $self->error_message("Couldn't create build for underlying ref-align model " . $model->name. ": " . Genome::Model::Build->error_message);
        return;
    }

    $self->status_message("...starting build (w/o job group)");
    UR::Context->commit();
    #TODO update these params to use pp values or wahtevers passes in off command line
    my $rv = $sub_build->start(
        job_dispatch    => 'apipe',
        server_dispatch => 'workflow',
        job_group => undef, # this will not take up one of the 50 slots available to a user
    );

    if ($rv) {
        $self->status_message("Created and started build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
    }
    else {
        $self->error_message("Failed to start build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
    }

    # NOTE: this should really never be done in regular "business logic", but
    # is necessary because we don't have multi-process context stacks working -ss
    $self->status_message("Committing after starting build");
    UR::Context->commit();

    return $sub_build;
}

# TODO: move this to the build class itself
sub wait_for_build {
    my ($self, $build) = @_;
    my $last_status = '';
    my $time = 0;
    my $inc = 30;
    while (1) {
        UR::Context->current->reload($build->the_master_event);
        my $status = $build->status;
        if ($status and !($status eq 'Running' or $status eq 'Scheduled')){
            return 1;
        }

        if ($last_status ne $status or !($time % 300)){
            $self->status_message("Waiting for build(~$time sec) ".$build->id.", status: $status");
        }
        sleep $inc;
        $time += 30;
        $last_status = $status;
    }
}

# TODO: move this to the model class itself
sub need_to_build {
    my ($self, $model) = @_;
    my $build = $model->last_succeeded_build;
    return 1 unless $build;
    my %last_assignments = map { $_->id => $_ } $build->instrument_data_assignments;
    my @current_assignments = $model->instrument_data_assignments;
    if (grep {! $last_assignments{$_->id}} @current_assignments){
        return 1;
    }else{
        return;
    }
}

#this name is maybe not the best
sub _process_sra_instrument_data {
    my ($self, $instrument_data) = @_;
    my $lane = $instrument_data->lane;
    my $instrument_data_id = $instrument_data->id;

    my $tmp_dir = "$UNALIGNED_TEMPDIR/unaligned_reads";
    unless ( -d $tmp_dir or mkdir $tmp_dir) {
        die "Failed to create temp directory $tmp_dir : $!";
    }

    $tmp_dir .= "/$instrument_data_id";
    
    if (-e $tmp_dir) {
        die $self->error_message("Temp directory $tmp_dir already exists?!?!");
    }

    unless (mkdir $tmp_dir) {
        die "Failed to create temp directory $tmp_dir : $!";
    }

    my @instrument_data = eval {

        # TODO: dust, n-remove and set the sub-dir based on the formula
        # and use a subdir name built from that formula
        my $subdir = 'n-remove_'.$self->n_removal_cutoff;
        unless (-d "$tmp_dir/$subdir" or mkdir "$tmp_dir/$subdir") {
            die "Failed to create temp directory $subdir : $!";
        }

        if ($self->dust_unaligned_reads){
            $subdir.='/dusted';
        }

        unless (-d "$tmp_dir/$subdir" or mkdir "$tmp_dir/$subdir") {
            die "Failed to create temp directory $subdir : $!";
        }

        $self->status_message("Preparing imported instrument data for import path $tmp_dir/$subdir");

        # proceed extracting and uploading unaligned reads into $tmp_dir/$subdir....

        # resolve the paths at which we will place processed instrument data
        # we're currently using these paths to find previous unaligned reads processed the same way

        my $forward_basename = "s_${lane}_1_sequence.txt";
        my $reverse_basename = "s_${lane}_2_sequence.txt";
        my $fragment_basename = "s_${lane}_sequence.txt";

        my $expected_path;
        my $expected_path1; #for paired end fastq processing
        my $expected_path2;

        if ($instrument_data->is_paired_end){
            $expected_path1 = "$tmp_dir/$subdir/$forward_basename";
            $expected_path2 = "$tmp_dir/$subdir/$reverse_basename";
            $expected_path = $expected_path1 . ',' . $expected_path2;
        }else{
            $expected_path = "$tmp_dir/$subdir/$fragment_basename";
        }

        my $upload_path;
        my $import_lock;

        # check for previous unaligned reads
        $self->status_message("Checking for previously post-processed and reimported reads from: $expected_path");
        my $post_processed_inst_data = Genome::InstrumentData::Imported->get(original_data_path => $expected_path);
        if ($post_processed_inst_data) {
            $self->status_message("post processed instrument data already found for path $expected_path, skipping");
        }
        else {
            my $lock = basename($expected_path);
            $lock = '/gsc/var/lock/' . $instrument_data_id . '/' . $lock;

            $import_lock = Genome::Utility::FileSystem->lock_resource(
                resource_lock => $lock,
                max_try => 2,
            );
            unless ($import_lock) {
                die $self->error_message("Failed to lock $expected_path.");
            }
            $upload_path = $expected_path;
        }

        unless ($upload_path) {
            $self->status_message("skipping read processing since all data is already processed and uploaded");
            return ($post_processed_inst_data);
        }

        # extract
        $self->status_message("Preparing imported instrument data for import path $expected_path");
        
        my $fastq_filenames = $instrument_data->resolve_fastq_filenames;
        for (@$fastq_filenames){
            unless (-s $_){
                $self->error_message("expected fastq ($_) extracted from instrument data ".$instrument_data->display_name." doesn't have size!");
                die $self->error_message;
            }
        }
        if ($instrument_data->is_paired_end){
            unless (@$fastq_filenames == 2){
                $self->error_message("instrument_data ".$instrument_data->display_name." is paired end but doesn't have 2 fastq files!");
                die $self->error_message;    
            }
            my ($forward) = grep {$_ =~ $forward_basename} @$fastq_filenames;
            my ($reverse) = grep {$_ =~ $reverse_basename} @$fastq_filenames;
            unless($forward and -s $forward and $reverse and -s $reverse){
                $self->error_message("couldn't find expected fastq basenames in ".$instrument_data->display_name);
                die $self->error_message;
            }
            my $processed_fastq1 = $self->_process_unaligned_fastq($forward, $expected_path1);
            my $processed_fastq2 = $self->_process_unaligned_fastq($reverse, $expected_path2);
            my @missing = grep {! -s $_} ($expected_path1, $expected_path2);
            if (@missing){
                $self->error_message("Expected data paths do not exist after fastq processing: ".join(", ", @missing));
                die($self->error_message);
            }
        }else{
            unless (@$fastq_filenames == 1){
                $self->error_message("instrument_data ".$instrument_data->display_name." is not paired end but doesn't have exactly 1 fastq file!"); 
                die $self->error_message;
            }
            my ($fragment) = grep {$_ =~ $fragment_basename} @$fastq_filenames;
            unless ($fragment and -e $fragment){
                $self->error_message("couldn't find expected fastq basename in ".$instrument_data->display_name);
                die $self->error_message;
            }

            my $processed_fastq = $self->_process_unaligned_fastq($fragment, $expected_path);
            unless (-s $expected_path){
                die $self->error_message("Expected data path does not exist after fastq processing: $expected_path");
            }
        }

        # upload
        $self->status_message("uploading new instrument data from the post-processed unaligned reads...");    
        my @properties_from_prior = qw/
        run_name 
        subset_name 
        sequencing_platform 
        median_insert_size 
        sd_above_insert_size
        library_name
        sample_name
        /;
        my @errors;
        my %properties_from_prior;
        for my $property_name (@properties_from_prior) {
            my $value = $instrument_data->$property_name;
            no warnings;
            $self->status_message("Value for $property_name is $value");
            $properties_from_prior{$property_name} = $value;
        }

        if ($upload_path =~ /,/){  #technically this can go in the @properties_prior_array above, but i'm trying to keep as much in common with processed_unaligned_reads as possible to simplify refactoring
            $properties_from_prior{is_paired_end} = 1;
        }else{
            $properties_from_prior{is_paired_end} = 0;
        }
        
        my %params = (
            %properties_from_prior,
            source_data_files => $upload_path,
            import_format => 'illumina fastq',
        );
        if ($self->skip_contamination_screen){
            $params{import_format}='sanger fastq'; #TODO, verify that this quality format is correct for sra/imported sanger instrument data after going through process_unaligned_reads, if so need a better way to choose this
        }
        $self->status_message("importing fastq with the following params:" . Data::Dumper::Dumper(\%params));

        my $command = Genome::InstrumentData::Command::Import::Fastq->create(%params);
        unless ($command) {
            $self->error_message( "Couldn't create command to import unaligned fastq instrument data!");
        };
        my $result = $command->execute();
        unless ($result) {
            die $self->error_message( "Error importing data from $upload_path! " . Genome::InstrumentData::Command::Import::Fastq->error_message() );
        }            
        $self->status_message("committing newly created imported instrument data");
        $DB::single = 1;
        $self->status_message("UR_DBI_NO_COMMIT: ".$ENV{UR_DBI_NO_COMMIT});
        UR::Context->commit(); # warning: most code should NEVER do this in a pipeline

        my $new_instrument_data = Genome::InstrumentData::Imported->get(
            original_data_path => $upload_path
        );
        unless ($new_instrument_data) {
            die $self->error_message( "Failed to find new instrument data $upload_path!");
        }
        if ($new_instrument_data->__changes__) {
            die "Unsaved changes present on instrument data $new_instrument_data->{id} from $upload_path!!!";
        }
        if ($import_lock) {
            unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $import_lock)) {
                die $self->error_message("Failed to unlock $expected_path.");
            }
        }
        return ($new_instrument_data);
    };

    # TODO: add directory removal to Genome::Utility::FileSystem
    if ($@) {
        system "/bin/rm -rf '$tmp_dir'";
        die $self->error_message("Error processing unaligned reads! $@");
    }
    system "/bin/rm -rf '$tmp_dir'";

    return @instrument_data;
}

sub _process_unaligned_reads {
    my ($self, $alignment) = @_;

    my $instrument_data = $alignment->instrument_data;
    my $lane = $instrument_data->lane;
    my $instrument_data_id = $instrument_data->id;

    my $dir = $alignment->output_dir;
    my $bam = $dir . '/all_sequences.bam';
    unless (-e $bam) {
        $self->error_message("Failed to find expected BAM file $bam\n");
        return;
    }

    my $tmp_dir = "$UNALIGNED_TEMPDIR/unaligned_reads";
    unless ( -d $tmp_dir or mkdir $tmp_dir ) {
        die "Failed to create temp directory $tmp_dir : $!";
    }
    $tmp_dir .= "/".$alignment->id;

    if (-e $tmp_dir) {
        die $self->error_message("Temp directory $tmp_dir already exists?!?!");
    }

    unless (mkdir $tmp_dir) {
        die "Failed to create temp directory $tmp_dir : $!";
    }

    my @instrument_data = eval {

        # TODO: dust, n-remove and set the sub-dir based on the formula
        # and use a subdir name built from that formula
        my $subdir = 'n-remove_'.$self->n_removal_cutoff;
        unless (-d "$tmp_dir/$subdir" or mkdir "$tmp_dir/$subdir") {
            die "Failed to create temp directory $subdir : $!";
        }

        if ($self->dust_unaligned_reads){
            $subdir.='/dusted';
        }

        unless (-d "$tmp_dir/$subdir" or mkdir "$tmp_dir/$subdir") {
            die "Failed to create temp directory $subdir : $!";
        }

        # skip uploading if we've already uploaded this alignment data post-processed the same way
        # TODO getting db ORA 00600 errors with this like matching multiple rows, going to skip
        #my @unaligned = Genome::InstrumentData::Imported->get(
        #    "original_data_path like" => "$tmp_dir/$subdir%",
        #
        #if (@unaligned) {
        #    for my $unaligned (@unaligned) {
        #        push @to_add2, $unaligned;
        #    }
        #    $self->status_message("Found previously imported instrument data under generated path \"$tmp_dir/$subdir\"");
        #    next; #SKIP PROCESSING
        #}else{

        $self->status_message("Preparing imported instrument data for import path $tmp_dir/$subdir");

        # proceed extracting and uploading unaligned reads into $tmp_dir/$subdir....

        # resolve the paths at which we will place processed instrument data
        # we're currently using these paths to find previous unaligned reads processed the same way

        my $forward_basename = "s_${lane}_1_sequence.txt";
        my $reverse_basename = "s_${lane}_2_sequence.txt";
        my $fragment_basename = "s_${lane}_sequence.txt";

        my $forward_unaligned_data_path     = "$tmp_dir/$instrument_data_id/$forward_basename";
        my $reverse_unaligned_data_path     = "$tmp_dir/$instrument_data_id/$reverse_basename";
        my $fragment_unaligned_data_path    = "$tmp_dir/$instrument_data_id/$fragment_basename";

        my @expected_original_paths;
        my $expected_data_path0 = "$tmp_dir/$subdir/$fragment_basename";
        my $expected_data_path1 = "$tmp_dir/$subdir/$forward_basename";
        my $expected_data_path2 = "$tmp_dir/$subdir/$reverse_basename";


        my $expected_se_path = $expected_data_path0;
        my $expected_pe_path = $expected_data_path1 . ',' . $expected_data_path2;


        my @upload_paths;
        my ($se_lock, $pe_lock);


        # check for previous unaligned reads
        $self->status_message("Checking for previously imported unaligned and post-processed reads from: $tmp_dir/$subdir");
        my $se_instdata = Genome::InstrumentData::Imported->get(original_data_path => $expected_se_path);
        if ($se_instdata) {
            $self->status_message("imported instrument data already found for path $expected_se_path, skipping");
        }
        else {
            my $lock = basename($expected_se_path);
            $lock = '/gsc/var/lock/' . $instrument_data_id . '/' . $lock;

            $se_lock = Genome::Utility::FileSystem->lock_resource(
                resource_lock => $lock,
                max_try => 2,
            );
            unless ($se_lock) {
                die $self->error_message("Failed to lock $expected_se_path.");
            }
            push @upload_paths, $expected_se_path;
        }

        my $pe_instdata = Genome::InstrumentData::Imported->get(original_data_path => $expected_pe_path);
        if ($pe_instdata) {
            $self->status_message("imported instrument data already found for path $expected_pe_path, skipping");
        }
        else {
            my $lock = basename($expected_pe_path);
            $lock = '/gsc/var/lock/' . $instrument_data_id . '/' . $lock;

            $pe_lock = Genome::Utility::FileSystem->lock_resource(
                resource_lock => "$lock",
                max_try => 2,
            );
            unless ($pe_lock) {
                die $self->error_message("Failed to lock $expected_pe_path.");
            }
            push @upload_paths, $expected_pe_path;
        }

        unless (@upload_paths) {
            $self->status_message("skipping read processing since all data is already processed and uploaded");
            return ($se_instdata, $pe_instdata);
        }

        for my $path (@upload_paths) {
            $self->status_message("planning to upload for $path");
        }

        # extract
        $self->status_message("Preparing imported instrument data for import path $tmp_dir/$subdir");
        my $extract_unaligned = Genome::Model::Tools::BioSamtools::BamToUnalignedFastq->create(
            bam_file => $bam,
            output_directory =>$tmp_dir,
        );
        $self->status_message("Extracting unaligned reads: " . Data::Dumper::Dumper($extract_unaligned));
        my $rv = $extract_unaligned->execute;
        unless ($rv){
            die $self->error_message("Couldn't extract unaligned reads from bam file $bam");
        }
        my @missing = grep {! -e $_} grep { defined($_) and length($_) } ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path);
        if (@missing){
            die $self->error_message(join(", ", @missing)." unaligned files missing after bam extraction");
        }
        $self->status_message("Extracted unaligned reads from bam file(".join(", ", ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path)));

        # process the fragment data
        if (-e $fragment_unaligned_data_path) {
            $self->status_message("processind single-end reads...");
            my $processed_fastq = $self->_process_unaligned_fastq($fragment_unaligned_data_path, $expected_data_path0);
            unless (-e $expected_data_path0){
                die $self->error_message("Expected data path does not exist after fastq processing: $expected_data_path0");
            }
        }

        # process the paired data
        if (-e $forward_unaligned_data_path or -e $reverse_unaligned_data_path) {
            $self->status_message("processind paired-end reads...");
            unless (-e $forward_unaligned_data_path and -e $reverse_unaligned_data_path) {
                die "Missing forward and reverse unaligned data?";
            }
            my $processed_fastq1 = $self->_process_unaligned_fastq($forward_unaligned_data_path, $expected_data_path1);
            my $processed_fastq2 = $self->_process_unaligned_fastq($reverse_unaligned_data_path, $expected_data_path2);
            my @missing = grep {! -e $_} ($expected_data_path1, $expected_data_path2);
            if (@missing){
                $self->error_message("Expected data paths do not exist after fastq processing: ".join(", ", @missing));
                Carp::confess($self->error_message);
            }
        }

        # upload
        $self->status_message("uploading new instrument data from the post-processed unaligned reads...");    
        my @properties_from_prior = qw/
        run_name 
        subset_name 
        sequencing_platform 
        median_insert_size 
        sd_above_insert_size
        library_name
        sample_name
        /;
        my @errors;
        my %properties_from_prior;
        for my $property_name (@properties_from_prior) {
            my $value = $instrument_data->$property_name;
            no warnings;
            $self->status_message("Value for $property_name is $value");
            $properties_from_prior{$property_name} = $value;
        }

        my @instrument_data;
        for my $original_data_path (@upload_paths) {
            if ($original_data_path =~ /,/){
                $properties_from_prior{is_paired_end} = 1;
            }else{
                $properties_from_prior{is_paired_end} = 0;
            }
            #my $previous = Genome::InstrumentData::Imported->get(
            #    original_data_path => $original_data_path,
            #);
            my $previous;
            if ($previous){
                $self->error_message("imported instrument data already found for path $original_data_path????");
                Carp::confess($self->error_message);
                #push @instrument_data, $previous;
                #next;
            }
            my %params = (
                %properties_from_prior,
                source_data_files => $original_data_path,
                import_format => 'illumina fastq',
            );
            $self->status_message("importing fastq with the following params:" . Data::Dumper::Dumper(\%params));


            my $command = Genome::InstrumentData::Command::Import::Fastq->create(%params);
            unless ($command) {
                $self->error_message( "Couldn't create command to import unaligned fastq instrument data!");
            };
            my $result = $command->execute();
            unless ($result) {
                die $self->error_message( "Error importing data from $original_data_path! " . Genome::InstrumentData::Command::Import::Fastq->error_message() );
            }            
            $self->status_message("committing newly created imported instrument data");
            $DB::single = 1;
            $self->status_message("UR_DBI_NO_COMMIT: ".$ENV{UR_DBI_NO_COMMIT});
            UR::Context->commit(); # warning: most code should NEVER do this in a pipeline

            my $instrument_data = Genome::InstrumentData::Imported->get(
                original_data_path => $original_data_path
            );
            unless ($instrument_data) {
                die $self->error_message( "Failed to find new instrument data $original_data_path!");
            }
            if ($instrument_data->__changes__) {
                die "Unsaved changes present on instrument data $instrument_data->{id} from $original_data_path!!!";
            }
            if ($se_lock) {
                unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $se_lock)) {
                    die $self->error_message("Failed to unlock $expected_se_path.");
                }
            }
            if ($pe_lock) {
                unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $pe_lock)) {
                    die $self->error_message("Failed to unlock $expected_pe_path.");
                }
            }
            push @instrument_data, $instrument_data;
        }        
        return @instrument_data;
    };

    # TODO: add directory removal to Genome::Utility::FileSystem
    if ($@) {
        system "/bin/rm -rf '$tmp_dir'";
        die $self->error_message("Error processing unaligned reads! $@");
    }
    system "/bin/rm -rf '$tmp_dir'";

    return @instrument_data;
}

sub _process_unaligned_fastq {
    my $self = shift;
    my ($fastq_file, $output_path) = @_;
    my ($sep_file, $qual_file) = ("$fastq_file.sep", "$fastq_file.qual");

    # run n-removal
    my $n_removed_fastq = $fastq_file;
    $n_removed_fastq=$fastq_file.".".$self->n_removal_cutoff."NREMOVED";
    unlink $n_removed_fastq if -e $n_removed_fastq;
    if ($self->n_removal_cutoff){
        $self->status_message("Running n-removal on file $fastq_file");
        Genome::Model::Tools::Fastq::RemoveN->execute(
            fastq_file => $fastq_file,
            n_removed_file => $n_removed_fastq,
            cutoff => $self->n_removal_cutoff,
        ); 
    }
    else {
        $self->status_message("No n-removal cutoff specified, skipping");
        unless ( rename($fastq_file, $n_removed_fastq)){
            $self->error_message("Failed to copy $fastq_file to $n_removed_fastq while skipping n-removal");
            return;
        }
    }

    # run dust   
    # 1. produce fasta file 

    my $fasta_file = $fastq_file.".FASTA";
    unlink $fasta_file if -e $fasta_file;

    my $dusted_file = $fasta_file.".DUSTED";
    unlink $dusted_file if -e $dusted_file;

    my $n_removed_dusted_length_screened_fastq =$fastq_file.".PROCESSED";
    unlink $n_removed_dusted_length_screened_fastq if -e $n_removed_dusted_length_screened_fastq;

    if ($self->dust_unaligned_reads){
        $self->status_message("Running dust on $n_removed_fastq");

        my $fastq_input_fh  = Genome::Utility::FileSystem->open_file_for_reading($n_removed_fastq);
        unless ($fastq_input_fh) {
            $self->error_message('Failed to open fastq file ' . $n_removed_fastq . ": $!");
            return;
        }
        binmode $fastq_input_fh, ":utf8";

        my $fasta_output_fh = Genome::Utility::FileSystem->open_file_for_writing($fasta_file);
        unless ($fasta_output_fh) {
            $self->error_message('Failed to open output file ' . $fasta_file . ": $!");
            return;
        }
        binmode $fasta_output_fh, ":utf8";

        my $sep_output_fh = Genome::Utility::FileSystem->open_file_for_writing($sep_file);
        unless ($sep_output_fh) {
            $self->error_message('Failed to open output file ' . $sep_file . ": $!");
        }
        binmode $sep_output_fh, ":utf8";

        my $qual_output_fh = Genome::Utility::FileSystem->open_file_for_writing($qual_file);
        unless ($qual_output_fh) {
            $self->error_message('Failed to open output file ' . $qual_file . ": $!");
            return;
        }
        binmode $qual_output_fh, ":utf8";

        while (my $header = $fastq_input_fh->getline) {
            my $seq  = $fastq_input_fh->getline;
            my $sep  = $fastq_input_fh->getline;
            my $qual = $fastq_input_fh->getline;

            unless (substr($header,0,1) eq '@') {
                die "Unexpected header in fastq! $header";
            }
            substr($header,0,1) = '>';

            $fasta_output_fh->print($header, $seq);
            $sep_output_fh->print($sep);
            $qual_output_fh->print($qual);
        }

        $fastq_input_fh->close;
        $fasta_output_fh->close;
        $sep_output_fh->close; $sep_output_fh = undef;
        $qual_output_fh->close; $qual_output_fh = undef;

        #2. run dust command
        my $cmd = "dust $fasta_file > $dusted_file";
        my $rv = system($cmd);

        #3. re-produce fastq 

        my $dusted_input_fh  = Genome::Utility::FileSystem->open_file_for_reading($dusted_file);
        unless ($dusted_input_fh) {
            $self->error_message('Failed to open fastq file ' . $dusted_file . ": $!");
            return;
        }
        binmode $dusted_input_fh, ":utf8";

        my $sep_input_fh = Genome::Utility::FileSystem->open_file_for_reading($sep_file);
        unless ($sep_input_fh) {
            $self->error_message('Failed to open input file ' . $sep_file . ": $!");
        }
        binmode $sep_input_fh, ":utf8";

        my $qual_input_fh = Genome::Utility::FileSystem->open_file_for_reading($qual_file);
        unless ($qual_input_fh) {
            $self->error_message('Failed to open input file ' . $qual_file . ": $!");
            return;
        }
        binmode $qual_input_fh, ":utf8";

        my $processed_fh = Genome::Utility::FileSystem->open_file_for_writing($n_removed_dusted_length_screened_fastq);
        unless ($processed_fh) {
            $self->error_message('Failed to open output file ' . $n_removed_dusted_length_screened_fastq . ": $!");
            return;
        }
        binmode $processed_fh, ":utf8";

        # since dusting wraps sequences, may have to read multiple lines to reconstruct sequence
        # pull header then concat lines until next header encountered
        my ($header, $seq, $sep, $qual);
        while (my $line = $dusted_input_fh->getline) {
            if ($line=~/^>.*/) { #found a header 
                # this only grabs the header on the first sequence
                # other sequences in the file will have their header pre-caught below
                # confusing :(
                $header = $line;
            }
            else {
                chomp($seq .= $line);
                #$seq .= $line;
            }

            while ($line = $dusted_input_fh->getline) { #accumulate lines for read, until next header encountered 
                if ($line=~/^>.*/) { #found a new header - read has been accumulated 
                    last;
                }
                else {
                    chomp($seq .= $line);
                    #$seq .= $line;
                }
            }

            $sep = $sep_input_fh->getline;
            $qual = $qual_input_fh->getline;

            unless (substr($header,0,1) eq '>') {
                die "Unexpected fasta header: $header";
            }
            substr($header,0,1) = '@';
            $processed_fh->print("$header$seq\n$sep$qual");

            #reset
            $seq = '';
            $header = $line;
        }


        $dusted_input_fh->close;
        $sep_input_fh->close;
        $qual_input_fh->close;
        $processed_fh->close;
    }
    else {
        $self->status_message("Dusting not required, skipping on $n_removed_fastq");
        unless( rename($n_removed_fastq, $n_removed_dusted_length_screened_fastq)){
            $self->error_message("Failed to copy $n_removed_fastq to $n_removed_dusted_length_screened_fastq while skipping dusting");
            return;
        }
    }

    # kill intermediate files
    for my $file($fasta_file, $n_removed_fastq, $dusted_file, $qual_file, $sep_file) {
        unlink($file) if -e $file;
    }

    #screen out <60bp reads, do this last? don't know what to do about mate pairs
    rename($n_removed_dusted_length_screened_fastq, $output_path);
    $self->status_message("Finished processing on $output_path");
    return $output_path;

}

1;
