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


sub _execute_build {
    my ($self, $build) = @_;

    my $model = $build->model;
    my $rv;

    # temp hack for debugging
    my $log_model_name = $model->name;
    $self->status_message("Starting build for model $log_model_name");

    my $screen_model = $model->_contamination_screen_alignment_model;
    unless ($screen_model) {
        $self->error_message("couldn't grab contamination screen underlying model!");
        return;
    }

    # ENSURE WE HAVE INSTRUMENT DATA
    my @assignments = $model->instrument_data_assignments;
    if (@assignments == 0) {
        $self->error_message("NO INSTRUMENT DATA ASSIGNED!");
        die $self->error_message();
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
    my ($screen_build) = $self->build_if_necessary_and_wait($screen_model);

    # POST-PROCESS THE UNALIGNED READS FROM THE CONTAMINATION SCREEN MODEL
    $self->status_message("Processing and importing instrument data for any new unaligned reads");
    my @screened_assignments = $screen_model->instrument_data_assignments;
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

    # ASSIGN THE POST-PROCESSED READS TO THE METAGENOMIC MODELS
    my @metagenomic_models = $model->_metagenomic_alignment_models;
    for my $metagenomic_model (@metagenomic_models) {
        my %assignments_expected;
        for my $n (0..$#post_processed_unaligned_reads) {
            my $prev_assignment = $screened_assignments[$n];
            my $post_processed_instdata_for_prev_assignment = $post_processed_unaligned_reads[$n];
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

    $DB::single = 1;
    # SYMLINK ALIGNMENT FILES TO BUILD DIRECTORY
    my $data_directory = $build->data_directory;
    my ($screen_bam, $screen_flagstat) = $self->get_bam_and_flagstat_from_build($screen_build);

    unless ($screen_bam and $screen_flagstat and -e $screen_bam and -e $screen_flagstat){
        $self->error_message("Bam or flagstat doesn't exist for contamination screen build");
        die;
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
            $self->error_message("Bam or flagstat doesn't exist for metagenomic alignment build $counter");
            die;
        }
        $self->symlink($meta_bam, "$data_directory/metagenomic_alignment$counter.bam");
        $self->symlink($meta_flagstat, "$data_directory/metagenomic_alignment$counter.bam.flagstat");
    }

    # REPORTS

    # TODO: Where should these go? build directory or /gscmnt/sata849/info/hmp-july2010?
    # Sounds like Craig would like these to go in the database.
    $rv = Genome::Model::MetagenomicCompositionShotgun::Command::QcReport->execute(
        build_id => $build->id,
        base_output_dir => $build->data_directory
    );
    unless($rv) {
        $self->error_message("QC report execution did not return 1");
        die;
    }
    
    # TODO: Where should these go? build directory or /gscmnt/sata835/info/medseq/hmp-july2010?
    # TODO: Should we move the taxonomy files into the repo?
    $rv = Genome::Model::MetagenomicCompositionShotgun::Command::MetagenomicReport->execute(
        build_id => $build->id,
        base_output_dir => $build->data_directory,
        taxonomy_file => '/gscmnt/sata409/research/mmitreva/databases/Bact_Arch_Euky.taxonomy.txt',
        viral_taxonomy_file => '/gscmnt/sata409/research/mmitreva/databases/viruses_taxonomy_feb_25_2010.txt',
    );
    unless($rv) {
        $self->error_message("metagenomic report execution did not return 1");
        die;
    }
    

    return 1;
}

sub symlink {
    my $self = shift;
    my ($source, $target) = @_;
    if(-l $target && readlink($target) ne $source) {
        $self->error_message("$target already exists but points to " . readlink($target));
        die $self->error_message();
    }
    elsif(! -l $target) {
        Genome::Utility::FileSystem->create_symlink($source, $target);
    }
}

sub get_bam_and_flagstat_from_build{
    my ($self, $build) = @_;
    my $aln_dir = $build->accumulated_alignments_directory;
    my @bam_file = glob("$aln_dir/*bam");
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

    $self->status_message("...starting build");
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

#sub record_unaligned_reads_for_instrument_data {
#    my ($self, $build, $instrument_data_id, $files) = @_;
#
#    my $path = $build->data_directory . '/' . $instrument_data_id;
#    my $record = Genome::Utility::FileSystem->open_file_for_writing($path);
#
#    for my $file (@$files) {
#        my $fh = Genome::Utility::FileSystem->open_file_for_read($file);
#        my $line = $fh->getline;
#        my ($read_name) = $line =~ /^@(\S)+/;
#        next unless $read_name;
#        $record->print("$read_name\n");
#    }
#}

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
    unless (-d $tmp_dir or mkdir $tmp_dir) {
        die "Failed to create temp directory $tmp_dir : $!";
    }

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
    my $expected_data_path0 = $tmp_dir . '/' . $subdir . "/$fragment_basename";
    my $expected_data_path1 = $tmp_dir . '/' . $subdir . "/$forward_basename";
    my $expected_data_path2 = $tmp_dir . '/' . $subdir . "/$reverse_basename";

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
            $self->error_message("Failed to lock $expected_se_path.");
            die $self->error_message;
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
            $self->error_message("Failed to lock $expected_pe_path.");
            die $self->error_message;
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
        $self->error_message("Couldn't extract unaligned reads from bam file $bam");
        return;
    }
    my @missing = grep {! -e $_} grep { defined($_) and length($_) } ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path);
    if (@missing){
        $self->error_message(join(", ", @missing)." unaligned files missing after bam extraction");
        return;
    }
    $self->status_message("Extracted unaligned reads from bam file(".join(", ", ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path)));

    #$self->record_unaligned_reads_for_instrument_data($build, $instrument_data->id, [$forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path]);


    # process the fragment data
    if (-e $fragment_unaligned_data_path) {
        $self->status_message("processind single-end reads...");
        my $processed_fastq = $self->_process_unaligned_fastq($fragment_unaligned_data_path, $expected_data_path0);
        unless (-e $expected_data_path0){
            $self->error_message("Expected data path does not exist after fastq processing: $expected_data_path0");
            return;
        }
    }

    # process the paired data
    if (-e $forward_unaligned_data_path or -e $reverse_unaligned_data_path) {
        $self->status_message("processind paired-end reads...");
        unless (-e $forward_unaligned_data_path and -e $reverse_unaligned_data_path) {
            die;
        }
        my $processed_fastq1 = $self->_process_unaligned_fastq($forward_unaligned_data_path, $expected_data_path1);
        my $processed_fastq2 = $self->_process_unaligned_fastq($reverse_unaligned_data_path, $expected_data_path2);
        my @missing = grep {! -e $_} ($expected_data_path1, $expected_data_path2);
        if (@missing){
            $self->error_message("Expected data paths do not exist after fastq processing: ".join(", ", @missing));
            Carp::confess($self->error_message);
        }
    }

    $DB::single = 1;

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
        );
        $self->status_message("importing fastq with the following params:" . Data::Dumper::Dumper(\%params));


        my $command = Genome::InstrumentData::Command::Import::Fastq->create(%params);
        unless ($command) {
            $self->error_message( "Couldn't create command to import unaligned fastq instrument data!");
        };
        my $result = $command->execute();
        unless ($result) {
            $self->error_message( "Error importing data from $original_data_path! " . Genome::InstrumentData::Command::Import::Fastq->error_message() );
            return;
        }            
        $self->status_message("committing newly created imported instrument data");
        $DB::single = 1;
        $self->status_message("UR_DBI_NO_COMMIT: ".$ENV{UR_DBI_NO_COMMIT});
        UR::Context->commit();

        my $instrument_data = Genome::InstrumentData::Imported->get(
            original_data_path => $original_data_path
        );
        unless ($instrument_data) {
            $self->error_message( "Failed to find new instrument data $original_data_path!");
            return;
        }
        if ($instrument_data->__changes__) {
            die "Unsaved changes present on instrument data $instrument_data->{id} from $original_data_path!!!";
        }

        unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $se_lock)) {
            $self->error_message("Failed to unlock $expected_se_path.");
            die $self->error_message;
        }
        unless(Genome::Utility::FileSystem->unlock_resource(resource_lock => $pe_lock)) {
            $self->error_message("Failed to unlock $expected_pe_path.");
            die $self->error_message;
        }

        push @instrument_data, $instrument_data;
    }        

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
