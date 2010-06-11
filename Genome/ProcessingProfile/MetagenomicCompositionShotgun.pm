package Genome::ProcessingProfile::MetagenomicCompositionShotgun;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sys::Hostname;

our $UNALIGNED_TEMPDIR = '/gscmnt/sata844/info/hmp-mgs-test-temp';

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

my $log_model_name;

sub status_message{
    my ($self, $message, @args) = @_;
    $self->SUPER::status_message($message,@args);
    $self->log_message("STATUS:".$message);
}

sub error_message{
    my ($self, $message, @args) = @_;
    $self->SUPER::error_message($message, @args);
    $self->log_message("ERROR:".$message);
    die $message;
}

sub log_message{
    my ($self, $message) = @_;
    my $fh = $self->{log_fh};
    unless ($fh){
        my $pid = $$;
        my $hostname = hostname();
        my $fn = "/gscuser/adukes/MCS_log/${log_model_name}_${pid}_${hostname}";
        my $log_fh = IO::File->new("> $fn");
        unless ($log_fh){
            die "couldn't create new logfile for $fn";
        }
        $self->{log_fh} = $log_fh;
        $fh = $self->{log_fh};
    }
    chomp $message;
    $fh->print($message."\n");
}

sub _execute_build{
    my ($self, $build) = @_;

$DB::single = 1;

    my $model = $build->model;
    $log_model_name = $model->name;

    $self->status_message("Starting build for model $log_model_name");

    $build->status_message("TEST BUILD STATUS: Starting build for model $log_model_name");

    my $screen_model = $model->_contamination_screen_alignment_model;
    unless ($screen_model) {
        $self->error_message("couldn't grab contamination screen underlying model!");
        return;
    }
    
    # ENSURE WE HAVE INSTRUMENT DATA
    my @id = $model->inst_data;
    if (@id == 0) {
        $self->error_message("NO INSTRUMENT DATA ASSIGNED!");
        die $self->error_message();
    }

    #ASSIGN ANY NEW INSTRUMENT DATA TO THE CONTAMINATION SCREENING MODEL
    $self->status_message("Checking for new instrument data to add to contamination screen model");
    my %screen_id = map { $_->id => $_ } $screen_model->instrument_data;
    my @to_add = grep {! $screen_id{$_->id}} @id;
    if (@to_add) {
        $self->add_instrument_data_to_model($screen_model, \@to_add);
    }
    else {
        $self->status_message("No new instrument data to add to contamination screen model");
    }

    #BUILD HUMAN CONTAMINATION SCREEN MODEL
    $self->status_message("Building contamination screen model if necessary");
    my $screen_build = $self->build_if_necessary_and_wait($screen_model,$build);

    # TRANSFORM AND IMPORT INSTRUMENT DATA
    $self->status_message("Importing instrument data for any new unaligned reads");
    my @screened_assignments = $screen_model->instrument_data_assignments;
    my @to_add2;
    for my $assignment (@screened_assignments) {
        my @alignments = $assignment->results($screen_build);
        if (@alignments > 1) {
            $self->error_message( "Multiple alignments found for instrument data assignment: " . $assignment->__display_name__);
            return;
        }
        if (@alignments == 0) {
            $self->error_message( "No alignments found for instrument data assignment: " . $assignment->__display_name__);
            return;
        }
        $self->status_message("Processing instrument data assignment ".$assignment->__display_name__." for unaligned reads import");

        my $alignment = $alignments[0];
        my $instrument_data = $assignment->instrument_data;
        my $lane = $instrument_data->lane;

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

        my $forward_basename = "s_${lane}_1_sequence.txt";
        my $reverse_basename = "s_${lane}_2_sequence.txt";
        my $fragment_basename = "s_${lane}_sequence.txt";

        my $forward_unaligned_data_path     = glob("$tmp_dir/*/$forward_basename");
        my $reverse_unaligned_data_path     = glob("$tmp_dir/*/$reverse_basename");
        my $fragment_unaligned_data_path    = glob("$tmp_dir/*/$fragment_basename");

        my @missing = grep {! -e $_} grep { defined($_) and length($_) } ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path);
        if (@missing){
            $self->error_message(join(", ", @missing)." unaligned files missing after bam extraction");
            return;
        }
        $self->status_message("Extracted unaligned reads from bam file(".join(", ", ($forward_unaligned_data_path, $reverse_unaligned_data_path, $fragment_unaligned_data_path)));

        my @expected_original_paths;
        if ($fragment_unaligned_data_path) {
            # dust, n-remove;
            my $expected_data_path = $tmp_dir . '/' . $subdir . "/$fragment_basename"; 
            my $processed_fastq = $self->process_unaligned_fastq($fragment_unaligned_data_path, $expected_data_path);
            unless (-e $expected_data_path){
                $self->error_message("Expected data path does not exist after fastq processing: $expected_data_path");
                return;
            }
            push @expected_original_paths, $expected_data_path; 
        }

        if ($forward_unaligned_data_path or $reverse_unaligned_data_path) {
            unless ($forward_unaligned_data_path and $reverse_unaligned_data_path) {
                die;
            }

            my $expected_data_path1 = $tmp_dir . '/' . $subdir . "/$forward_basename"; 
            my $processed_fastq1 = $self->process_unaligned_fastq($forward_unaligned_data_path, $expected_data_path1);

            my $expected_data_path2 = $tmp_dir . '/' . $subdir . "/$reverse_basename"; 
            my $processed_fastq2 = $self->process_unaligned_fastq($reverse_unaligned_data_path, $expected_data_path2);

            my @missing = grep {! -e $_} ($expected_data_path1, $expected_data_path2);
            if (@missing){
                $self->error_message("Expected data paths do not exist after fastq processing: ".join(", ", @missing));
                return;
            }

            push @expected_original_paths, $expected_data_path1 . ',' . $expected_data_path2; 

        }
        $DB::single = 1;

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

        for my $original_data_path (@expected_original_paths) {
            if ($original_data_path =~ /,/){
                $properties_from_prior{is_paired_end} = 1;
            }else{
                $properties_from_prior{is_paired_end} = 0;
            }
            my $previous = Genome::InstrumentData::Imported->get(
                original_data_path => $original_data_path,
            );
            if ($previous){
                $self->status_message("imported instrument data already found for path $original_data_path, skipping");
                push @to_add2, $previous;
                next;
            }
            my %params = (
                %properties_from_prior,
                source_data_files => $original_data_path,
            );
            $self->status_message("importing fastq with the following params:" . Data::Dumper::Dumper(\%params));
            
            if (0) {

            }
            else {
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
            }

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
            
            push @to_add2, $instrument_data;
        }        
    }

#ASSIGN IMPORTED INSTRUMENT DATA
    my @metagenomic_models = $model->_metagenomic_alignment_models;
    for my $metagenomic_model (@metagenomic_models){
        my %current_instrument_data = map { $_->id => $_ } $metagenomic_model->instrument_data;
        my @to_add_meta = grep {! $current_instrument_data{$_->id}} @to_add2;
        if (@to_add_meta){
            $self->add_instrument_data_to_model($metagenomic_model, \@to_add_meta);
        }else{
            $self->status_message("No new imported instrument data to add to ".$metagenomic_model->name);
        }
    } 

#RUN METAGENOMIC REF-ALIGN-BUILD
    foreach my $metagenomic_model (@metagenomic_models){
        $self->build_if_necessary_and_wait($metagenomic_model,$build);
    }
#MERGE ALIGNMENTS
#REPORTING

}

sub add_instrument_data_to_model{
    my ($self, $model, $instrument_data) = @_;

    #TODO:put this logic in Genome::Model::assign_instrument_data() so we don't have to use a command
    $self->status_message("adding the following instrument data to the model ".$model->name." ".join(', ', map { $_->id } @$instrument_data));

    for (@$instrument_data) {

        my $cmd = Genome::Model::Command::InstrumentData::Assign->create(
            model_id => $model->id,
            instrument_data_id => $_->id,
        );
        my $rv = $cmd->execute;
        unless ($rv){
            $self->error_message("Couldn't assign instrument data to contamination screen model");
            return 0;
        }
    }
    $self->status_message("Committing new instrument data assignment");
    UR::Context->commit();
    $self->status_message("instrument data added");
    return 1;
}

sub build_if_necessary_and_wait{
    my ($self, $model, $parent_build) = @_;
    unless ($model and $model->isa("Genome::Model::ReferenceAlignment")){
        $self->error_message("No ImportedReferenceSequence model passed to build_if_necessary_and_wait()");
        return;
    }

    if ($self->need_to_build($model)) {

        $self->status_message("Running build for model ".$model->name);
        my $build = $self->run_ref_align_build($model);

        unless ($build){
            $self->error_message("Couldn't create build for model ".$model->name);
        }

        $self->wait_for_build($build);

        unless ($build->status eq 'Succeeded'){
            $self->error_message("Failed to execute build for for model ".$model->name);
            return;
        }
        return $build;
    }
    else {
        $self->status_message("Skipping redundant build");
        my $build = $model->last_succeeded_build;
        return $build;
    }
}

sub run_ref_align_build {
    my ($self, $model) = @_;
    unless ($model and $model->isa("Genome::Model::ReferenceAlignment")){
        $self->error_message("No ImportedReferenceSequence model passed to run_ref_align_build()");
        return;
    }

    my @builds1 = $model->builds;

    my $sub_build;
    if (0) {
        my $cmd = "genome model build start --force -m " . $model->id;
        Genome::Utility::FileSystem->shellcmd(cmd => $cmd); 
        my @builds2 = UR::Context->current->reload("Genome::Model::Build", model_id => $model->id);
        
        if (@builds2 == @builds1) {
            $self->error_message("Failed to start build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
        }
        else {
            $sub_build = $builds2[-1];
            $self->status_message("Created and started build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
        }

    }
    else {
        $self->status_message("  creating build");
        $sub_build = Genome::Model::Build->create(
            model_id => $model->id
        );
        unless ($sub_build){
            $self->error_message("Couldn't create build for underlying ref-align model " . $model->name. ": " . Genome::Model::Build->error_message);
            return;
        }
        
        $self->status_message("  starting build");
        #TODO update these params to use pp values or wahtevers passes in off command line
        my $rv = $sub_build->start(
            job_dispatch => 'apipe',
            server_dispatch=>'long'
        );
        
        if ($rv){
            $self->status_message("Created and started build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
        }else{
            $self->error_message("Failed to start build for underlying ref-align model " .  $model->name ." w/ build id ".$sub_build->id);
        }
        
        $self->status_message("Committing after starting build");
        UR::Context->commit();
    }


    return $sub_build;
}

sub wait_for_build{
    my ($self, $build) = @_;
    my $last_status = '';
    my $time = 0;
    my $inc = 30;
    while (1){
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


sub process_unaligned_fastq {
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
    }else{
        $self->status_message("No n-removal cutoff specified, skipping");
        unless ( File::Copy::copy($fastq_file, $n_removed_fastq)){
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

        while (my $header = $fastq_input_fh->getline) 
        {
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
        while (my $line = $dusted_input_fh->getline)
        {
            if ($line=~/^>.*/) #found a header
            {
                # this only grabs the header on the first sequence
                # other sequences in the file will have their header pre-caught below
                # confusing :(
                $header = $line;
            }
            else
            {
                chomp($seq .= $line);
                #$seq .= $line;
            }

            while ($line = $dusted_input_fh->getline) #accumulate lines for read, until next header encountered
            {
                if ($line=~/^>.*/) #found a new header - read has been accumulated 
                {
                    last;
                }
                else
                {
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
    }else{
        $self->status_message("Dusting not required, skipping on $n_removed_fastq");
        unless( File::Copy::copy($n_removed_fastq, $n_removed_dusted_length_screened_fastq)){
            $self->error_message("Failed to copy $n_removed_fastq to $n_removed_dusted_length_screened_fastq while skipping dusting");
            return;
        }
    }

    # kill intermediate files
    foreach my $file($fasta_file, $n_removed_fastq, $dusted_file, $qual_file, $sep_file)
    {
        unlink($file) if -e $file;
    }

    #screen out <60bp reads, do this last? don't know what to do about mate pairs
    File::Copy::move($n_removed_dusted_length_screened_fastq, $output_path);
    $self->status_message("Finished processing on $output_path");
    return $output_path;

}

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/ProcessingProfile/MetagenomicComposition16s.pm $
#$Id: MetagenomicComposition16s.pm 56538 2010-03-15 23:42:35Z ebelter $
