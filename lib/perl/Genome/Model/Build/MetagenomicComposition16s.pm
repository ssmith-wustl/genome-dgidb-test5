package Genome::Model::Build::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Mail::Sendmail;

class Genome::Model::Build::MetagenomicComposition16s {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => { 
            is => 'String', len => 255, is_mutable => 0,
            calculate_from => ['model_id'],
            calculate => sub {
                my($model_id) = @_;
                return unless $model_id;
                my $model = Genome::Model->get($model_id);
                Carp::croak("Can't find Genome::Model with ID $model_id while resolving subclass for Build") unless $model;
                my $seq_platform = $model->sequencing_platform;
                Carp::croak("Can't subclass Build: Genome::Model id $model_id has no sequencing_platform") unless $seq_platform;
                return return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($seq_platform);
            },
        },
        map( { 
                $_ => { via => 'processing_profile' } 
            } Genome::ProcessingProfile::MetagenomicComposition16s->params_for_class 
        ),
        map ( {
                $_ => { is => 'Number', is_metric => 1, }
            } (qw/
                amplicons_attempted amplicons_processed amplicons_processed_success 
                amplicons_classified amplicons_classified_success amplicons_classification_error 
                amplicons_chimeric amplicons_chimeric_percent 
                reads_attempted reads_processed reads_processed_success 
                /)
        ),
    ],
};

sub length_of_16s_region {
    return 1542;
}

sub post_allocation_initialization {
    my $self = shift;
    return $self->create_subdirectories;
}

sub create_subdirectories {
    my $self = shift;
    for my $dir ( $self->sub_dirs ) {
        Genome::Sys->create_directory( $self->data_directory."/$dir" )
            or return;
    }
    return 1;
}

sub validate_for_start_methods {
    my $self = shift;
    my @methods = $self->SUPER::validate_for_start_methods;
    push @methods, 'instrument_data_assigned';
    return @methods;
}

sub instrument_data_assigned {
    my $self = shift;
    my @tags;
    my @instrument_data = $self->instrument_data;
    unless (@instrument_data) {
        push @tags, UR::Object::Tag->create(
            type => 'error',
            properties => ['instrument_data'],
            desc => 'Build has no instrument data',
        );
    }
    return @tags;
}

#< Description >#
sub description {
    my $self = shift;

    return sprintf(
        'metagenomic composition 16s %s build (%s) for model (%s %s)',
        $self->sequencing_platform,
        $self->id,
        $self->model->name,
        $self->model->id,
    );
}

#< Amplicons >#
sub amplicon_set_names {
    my $self = shift;
    my %set_names_and_primers = $self->amplicon_set_names_and_primers;
    return sort keys %set_names_and_primers;
}

sub amplicon_set_names_and_primers {
    my $self = shift;
    my $sequencing_platform = $self->processing_profile->sequencing_platform;
    return Genome::Model::Build::MetagenomicComposition16s::SetNamesAndPrimers->set_names_and_primers_for($sequencing_platform);
}

sub amplicon_sets {
    my $self = shift;

    my %amplicon_set_names_and_primers = $self->amplicon_set_names_and_primers;
    my @amplicon_sets;
    for my $set_name ( sort { $a cmp $b } keys %amplicon_set_names_and_primers ) {
        push @amplicon_sets, Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(
            name => $set_name,
            primers => $amplicon_set_names_and_primers{$set_name},
            classification_dir => $self->classification_dir,
            classification_file => $self->classification_file_for_set_name($set_name),
            processed_fasta_file => $self->processed_fasta_file_for_set_name($set_name),
            processed_qual_file => $self->processed_qual_file_for_set_name($set_name),
            oriented_fasta_file => $self->oriented_fasta_file_for_set_name($set_name),
            oriented_qual_file => $self->oriented_qual_file_for_set_name( $set_name ),
        );
    }

    unless ( @amplicon_sets ) {
        $self->error_message("No amplicon sets found for ".$self->description);
        return;
    }

    return @amplicon_sets;
}

sub get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        my $writer = Genome::Model::Tools::Sx::PhredWriter->create(file => $fasta_file);
        Carp::confess("Failed to create phred reader for amplicon set ($set_name)") if not $writer;
        $self->{$set_name} = $writer;
    }

    return $self->{$set_name};
}


#< Dirs >#
sub sub_dirs {
    my $self = shift;
    my @sub_dirs = (qw| classification fasta reports |);
    push @sub_dirs, (qw/ chromat_dir edit_dir /) if $self->sequencing_platform eq 'sanger';
    return @sub_dirs;
}

sub classification_dir {
    return $_[0]->data_directory.'/classification';
}

sub fasta_dir {
    return $_[0]->data_directory.'/fasta';
}

sub reports_dir {
    return $_[0]->data_directory.'/reports';
}

sub edit_dir {
    return $_[0]->data_directory.'/edit_dir';
}

sub chromat_dir {
    return $_[0]->data_directory.'/chromat_dir';
}

#< Files >#
sub file_base_name {
    return Genome::Utility::Text::sanitize_string_for_filesystem( $_[0]->subject_name );
}

sub _files_for_amplicon_sets {
    my ($self, $type) = @_;
    die "No type given to get files for ".$self->description unless defined $type;
    my $method = $type.'_file_for_set_name';
    return grep { -s } map { $self->$method($_) } $self->amplicon_set_names;
}

sub _fasta_file_for_type_and_set_name {
    my ($self, $type, $set_name) = @_;

    # Sanity check - should not happen
    die "No type given to get fasta (qual) file for ".$self->description unless defined $type;
    die "No set name given to get $type fasta (qual) file for ".$self->description unless defined $set_name;
    
    return sprintf(
        '%s/%s%s.%s.fasta',
        $self->fasta_dir,
        $self->file_base_name,
        ( $set_name eq '' ? '' : ".$set_name" ),
        $type,
    );
}

sub _qual_file_for_type_and_set_name{
    my ($self, $type, $set_name) = @_;
    return $self->_fasta_file_for_type_and_set_name($type, $set_name).'.qual';
}

sub combined_input_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.'.'input.fasta';
}

# sanger files
sub raw_reads_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.reads.raw.fasta';
}

sub raw_reads_qual_file {
    return $_[0]->raw_reads_fasta_file.'.qual';
}

sub reads_fasta_file_for_amplicon { 
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.fasta';
}

sub reads_qual_file_for_amplicon {
    return reads_fasta_file_for_amplicon(@_).'.qual';
}

sub ace_file_for_amplicon { 
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.fasta.ace';
}
sub scfs_file_for_amplicon {
    my ($self, $amplicon) = @_;
    return $self->edit_dir.'/'.$amplicon->{name}.'.scfs';
}

sub create_scfs_file_for_amplicon {
    my ($self, $amplicon) = @_;

    my $scfs_file = $self->scfs_file_for_amplicon($amplicon);
    unlink $scfs_file if -e $scfs_file;
    my $scfs_fh = Genome::Sys->open_file_for_writing($scfs_file)
        or return;
    for my $scf ( @{$amplicon->{reads}} ) { 
        $scfs_fh->print("$scf\n");
    }
    $scfs_fh->close;

    if ( -s $scfs_file ) {
        return $scfs_file;
    }
    else {
        unlink $scfs_file;
        return;
    }
}

# processsed
sub processed_fasta_file { # returns them as a string (legacy)
    return join(' ', $_[0]->processed_fasta_files);
}

sub processed_fasta_files {
    return $_[0]->_files_for_amplicon_sets('processed_fasta');
}

sub processed_fasta_file_for_set_name {
    my ($self, $set_name) = @_;
    return $self->_fasta_file_for_type_and_set_name('processed', $set_name);
}

sub processed_qual_file { # returns them as a string (legacy)
    return join(' ', $_[0]->processed_qual_files);
}

sub processed_qual_files {
    return $_[0]->_files_for_amplicon_sets('processed_qual');
}

sub processed_qual_file_for_set_name {
    my ($self, $set_name) = @_;
    return $self->processed_fasta_file_for_set_name($set_name).'.qual';
}

sub processed_reads_fasta_file { #sanger
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.reads.processed.fasta';
}

sub processed_reads_qual_file { #sanger
    return $_[0]->processed_reads_fasta_file.'.qual';
}

# original/unprocessed file .. maybe name it unprocessed
sub combined_original_fasta_file {
    my $self = shift;
    return sprintf(
        '%s/%s.%s.fasta',
        $self->fasta_dir,
        $self->file_base_name,
        'original',
    );
}

sub combined_original_qual_file {
    return $_[0]->combined_original_fasta_file.'.qual';
}

sub combined_original_fastq_file {
    my $self = shift;
    return sprintf(
        '%s/%s.%s.fastq',
        $self->fasta_dir,
        $self->file_base_name,
        'original',
    );
}

# oriented
sub oriented_fasta_file { # returns them as a string
    return join(' ', $_[0]->oriented_fasta_files);
}

sub oriented_fasta_files {
    return $_[0]->_files_for_amplicon_sets('oriented_fasta');
}

sub oriented_fasta_file_for_set_name {
    my ($self, $set_name) = @_;
    return $self->_fasta_file_for_type_and_set_name('oriented', $set_name);
}

sub oriented_qual_file { # returns them as a string (legacy)
    return join(' ', $_[0]->oriented_qual_files);
}

sub oriented_qual_files {
    return $_[0]->_files_for_amplicon_sets('oriented_qual');
}

sub oriented_qual_file_for_set_name {
    my ($self, $set_name) = @_;
    return $self->oriented_fasta_file_for_set_name($set_name).'.qual';
}

# classification
sub classification_files_as_string {
    return join(' ', $_[0]->classification_files);
}

sub classification_files {
    return $_[0]->_files_for_amplicon_sets('classification');
}

#< Prepare instrument data >#
sub prepare_instrument_data {
    my $self = shift;
    $self->status_message('Prepare instrument data...');

    #call a separate command for sanger
    if ( $self->sequencing_platform eq 'sanger' ) {
        my $cmd = Genome::Model::MetagenomicComposition16s::Command::ProcessSangerInstrumentData->create(
            build => $self,
            );
        unless ( $cmd->prepare_instrument_data ) {
            $self->error_message("Failed to execute mc16s process sanger");
            return;
        }
        return 1;
    }

    my @instrument_data = $self->instrument_data;
    $self->status_message('Instrument data count: '.@instrument_data);
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->description);
        return;
    }

    #writer original/unprocessed/combined fastq file
    if ( not $self->fastq_from_instrument_data ) {
        Carp::confess( "Failed to get fasta from instrument data" );
    }
    #read in orig fastq file
    my $orig_fastq = $self->combined_original_fastq_file;
    if ( not -s $orig_fastq ) {
      Carp::confess( "Original fasta file did not get created or is blank" );
    }

    my @cmd_parts = ( 'gmt sx rm-desc' );
    my @amplicon_sets = $self->amplicon_sets;
    my (@output, @primers);
    for my $amplicon_set ( @amplicon_sets ) {
        my @set_primers = $amplicon_set->primers;
        for my $primer ( @set_primers ) {
            push @primers, $amplicon_set->name.'='.$primer;
        }
        my $root_set_name = $amplicon_set->name;
        $root_set_name =~ s/\.[FR]$//; #strip off .F/.R for paired sets
        my $fasta_file = $amplicon_set->processed_fasta_file;
        my $qual_file = $amplicon_set->processed_qual_file;
        unlink $fasta_file, $fasta_file;
        my $output = 'file='.$fasta_file.':qual_file='.$qual_file.':type=phred';
        $output .= ':name='.$root_set_name if @set_primers;
        push @output, $output;
    }

    if ( @primers ) {
        my $none_fasta_file = $self->processed_fasta_file_for_set_name('none');
        my $none_qual_file = $self->processed_qual_file_for_set_name( 'none' );
        unlink $none_fasta_file, $none_qual_file;
        push @output, 'name=discard:file='.$none_fasta_file.':qual_file='.$none_qual_file.':type=phred';
        push @cmd_parts, 'gmt sx bin by-primer --remove --primers '.join(',', @primers);
    }

    #add amplicon processing sx commands
    if ( $self->processing_profile->amplicon_processor ) {
        push @cmd_parts, $self->processing_profile->amplicon_processor_commands;
    }

    # Add input and metrics to first cmd
    $cmd_parts[0] .= ' --input file='.$orig_fastq.':type=sanger';
    my $input_metrics_file = $self->fasta_dir.'/metrics.processed.in.txt';
    $cmd_parts[0] .= ' --input-metrics '.$input_metrics_file;

    # Add output and metrics to last cmd
    $cmd_parts[$#cmd_parts] .= ' --output '.join(',', @output);
    my $output_metrics_file = $self->fasta_dir.'/metrics.processed.out.txt';
    $cmd_parts[$#cmd_parts] .= ' --output-metrics '.$output_metrics_file;

    # Create, execute, check return
    my $cmd = join(' | ', @cmd_parts);
    $self->status_message('Run SX...');
    $self->status_message("SX comand: $cmd");
    my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $rv ) {
        $self->error_message('Failed to run sx command to create amplicon files.');
        return;
    }
    $self->status_message('Run SX...OK');

    # Rm empty output files
    $self->status_message('Remove empty otuput files...');
    for my $amplicon_set ( @amplicon_sets ) {
        for my $file_method (qw/ processed_fasta_file processed_qual_file /) {
            my $file = $amplicon_set->$file_method;
            my $sz = -s $file;
            unlink $file if not $sz or $sz == 0;
        }
    }
    $self->status_message('Remove empty otuput files...OK');

    # Set metrics
    $self->status_message('Get metrics...');
    my $input_metrics = Genome::Model::Tools::Sx::Metrics->read_from_file($input_metrics_file);
    if ( not $input_metrics ) {
        $self->error_message('Failed to get metrcis from file: '.$input_metrics_file);
        return;
    }
    my $attempted = $input_metrics->count;
    $attempted = 0 if not defined $attempted;
    my $reads_attempted = $attempted;

    my $output_metrics = Genome::Model::Tools::Sx::Metrics->read_from_file($output_metrics_file);
    if ( not $output_metrics ) {
        $self->error_message('Failed to get metrcis from file: '.$output_metrics_file);
        return;
    }
    my $processed = $output_metrics->count;
    $processed = 0 if not defined $processed;
    $self->status_message('Get metrics...OK');

    $self->amplicons_attempted($attempted);
    $self->amplicons_processed($processed);
    my $processed_success =  $attempted > 0 ?  sprintf('%.2f', $processed / $attempted) : 0;
    $self->amplicons_processed_success($processed_success);
    $self->reads_attempted($reads_attempted);
    $self->reads_processed($processed);
    $self->reads_processed_success( $reads_attempted > 0 ?  sprintf('%.2f', $processed / $reads_attempted) : 0 );

    $self->status_message('Attempted:  '.$self->amplicons_attempted);
    $self->status_message('Processed:  '.$self->amplicons_processed);
    $self->status_message('Success:    '.($self->amplicons_processed_success * 100).'%');

    $self->status_message('Prepare instrument data...OK');
    return 1;
}

sub original_fastq_writer {
   my $self = shift;

   return $self->{_fastq_writer} if $self->{_fastq_writer};
   
   my $fastq_file = $self->combined_original_fastq_file;
   unlink $fastq_file if -e $fastq_file;

   my $writer = Genome::Model::Tools::Sx::Writer->create( config => [$fastq_file.':type=sanger'] );
   Carp::confess("Failed to create fastq writer to write original fastq file") if not $writer;
   
   $self->{_fastq_writer} = $writer;
   
   return $self->{_fastq_writer};
}

#< Fasta/Qual Readers/Writers >#
sub fastq_from_instrument_data {
    my $self = shift;
    
    for my $inst_data ( $self->instrument_data ) {

        my $temp_dir = Genome::Sys->create_temp_directory;
        my @fastq_files;
        if ( @fastq_files = eval {$inst_data->dump_fastqs_from_bam( directory => $temp_dir );} ) {
            #solexa bam
            if ( not @fastq_files ) {
                Carp::confess( "Did not get any fastq files from instrument data bam path" );
            }
            $self->status_message( "Got fastqs from bam" );
            #write fastq to original.fastq.file
            if ( not $self->append_fastq_to_orig_fastq_file( @fastq_files ) ) {
                Carp::confess( "Attempt to get fastq from fastq via bam failed" );
            }
        }
        elsif (  my $rv = eval {Genome::Sys->shellcmd( cmd => "tar zxf " . $inst_data->archive_path ." -C $temp_dir" );} ) {
            #solexa archive
            my @fastq_files = glob $temp_dir.'/*';
            if ( not @fastq_files ) {
                Carp::confess( "Did not get any fastq files from instrument data archive path" );
            }
            $self->status_message( "Untarred fastqs from archive path" );
            if ( not $self->append_fastq_to_orig_fastq_file( @fastq_files ) ) {
                Carp::confess( "Attempt to get fastq from fastq via archive path failed" );
            }
        }
        elsif ( @fastq_files = eval{$inst_data->dump_sanger_fastq_files;} ) {
            #fastq from sff files .. 454
            if ( not @fastq_files ) {
                Carp::confess( "Did not get fastq files from inst data dump_sanger_fastq_file method" );
            }
            $self->status_message( "Got fastq from sff files" ); #better message?
            if ( not $self->append_fastq_to_orig_fastq_file( @fastq_files ) ) {
                Carp::confess( "Attempt to append to original fastq with with new fastq failed" );
            }
        }
        else {
            $self->status_message($inst_data->__display_name__.' does not have any sequences! Skipping!');
        }
    }
    return 1;
}

sub append_fastq_to_orig_fastq_file {
    my ( $self, @fastq_files ) = @_;

    my $writer = $self->original_fastq_writer;
    unless ( $writer ) {
        Carp::confess( "Failed to get fastq writer to write original fastq file" );
    }
    my $reader = Genome::Model::Tools::Sx::Reader->create(config => [ map { $_.':type=sanger' } @fastq_files ]);
    if ( not $reader ) {
        Carp::confess( "Did not get fastq reader for files: ".join(' ', @fastq_files) );
    }
    while ( my $fastqs = $reader->read ) {
        for my $fastq( @$fastqs ) {
            $writer->write( [$fastq] );
        }
    }
    $self->status_message( "Finished writing to original fastq file, files: ".join(' ', @fastq_files) );

    return 1;
}

sub fasta_and_qual_reader_for_type_and_set_name {
    my ($self, $type, $set_name) = @_;
    
    # Sanity checks - should not happen
    die "No type given to get fasta and qual reader" unless defined $type;
    die "Invalid type ($type) given to get fasta and qual reader" unless grep { $type eq $_ } (qw/ processed oriented /);
    die "No set name given to get $type fasta and qual reader for set name ($set_name)" unless defined $set_name;

    # Get method and fasta file
    my $fasta_method = $type.'_fasta_file_for_set_name';
    my $fasta_file = $self->$fasta_method($set_name);
    my $qual_method = $type.'_qual_file_for_set_name';
    my $qual_file = $self->$qual_method($set_name);

    return unless -e $fasta_file and -e $qual_file; # ok
    my %params = (
        file => $fasta_file,
        qual_file => $qual_file,
    );
    my $reader =  Genome::Model::Tools::Sx::PhredReader->create(%params);
    if ( not  $reader ) {
        $self->error_message("Failed to create phred reader for $type fasta file and amplicon set name ($set_name) for ".$self->description);
        return;
    }

    return $reader;
}

sub fasta_and_qual_writer_for_type_and_set_name {
    my ($self, $type, $set_name) = @_;

    # Sanity checks - should not happen
    die "No type given to get fasta and qual writer" unless defined $type;
    die "Invalid type ($type) given to get fasta and qual writer" unless grep { $type eq $_ } (qw/ processed oriented /);
    die "No set name given to get $type fasta and qual writer for set name ($set_name)" unless defined $set_name;

    # Get method and fasta file
    my $fasta_method = $type.'_fasta_file_for_set_name';
    my $fasta_file = $self->$fasta_method($set_name);
    my $qual_method = $type.'_qual_file_for_set_name';
    my $qual_file = $self->$qual_method($set_name);

    # Remove existing files if there
    unlink $fasta_file, $qual_file;
    my %params = ( 
        file => $fasta_file,
        qual_file => $qual_file,
    );

    # Create writer, return
    my $writer =  Genome::Model::Tools::Sx::PhredWriter->create(%params);
    unless ( $writer ) {
        $self->error_message("Can't create phred writer for $type fasta file and amplicon set name ($set_name) for ".$self->description);
        return;
    }

    return $writer;
}

#< Orient >#
sub orient_amplicons {
    my $self = shift;

    $self->status_message('Orient amplicons...');

    my $amplicons_classified = $self->amplicons_classified;
    if ( not defined $amplicons_classified ) {
        $self->error_message('Cannot orient apmplicons because "amplicons classified" metric is not set for '.$self->description);
        return;
    }

    if ( $amplicons_classified == 0 ) {
        $self->status_message("No amplicons were successfully classified, skipping orient.");
        return 1;
    }

    my @amplicon_sets = $self->amplicon_sets;
    return if not @amplicon_sets;

    my $no_classification = 0;
    for my $amplicon_set ( @amplicon_sets ) {
        next if not $amplicon_set->amplicon_iterator;
        my $writer = $self->fasta_and_qual_writer_for_type_and_set_name('oriented', $amplicon_set->name)
            or return;

        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            my $seq = $amplicon->{seq};
            next if not $seq; #OK - for now...

            if ( not defined $amplicon->{classification} ) {
                $no_classification++;
                next;
            }

            if ( $amplicon->{classification}->[1] eq '-' ) {
                $seq->{seq} = reverse $seq->{seq};
                $seq->{seq} =~ tr/ATGCatgc/TACGtacg/;
            }

            $writer->write($seq);
        }
    }

    my $classification_error = $self->amplicons_classification_error;
    if ( $no_classification != $classification_error ) {
        $self->error_message("Found $no_classification amplicons without classifications, but $classification_error amplicons failed to classify.");
    }

    $self->status_message('Orient amplicons...OK');

    return 1;
}

#< Classify >#
sub classification_file_for_set_name {
    my ($self, $set_name) = @_;
    
    die "No set name given to get classification file for ".$self->description unless defined $set_name;

    my $classifier = $self->classifier;
    my %classifier_params = $self->processing_profile->classifier_params_as_hash;
    if ( $classifier_params{version} ) {
        $classifier .= $classifier_params{version};
    }

    return sprintf(
        '%s/%s%s.%s',
        $self->classification_dir,
        $self->file_base_name,
        ( $set_name eq '' ? '' : ".$set_name" ),
        lc($classifier),
    );
}

sub classify_amplicons {
    my $self = shift;

    $self->status_message('Classify amplicons...');

    my $attempted = $self->amplicons_attempted;
    if ( not defined $attempted ) {
        $self->error_message('No value for amplicons attempted set. Cannot classify.');
        return;
    }

    my @amplicon_sets = $self->amplicon_sets;
    if ( not @amplicon_sets ) {
        $self->error_message('No amplicon sets for '.$self->description);
        return;
    }

    my $classifier_params = $self->processing_profile->classifier_params;
    # TEMP UTNIL THIS GOES STABLE, THEN FIX PARAMS
    $classifier_params =~ s/_/\-/g;
    if ( $classifier_params !~ /version/ ) {
        if ( $self->classifier eq 'rdp2-1' ) {
            $classifier_params .= ' --version 2x1';
        }
        elsif ( $self->classifier eq 'rdp2-2' ) {
            $classifier_params .= ' --version 2x2';
        }
        else {
            $self->error_message("Invalid classifier (".$self->classifier.") for ".$self->description);
            return;
        }
    }
    if ( $classifier_params !~ /format/ ) {
        $classifier_params .= ' --format hmp_fix_ranks';
    }

    $self->status_message('Classifier: '.$self->classifier);
    $self->status_message('Classifier params: '.$classifier_params);

    my %metrics;
    @metrics{qw/ attempted success error total /} = (qw/ 0 0 0 0 /);
    for my $amplicon_set ( @amplicon_sets ) {
        my $fasta_file = $amplicon_set->processed_fasta_file;
        next if not -s $fasta_file;

        my $classification_file = $amplicon_set->classification_file;
        unlink $classification_file if -e $classification_file;

        # FIXME use $classifier
        my $cmd = "gmt metagenomic-classifier rdp --input-file $fasta_file --output-file $classification_file $classifier_params --metrics"; 
        my $rv = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
        if ( not $rv ) {
            $self->error_message('Failed to execute classifier command');
            return;
        }

        # metrics
        my $metrics_file = $classification_file.'.metrics';
        my $metrics_fh = eval{ Genome::Sys->open_file_for_reading($metrics_file); };
        if ( not $metrics_fh ) {
            $self->error_message("Failed to open metrics file ($metrics_file): $@");
            return;
        }
        while ( my $line = $metrics_fh->getline ) {
            chomp $line;
            my ($key, $val) = split('=', $line);
            $metrics{$key} += $val;
        }
    }

    $self->amplicons_processed($metrics{total});
    $self->amplicons_processed_success( 
        defined $attempted and $attempted > 0 ?  sprintf('%.2f', $metrics{total} / $attempted) : 0 
    );
    $self->amplicons_classified($metrics{success});
    $self->amplicons_classified_success( 
        $metrics{total} > 0 ?  sprintf('%.2f', $metrics{success} / $metrics{total}) : 0
    );
    $self->amplicons_classification_error($metrics{error});

    $self->status_message('Processed:  '.$self->amplicons_processed);
    $self->status_message('Classified: '.$self->amplicons_classified);
    $self->status_message('Error:      '.$self->amplicons_classification_error);
    $self->status_message('Success:    '.($self->amplicons_classified_success * 100).'%');

    $self->status_message('Classify amplicons...OK');

    return 1;
}

#< QC Email >#
sub perform_post_success_actions {
    my $self = shift;

    $self->status_message('Post success actions');
    $self->status_message('Check if model is for QC: '.$self->model_name);

    if ( not $self->model->is_for_qc ) {
        $self->status_message('Model is not for QC. Not sending confirmation email');
        return 1;
    }

    $self->status_message('This model is QC');

    my @instrument_data = $self->instrument_data;
    my %run_region_names = map { $_->run_name.' '.$_->region_number => 1 } @instrument_data;
    my @run_region_names = grep { defined } keys %run_region_names;
    if ( not @run_region_names ) {
        $self->error_message('No run names from instrument data for '.$self->description);
        return;
    }
    if ( @run_region_names > 1 ) {
        $self->error_message("Found multiple run region names (@run_region_names) for instrument data assigned to ".$self->description);
        return;
    }

    my @instrument_data_for_run_region = Genome::InstrumentData::454->get(
        run_name => $instrument_data[0]->run_name,
        region_number => $instrument_data[0]->region_number,
    );
    if ( not @instrument_data_for_run_region ) {
        $self->error_message('No instrument data found for run region name: '.$run_region_names[0]);
        return;
    }

    if ( @instrument_data != @instrument_data_for_run_region ) {
        $self->status_message('Not sending email for MC16s QC model. Have '.@instrument_data.' instrument data, but expect '.@instrument_data_for_run_region);
        return 1;
    }

    my $msg = "Hello,\n\nThis MC16s QC build is finished and has all instrument data included.\n\n";
    $msg .= 'Model name:      '.$self->model_name."\n";
    $msg .= 'Model id:        '.$self->model_id."\n";
    $msg .= 'Build id:        '.$self->id."\n";
    $msg .= 'Directory:       '.$self->data_directory."\n";
    $msg .= 'Run name:        '.$instrument_data[0]->run_name."\n";
    $msg .= 'Region number:   '.$instrument_data[0]->region_number."\n";
    $msg .= 'Inluded count:   '.@instrument_data."\n";
    $msg .= 'Expected count:  '.@instrument_data_for_run_region."\n";
    $msg .= 'Attempted:       '.$self->amplicons_attempted."\n";
    $msg .= 'Processed:       '.$self->amplicons_processed."\n";
    $msg .= 'Success :        '.(100 * $self->amplicons_processed_success)."%\n";
    $msg .= "\n-APIPE";
    $self->status_message($msg);

    if ( not $ENV{UR_DBI_NO_COMMIT} ) { # do not send mail when in dev mode
        Mail::Sendmail::sendmail(
            To => 'esodergr@genome.wustl.edu, kmihindu@genome.wustl.edu', 
            #To => 'ebelter@genome.wustl.edu', 
            Cc => 'ebelter@genome.wustl.edu', 
            From => 'apipe@genome.wustl.edu', 
            Subject => 'MC16s QC Build is Done',
            Message => $msg,
        );
    }

    $self->status_message('Sent email to Erica (esodergren) and Kathie (kmihindu)');

    return 1;
}

#< calculate est kb usage >#
sub calculate_estimated_kb_usage {
    my $self = shift;

    #could also derive seq platform from inst data
    my $method = 'calculate_estimated_kb_usage_'.$self->processing_profile->sequencing_platform;
    unless ( $self->can( $method ) ) {
         $self->error_message( "Failed to find method to estimate kb usage for sequencing platform: ".$self->processing_profile->sequencing_platform );
         return;
    }
    return $self->$method;
}

sub calculate_estimated_kb_usage_solexa {
    my $self = shift;

    my $instrument_data_count = $self->instrument_data_count;
    if ( not $instrument_data_count > 0 ) {
        Carp::confess( "No instrument data found for ".$self->description );
    }

    my $kb = $instrument_data_count * 500_000; #TODO .. not sure what best value is

    return ( $kb );
}

sub calculate_estimated_kb_usage_454 {
    # Based on the total reads in the instrument data. The build needs about 3 kb (use 3.5) per read.
    #  So request 5 per read or at least a MiB
    #  If we don't keep the classifications around, then we will have to lower this number.
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) { # very bad; should be checked when the build is create
        Carp::confess("No instrument data found for ".$self->description);
    }

    my $total_reads = 0;
    for my $instrument_data ( @instrument_data ) {
        $total_reads += $instrument_data->total_reads;
    }

    my $kb = $total_reads * 5;
    return ( $kb >= 1024 ? $kb : 1024 );
}

sub calculate_estimated_kb_usage_sanger {
    # Each piece of instrument data uses about 30Mb of space. Adjust if more files are removed
    my $self = shift;

    my $instrument_data_count = $self->instrument_data_count;
    unless ( $instrument_data_count ) { # very bad; should be checked when the build is created
        confess("No instrument data found for build ".$self->description);
    }

    return $instrument_data_count * 30000;
}


#< instrument data processing >#
sub fastqs_from_solexa {
    my ( $self, $inst_data ) = @_;

    my @fastq_files;

    if ( $inst_data->bam_path ) { #fastq from bam
        $self->error_message("Bam file is zero size or does not exist: ".$inst_data->bam_path ) and return
            if not -s $inst_data->bam_path;
        my $temp_dir = Genome::Sys->create_temp_directory;
        @fastq_files = $inst_data->dump_fastqs_from_bam( directory => $temp_dir );
        $self->status_message( "Got fastq files from bam: ".join( ', ', @fastq_files ) );
    }
    elsif ( $inst_data->archive_path ) { #dump fastqs from archive
        $self->error_message( "Archive file is missing or is zero size: ".$inst_data->archive_path ) and return
            if not -s $inst_data->archive_path;
        my $temp_dir = Genome::Sys->create_temp_directory;
        my $tar_cmd = "tar zxf " . $inst_data->archive_path ." -C $temp_dir";
        $self->status_message( "Running tar: $tar_cmd" );
        unless ( Genome::Sys->shellcmd( cmd => $tar_cmd ) ) {
            $self->error_message( "Failed to dump fastq files from archive path using cmd: $tar_cmd" );
            return;
        }
        @fastq_files = glob $temp_dir .'/*';
        $self->status_message( "Got fastq files from archive path: ".join (', ', @fastq_files) );
    }
    else {
        $self->error_message( "Could not get neither bam_path nor archive path for instrument data: ".$inst_data->id );
        return; #die here
    }

    return @fastq_files;
}


#< Diff >#
sub dirs_ignored_by_diff {
    return (qw{
        logs/
        reports/
        edit_dir/
        chromat_dir/
        classification/
    });
}

sub files_ignored_by_diff {
    return (qw/ build.xml /);
}

sub regex_for_custom_diff {
    return (
        gz => '\.gz$',
        rdp => '\.rdp1-[12]$',
    );
}

sub diff_rdp {
    my ($self, $file1, $file2) = @_;

    my $reader1 = Genome::Model::Tools::MetagenomicClassifier::ClassificationReader->create(
        file => $file1,
    );
    return if not $reader1;

    my $reader2 = Genome::Model::Tools::MetagenomicClassifier::ClassificationReader->create(
        file => $file2,
    );
    return if not $reader2;

    my ($classification1_cnt, $classification2_cnt) = (qw/ 0 0 /);
    while ( my $classification1 = $reader1->read ) {
        $classification1_cnt++;
        my $classification2 = $reader2->read;
        last if not $classification2;
        $classification2_cnt++;
        if ( $classification1->{id} ne $classification2->{id} ) {
            $self->status_message("RDP differs at id: ".$classification1->{id}.' <=> '.$classification2->{id});
            return;
        }
        if ( $classification1->{complemented} ne $classification2->{complemented} ) {
            $self->status_message("RDP differs at complemented: ".$classification1->{complemented}.' <=> '.$classification2->{complemented});
            return;
        }
        for my $rank (qw/ domain phylum order class family genus /) {
            if ( $classification1->{$rank}->{id} ne $classification2->{$rank}->{id} ) {
                $self->status_message("RDP differs at $rank: ".$classification1->{$rank}->{id}.' <=> '.$classification2->{$rank}->{id});
                return;
            }
        }
    }

    if ( $classification1_cnt != $classification2_cnt ) {
        $self->error_message('Classification counts differ: '.$classification1_cnt.' <=> '.$classification2_cnt);
        return;
    }

    return 1;
}

1;

