package Genome::ProcessingProfile::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sys::Hostname;
use Data::Dumper;

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
        n_removal_threshold => {
            is => 'Integer',
            default_value => 0,
            doc => "Reads with this amount of n's will be removed from unaligned reads from contamination screen step before before optional dusting",
        },
        non_n_base_threshold => {
            is => 'Int',
            doc => 'reads with less than this amount of non-n bases will be removed in post-processing',
            default => 0,
        },
        mismatch_cutoff => {
            is => 'Integer',
            default_value=> 0,
            doc => 'mismatch cutoff (including softclip) for post metagenomic alignment processing',
        },
        skip_contamination_screen => {
            is => 'Boolean',
            default_value => 0,
            doc => "If this flag is enabled, the instrument data assigned to this model will not be human screened, but will undergo dusting and n-removal before undergoing metagenomic alignment",
        },
        include_taxonomy_report => {
            is => 'Boolean',
            default_value => 1,
            doc => 'When this flag is enabled, the model will attempt to grab taxonomic data for the metagenomic reports and produce a combined refcov-taxonomic final report.  Otherwise, only refcov will be run on the final metagenomic bam',
        },
        skip_qc_on_untrimmed_reads => {
            is => 'Boolean',
            default_value => 0,
            doc => "If this flag is specified, QC report will skip metric on the human-free, untrimmed data.",
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
    my ($self, $build) = @_;
    my @instrument_data = $build->instrument_data;
    my $tmp = 30000 + 5000 * (1 + scalar(@instrument_data));
    return "-R 'select[model!=Opteron250 && type==LINUX64] rusage[tmp=$tmp:mem=16000]' -M 16000000";
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
                $screen_model->add_instrument_data(
                    value => $instrument_data,
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
        my @sra_assignments = $build->instrument_data_assignments; 
        for my $assignment(@sra_assignments){
            my @post_processed_reads = $self->_process_sra_instrument_data($assignment->instrument_data);
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
    $DB::single = 1;
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
                    $DB::single = 1;
                    $metagenomic_assignment = 
                    $metagenomic_model->add_instrument_data(
                        value => $instrument_data,
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

        #TODO  When a model with skip_contamination_screen restarts, the potential extra fragment instrument data from n-removal will not be returned from _process_sra_data, and therefore won't be an expected assignment, so we'll need to check if the extra assignment's source_data_files contains(is derived from) the original instrument data assigned to the model. tldr: don't break on skip_contamination_restarts if extra inst_data looks legit.
        my @mcs_instrument_data_ids = map {$_->id} $build->instrument_data;

        # ensure there are no other odd assignments on the model besides those expected
        # this can happen if instrument-data is re-processed (deleted)
        $DB::single=1;
        for my $assignment ($metagenomic_model->instrument_data_assignments) {
            unless ($assignments_expected{$assignment->id}) {
                my $instrument_data = $assignment->instrument_data;
                if ($instrument_data) {
                    my ($derived_from) = $instrument_data->original_data_path =~ m{^/tmp/(?:unaligned_reads/)?(\d+)}; 
                    #if unaligned reads is in the data path, the id may be an instrument data id(deprecated way of storing original data path), or an alignment result id, here we will figure out which and return the derived from instrument data id
                    my $inst_data = Genome::InstrumentData->get($derived_from);
                    unless($inst_data){
                        my $alignment =Genome::InstrumentData::AlignmentResult->get($derived_from);
                        unless ($alignment){
                            die $self->error_message("Couldn't determine derived_from instrument data id from original data path ".$instrument_data->original_data_path);
                        }
                        $derived_from = $alignment->instrument_data->id;
                    }
                    unless (grep {$derived_from eq $_} @mcs_instrument_data_ids){
                        $self->error_message(
                            "Odd assignment found on model " 
                            . $metagenomic_model->__display_name__ 
                            . " for instrument data " 
                            . $instrument_data->__display_name__
                        );
                        Carp::confess($self->error_message);
                    }
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
    unless ($self->skip_contamination_screen){
        my ($screen_bam, $screen_flagstat) = $self->get_bam_and_flagstat_from_build($screen_build);

        unless ($screen_bam and $screen_flagstat){ 
            die $self->error_message("Bam or flagstat undefined for contamination screen build(screen bam: $screen_bam, screen flagstat: $screen_flagstat) ");
        }
        unless (-e $screen_bam and -e $screen_flagstat){
            die $self->error_message("Bam or flagstat doesn't exist for contamination screen build(screen bam: $screen_bam, screen flagstat: $screen_flagstat) ");
        }
        $self->symlink($screen_bam, "$data_directory/contamination_screen.bam");
        $self->symlink($screen_flagstat, "$data_directory/contamination_screen.bam.flagstat");
    }

    my $counter;
    my @meta_bams;
    for my $meta_build (@metagenomic_builds){
        $counter++;
        my ($meta_bam, $meta_flagstat) = $self->get_bam_and_flagstat_from_build($meta_build);
        push @meta_bams, $meta_bam;

        unless ($meta_bam and $meta_flagstat){ 
            die $self->error_message("Bam or flagstat undefined for metagenomic alignemnt build $counter(meta bam: $meta_bam, meta flagstat: $meta_flagstat) ");
        }
        unless (-e $meta_bam and -e $meta_flagstat){
            die $self->error_message("Bam or flagstat doesn't exist for metagenomic alignment build $counter(meta bam: $meta_bam, meta flagstat: $meta_flagstat) ");
        }

        $self->symlink($meta_bam, "$data_directory/metagenomic_alignment$counter.bam");
        $self->symlink($meta_flagstat, "$data_directory/metagenomic_alignment$counter.bam.flagstat");
    }

    # REPORTS

    # enable "verbose" logging so we can actually see status messages from these methods
    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    unless ($self->skip_contamination_screen){
        my $qc_report = Genome::Model::MetagenomicCompositionShotgun::Command::QcReport->create(
            build_id => $build->id,
            skip_qc_on_untrimmed_reads => $self->skip_qc_on_untrimmed_reads,
        );
        unless($qc_report->execute()) {
            die $self->error_message("Failed to create QC report!");
        }
    }

    my $final_metagenomic_bam = $build->_final_metagenomic_bam();
    if (@meta_bams > 1){
        $final_metagenomic_bam = $self->merge_metagenomic_bams(\@meta_bams, $final_metagenomic_bam);
    }else{
        $self->symlink($meta_bams[0], $final_metagenomic_bam);
    }

    #TODO, these taxonomic files need to be retrieved from to one or all metagenomic references

    my %meta_report_properties = (
        build_id => $build->id,
    );

    if ($self->skip_contamination_screen){
        $meta_report_properties{include_fragments} = 1; 
    }

    if ($self->include_taxonomy_report){
        $meta_report_properties{include_taxonomy_report} = 1;
        $meta_report_properties{taxonomy_file} = '/gscmnt/sata409/research/mmitreva/databases/Bact_Arch_Euky.taxonomy.txt';
        $meta_report_properties{viral_taxonomy_file} = '/gscmnt/sata409/research/mmitreva/databases/viruses_taxonomy_feb_25_2010.txt';
    }

    my $meta_report = Genome::Model::MetagenomicCompositionShotgun::Command::MetagenomicReport->create(
        %meta_report_properties,
    );
    unless($meta_report->execute()) {
        die $self->error_message("metagenomic report execution died or did not return 1:$@");
    }

    unless($self->skip_contamination_screen){ #TODO: update validate to deal with this arg
        my $validate_build = Genome::Model::MetagenomicCompositionShotgun::Command::Validate->create(build_id => $build->id);
        unless($validate_build->execute()) {
            die $self->error_message("Failed to validate build!");
        }
    }

    return 1;
}

sub merge_metagenomic_bams{
    my ($self, $meta_bams, $sorted_bam) = @_;
    if (-e $sorted_bam and -e $sorted_bam.".OK"){  
        $self->status_message("sorted metagenomic merged bam already produced, skipping");
    }else{
        my $merged_bam = $sorted_bam.".name_sorted.bam";
        $self->status_message("starting sort and merge");

        my $sort_and_merge_meta = Genome::Model::Tools::Sam::SortAndMergeSplitReferenceAlignments->create(
            input_files => $meta_bams,
            output_file => $merged_bam,
        );
        unless($sort_and_merge_meta->execute()) {
            die $self->error_message("Failed to sort and merge metagenomic bams: $@");
        }

        unless (-s $merged_bam){
            die $self->error_message("Merged bam has no size!");
        }

        $self->status_message("starting position sort of merged bam");

        my $sort_merged_bam = Genome::Model::Tools::Sam::SortBam->create(
            file_name => $merged_bam,
            output_file => $sorted_bam,
        );
        unless($sort_merged_bam->execute()) {
            die $self->error_message("Failed to position sort merged metagenomic bam.");
        }

        unless (-s $sorted_bam){
            die $self->error_message("Sorted bam has no size!");
        }

        system ("touch $sorted_bam.OK");
        unlink $merged_bam;
    }
    return $sorted_bam;
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
                unless(Genome::Sys->unlock_resource(resource_lock => $lock)) {
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
    my $lock = Genome::Sys->lock_resource(
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

sub assign_missing_instrument_data_to_model{
    my ($self, $model, @instrument_data) = shift;
}

sub symlink {
    my $self = shift;
    my ($source, $target) = @_;
    if(-l $target && readlink($target) ne $source) {
        die $self->error_message("$target already exists but points to " . readlink($target));
    }
    elsif(! -l $target) {
        Genome::Sys->create_symlink($source, $target);
    }
}

sub get_bam_and_flagstat_from_build{
    my ($self, $build) = @_;
    $self->status_message("getting bam and flagstat from build: ".$build->id);

    #we have to try two different methods to find the merged bam, one uses the <picard software result id>.bam which is the new way, and the old uses the <build_id>.bam

    my @swus = Genome::SoftwareResult::User->get(user_id=>$build->id);

    my @software_results = grep { ref($_) eq "Genome::InstrumentData::AlignmentResult::Merged" } Genome::SoftwareResult->get(id=>[map {$_->software_result_id} @swus]);

    if (scalar @software_results > 1) {
        die $self->error_message("Found more than one merged bam alignment software result for metagenomic alignment build ".$build->id);
    }
    my $alignment = shift @software_results;
    my $alignment_file;
    my $alignment_dir;
    if ($alignment){
        $alignment_dir = $alignment->output_dir;
        $alignment_file = $alignment_dir . "/" . $alignment->id . ".bam";
        unless (-e $alignment_file){
            die $self->error_message("merged bam ($alignment_file) for build ".$build->id." from software result doesn't exist");
        }
    }else{
        #try old method
        $alignment_dir = $build->accumulated_alignments_directory;
        my $build_id = $build->id;
        my @alignment_file = glob("$alignment_dir/$build_id*bam");
        unless (@alignment_file){
            die $self->error_message("no bam file in alignment directory $alignment_dir");
        }
        if (@alignment_file > 1){
            die $self->error_message("more than one bam file found in alignment directory $alignment_dir");
        }
        $alignment_file = shift @alignment_file;
        unless (-e $alignment_file){
            die $self->error_message("Failed to find bam for build ".$build->id." in alignments dir $alignment_dir");
        }
    } 

    my $flagstat_file = "$alignment_file.flagstat";
    unless (-e $flagstat_file){
        die $self->error_message("Failed to flagstat for build ".$build->id." in alignments dir $alignment_dir");
    }
    return ($alignment_file, $flagstat_file);
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
            $self->status_message("Skipping redundant build for model ".$model->name);
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
    my $sub_build = $model->create_build(
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
    unless ($build) {
        $self->status_message("No build found for ".$model->name."; need to build.");
        return 1;
    }
    $self->status_message("Found build: ".$build->__display_name__);
    my @build_assignments = sort {$a cmp $b} $build->instrument_data_assignments;
    my @model_assignments = sort {$a cmp $b} $model->instrument_data_assignments;

    if (@build_assignments ne @model_assignments) {
        $self->status_message("Assignment count does not match, build has ".scalar(@build_assignments)." but model has ".scalar(@model_assignments)."; need to build.");
        return 1;
    }
    # Check for missing_first_build_id due to bug in UR caching
    for (my $i = 0; $i < @model_assignments; $i++) {
        my $build_assignment = $build_assignments[$i];
        my $model_assignment = $model_assignments[$i];

        if (!$model_assignment->first_build_id) {
            $self->status_message("Model has assignments without corresponding build; need to build.");
            return 1;
        }
        if ($build_assignment->id ne $model_assignment->id) {
            $self->status_message("Missing instrument data assignment; need to build.");
            return 1;
        }
    }

    $self->status_message("Build for ".$model->name." exists and all (".scalar(@model_assignments).") instrument data assignments match; no need to build.");
    return 0;
}

#this name is maybe not the best
sub _process_sra_instrument_data {
    my ($self, $instrument_data) = @_;
    my $lane = $instrument_data->lane;

    my %params;
    $params{instrument_data} = $instrument_data;
    $params{n_removal_threshold} = $self->n_removal_threshold if $self->n_removal_threshold;
    $params{non_n_base_threshold} = $self->non_n_base_threshold if $self->non_n_base_threshold;
    $params{dust} = $self->dust_unaligned_reads if $self->dust_unaligned_reads;

    my $cmd = Genome::InstrumentData::Command::PostProcessAndImport->create(%params);
    unless($cmd){
        die $self->error_message("Couldn't create PostProcessAndImport command for instrument data ".$instrument_data->id);
    }
    my $rv = $cmd->execute;
    unless ($rv){
        die $self->error_message("Couldn't execute PostProcessAndImport command for instrument data ".$instrument_data->id);
    }

    my @instrument_data = $cmd->post_processed_instrument_data();

    unless (@instrument_data){
        die $self->error_message("No post-processed instrument data returned as output from PostProcessAndImport command for instrument data ". $instrument_data->id);
    }

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
    $tmp_dir .= "/".$alignment->id;
    my @instrument_data = eval {
        my $subdir = 'n-remove_'.$self->n_removal_threshold;
        if ($self->dust_unaligned_reads){
            $subdir.='/dusted';
        }
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

            $self->status_message("Creating lock on $lock...");
            $se_lock = Genome::Sys->lock_resource(
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
        elsif ( $instrument_data->is_paired_end ) {
            my $lock = basename($expected_pe_path);
            $lock = '/gsc/var/lock/' . $instrument_data_id . '/' . $lock;

            $self->status_message("Creating lock on $lock...");
            $pe_lock = Genome::Sys->lock_resource(
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
            return grep { defined } ($se_instdata, $pe_instdata);
        }

        for my $path (@upload_paths) {
            $self->status_message("planning to upload for $path");
        }

        # extract
        my $create_directory = eval{ Genome::Sys->create_directory($tmp_dir.'/'.$subdir); };
        if ( not $create_directory ) {
            die "Failed to create tmp directory ($tmp_dir/$subdir): $@";
        }
        $self->status_message("Preparing imported instrument data for import path $tmp_dir/$subdir");
        $self->status_message("Extracting unaligned reads from $bam");
        my $cmd = "gmt5.12.1 bio-samtools bam-to-unaligned-fastq --bam-file $bam --output-directory $tmp_dir";
        my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
        if ( not $rv ) {
            die "Failed to extract unaligned reads: $@";
        }

        #$self->status_message("Perl version: $]");
        #my $extract_unaligned = Genome::Model::Tools::BioSamtools::BamToUnalignedFastq->create(
        #    bam_file => $bam,
        #    output_directory =>$tmp_dir,
        #);
        #my $rv = $extract_unaligned->execute;
        #unless ($rv){
        #    die $self->error_message("Couldn't extract unaligned reads from bam file $bam");
        #}

        my @expected_output_fastqs = ( $instrument_data->is_paired_end )
        ?  ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path)
        :  ($fragment_unaligned_data_path);
        my @missing = grep {! -e $_} grep { defined($_) and length($_) } @expected_output_fastqs;
        if (@missing){
            die $self->error_message(join(", ", @missing)." unaligned files missing after bam extraction");
        }
        $self->status_message("Extracted unaligned reads from bam file (@expected_output_fastqs)");

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
            $self->status_message("Attempting to upload $original_data_path...");
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

            my $new_instrument_data = Genome::InstrumentData::Imported->get($command->generated_instrument_data_id);
            unless ($new_instrument_data) {
                die $self->error_message( "Failed to find new instrument data $original_data_path!");
            }
            if ($new_instrument_data->__changes__) {
                die "Unsaved changes present on instrument data $new_instrument_data->{id} from $original_data_path!!!";
            }
            if (!$new_instrument_data->is_paired_end && $se_lock) {
                $self->status_message("Attempting to remove lock on $se_lock...");
                unless(Genome::Sys->unlock_resource(resource_lock => $se_lock)) {
                    die $self->error_message("Failed to unlock $se_lock.");
                }
                undef($se_lock);
            }
            if ($new_instrument_data->is_paired_end && $pe_lock) {
                $self->status_message("Attempting to remove lock on $pe_lock...");
                unless(Genome::Sys->unlock_resource(resource_lock => $pe_lock)) {
                    die $self->error_message("Failed to unlock $pe_lock.");
                }
                undef($pe_lock);
            }
            push @instrument_data, $new_instrument_data;
        }        
        return @instrument_data;
    };

    system "/bin/rm -rf $tmp_dir";

    if ( not @instrument_data ) {
        die $self->error_message("Error processing unaligned reads!");
    }

    return @instrument_data;
}

sub _process_unaligned_fastq_pair {
    my $self = shift;
    my ($forward, $reverse, $forward_out, $reverse_out, $fragment_out) = @_;
    #run dust on forward and reverse
    my $forward_dusted;
    my $reverse_dusted;

    if ($self->dust_unaligned_reads){
        $self->status_message("Dusting fastq pair $forward, $reverse");
        $forward_dusted = "$forward.DUSTED";
        $reverse_dusted = "$reverse.DUSTED";

        $self->dust_fastq($forward, $forward_dusted);
        $self->dust_fastq($reverse, $reverse_dusted);
    }else{
        $self->status_message("skipping dusting");
        $forward_dusted = $forward;
        $reverse_dusted = $reverse;
    }

    #run pairwise n-removal
    if ($self->n_removal_threshold){
        $self->status_message("running remove-n-pairwise on $forward, $reverse");
        my $cmd = Genome::Model::Tools::Fastq::RemoveNPairwise->create(
            forward_fastq => $forward_dusted,
            reverse_fastq => $reverse_dusted,
            forward_n_removed_file => $forward_out,
            reverse_n_removed_file => $reverse_out,
            singleton_n_removed_file => $fragment_out,
            n_removal_threshold => $self->n_removal_threshold,
        );
        unless ($cmd){
            die $self->error_message("couldn't create remove-n-pairwise command for $forward_dusted, $reverse_dusted!");
        }
        my $rv = $cmd->execute;
        unless ($rv){
            die $self->error_message("couldn't create remove-n-pairwise command for $forward_dusted, $reverse_dusted!");
        }
        unless(-e $forward_out && -e $reverse_out && -e $fragment_out){
            die $self->error_message("couldn't find all expected output files! $forward_out, $reverse_out, $fragment_out");
        }
        #clean up, maybe make these temp files
        if ($self->dust_unaligned_reads){
            #only need to do this if we actually dusted
            unlink $forward_dusted;
            unlink $reverse_dusted;
        }

        #return the 3 processed fastq files
        return ($forward_out, $reverse_out, $fragment_out);
    }else{
        $self->status_message("skipping n-removal");
        Genome::Sys::copy_file($forward_dusted, $forward_out);
        Genome::Sys::copy_file($reverse_dusted, $reverse_out);
        if ($self->dust_unaligned_reads){
            #only need to do this if we actually dusted
            unlink $forward_dusted;
            unlink $reverse_dusted;
        }
        return ($forward_out, $reverse_out);
    }
}

sub dust_fastq{
    my ($self, $in, $out) = @_;
    my $cmd = Genome::Model::Tools::Fastq::Dust->create(
        fastq_file => $in,
        output_file => $out,
    );
    unless ($cmd){
        die $self->error_message("couldn't create dust command for $in -> $out!");
    }
    my $rv = $cmd->execute;
    unless ($rv){
        die $self->error_message("failed to execute dust command for $in -> $out! rv:$rv");
    }
    unless (-s $out){
        die $self->error_message("expected output file $out doesn't exist or has 0 size!");
    }
    return $out;
}

sub _process_unaligned_fastq {
    my $self = shift;
    my ($fastq_file, $output_path) = @_;

    my $dusted_fastq;
    if ($self->dust_unaligned_reads){
        $dusted_fastq = "$fastq_file.DUSTED";
        $self->dust_fastq($fastq_file, $dusted_fastq);
    }else{
        $self->status_message("skipping dusting $fastq_file");
        $dusted_fastq = $fastq_file;
    }

    if ($self->n_removal_threshold){
        $self->status_message("Running n-removal on file $fastq_file");
        my $cmd = Genome::Model::Tools::Fastq::RemoveN->create(
            fastq_file => $dusted_fastq,
            n_removed_file => $output_path,
            n_removal_threshold => $self->n_removal_threshold,
        ); 
        unless ($cmd){
            die $self->error_message("couldn't create remove-n command for $dusted_fastq");
        }
        my $rv = $cmd->execute;
        unless ($rv){
            die $self->error_message("couldn't execute remove-n command for $dusted_fastq");
        }
    } else {
        $self->status_message("No n-removal cutoff specified, skipping");
        Genome::Sys->copy_file($dusted_fastq, $output_path);
    }
    if ($self->dust_unaligned_reads){
        unlink $dusted_fastq;
    }
    return $output_path;
}

1;
