package Genome::Model::Build::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

class Genome::Model::Build::MetagenomicComposition16s {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    has => [
        subclass_name => { is => 'String', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
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
        # Metrics
        amplicons_attempted => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons attempted' ],
            to => 'value',
            doc => 'Number of amplicons that were attempted in this build.'
        },
        amplicons_processed => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons processed' ],
            to => 'value',
            doc => 'Number of amplicons that were processed in this build.'
        },
        amplicons_processed_success => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons processed success' ],
            to => 'value',
            doc => 'Number of amplicons that were successfully processed in this build.'
        },
        amplicons_classified => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons classified' ],
            to => 'value',
            doc => 'Number of amplicons that were classified in this build.'
        },
        amplicons_classified_success => {
            is => 'Number',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons classified success' ],
            to => 'value',
            doc => 'Number of amplicons that were successfully classified in this build.'
        },
        amplicons_classification_error => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons classification error' ],
            to => 'value',
            doc => 'Number of amplicons that had a classification error, and did not classify.'
        },
        reads_attempted => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'reads attempted' ],
            to => 'value',
            doc => 'Number of reads attempted.'
        },
        reads_processed => {
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'reads processed' ],
            to => 'value',
            doc => 'Number of reads that processed into amplicon sequence.'
        },
        reads_processed_success => {
            is => 'Number',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'reads processed success' ],
            to => 'value',
            doc => 'Percentage of reads successfully processed into amplicon sequence.'
        },
    ],
};

sub length_of_16s_region {
    return 1542;
}

#< UR >#
sub create {
    my $class = shift;
    if ($class eq __PACKAGE__) {
        return $class->SUPER::create(@_);
    }

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data was found for model (".$self->model->id."), and cannot be built");
        $self->delete;
        return 1;
    }

    unless ( $self->model->type_name eq 'metagenomic composition 16s' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an metagenomic composition.',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    # Create directory structure
    Genome::Sys->create_directory($self->data_directory )
        or return;

    for my $dir ( $self->sub_dirs ) {
        Genome::Sys->create_directory( $self->data_directory."/$dir" )
            or return;
    }

    return $self;
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
    my $method = 'amplicon_set_names_and_primers_'.$self->processing_profile->sequencing_platform;
    if ( $self->can( $method ) ) {
        my %set_names_and_primers = $self->$method;
        return sort keys %set_names_and_primers;
    }
    $self->warning_message( "No amplicon set primers for sequencing platform: ".$self->processing_profile->sequencing_platform );
    return ( '' );
}

sub amplicon_set_names_and_primers {
    my $self = shift;
    my $method = 'amplicon_set_names_and_primers_'.$self->processing_profile->sequencing_platform;
    if ( $self->can( $method ) ) {
        return $self->$method;
    }
    $self->warning_message( "No amplicon set primers for sequencing platform: ".$self->processing_profile->sequencing_platform );
    return; 
}

sub amplicon_set_names_and_primers_454 {
    return (
        V1_V3 => [qw/
            ATTACCGCGGCTGCTGG 
        /],
        V3_V5 => [qw/ 
            CCGTCAATTCATTTAAGT
            CCGTCAATTCATTTGAGT
            CCGTCAATTCCTTTAAGT
            CCGTCAATTCCTTTGAGT
        /],
        V6_V9 => [qw/
            TACGGCTACCTTGTTACGACTT
            TACGGCTACCTTGTTATGACTT
            TACGGTTACCTTGTTACGACTT
            TACGGTTACCTTGTTATGACTT
        /],
    );
}

sub amplicon_sets {
    my $self = shift;

    my @amplicon_sets;
    for my $set_name ( $self->amplicon_set_names ) {
        my $amplicon_set;
        if ( $self->sequencing_platform eq 'sanger' ) { #TODO - make it so it auto recognizes sanger
            my $cmd = Genome::Model::MetagenomicComposition16s::Command::ProcessSangerInstrumentData->create( build_id => $self->id );
            $amplicon_set = $cmd->amplicon_set_for_name( $set_name );
        } else {
            $amplicon_set = $self->amplicon_set_for_name($set_name); #call command for sanger
        }
        next unless $amplicon_set; # undef ok, dies on error
        push @amplicon_sets, $amplicon_set;
    }

    unless ( @amplicon_sets ) { # bad
        $self->error_message("No amplicon sets found for ".$self->description);
        return;
    }

    return @amplicon_sets;
}

sub amplicon_set_for_name {
    my ($self, $set_name) = @_;

    Carp::confess('No amplicon set name to get amplicon iterator') if not defined $set_name;

    my $amplicon_iterator = $self->_amplicon_iterator_for_name($set_name);
    return if not $amplicon_iterator;

    my %params = (
        name => $set_name,
        amplicon_iterator => $amplicon_iterator,
        classification_dir => $self->classification_dir,
        classification_file => $self->classification_file_for_set_name($set_name),
        processed_fasta_file => $self->processed_fasta_file_for_set_name($set_name),
        oriented_fasta_file => $self->oriented_fasta_file_for_set_name($set_name),
    );

    if ( $self->sequencing_platform eq 'sanger' ) { # has qual
        $params{processed_qual_file} = $self->processed_fasta_file_for_set_name($set_name);
        $params{oriented_qual_file} = $self->oriented_qual_file_for_set_name($set_name);
    }
    
    return Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(%params);
}

sub _amplicon_iterator_for_name { # 454 and solexa for now
    my ($self, $set_name) = @_;

    #print "iterator from base\n"; <STDIN>;

    my $reader = $self->fasta_and_qual_reader_for_type_and_set_name('processed', $set_name);
    return unless $reader; # returns undef if no file exists OK or dies w/ error 

    my $classification_file = $self->classification_file_for_set_name($set_name);
    my ($classification_io, $classification_line);
    if ( -s $classification_file ) {
        $classification_io = eval{ Genome::Sys->open_file_for_reading($classification_file); };
        if ( not $classification_io ) {
            $self->error_message('Failed to open classification file: '.$classification_file);
            return;
        }
        $classification_line = $classification_io->getline;
        chomp $classification_line;
    }

    my $amplicon_iterator = sub{
        my $seqs = $reader->read;
        return unless $seqs;
        my $seq = $seqs->[0];

        my %amplicon = (
            name => $seq->{id},
            reads => [ $seq->{id} ],
            reads_processed => [ $seq->{id} ],
            seq => $seq,
        );

        return \%amplicon if not $classification_line;

        my @classification = split(';', $classification_line); # 0 => id | 1 => ori
        if ( not defined $classification[0] ) {
            Carp::confess('Malformed classification line: '.$classification_line);
        }
        if ( $seq->{id} ne $classification[0] ) {
            return \%amplicon;
        }

        $classification_line = $classification_io->getline;
        chomp $classification_line if $classification_line;

        $amplicon{classification} = \@classification;
        return \%amplicon;
    };

    return $amplicon_iterator;
}

sub get_writer_for_set_name {
    my ($self, $set_name) = @_;

    unless ( $self->{$set_name} ) {
        my $fasta_file = $self->processed_fasta_file_for_set_name($set_name);
        unlink $fasta_file if -e $fasta_file;
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);
        Carp::confess("Failed to create phred reader for amplicon set ($set_name)") if not $writer;
        $self->{$set_name} = $writer;
    }

    return $self->{$set_name};
}


#< Dirs >#
sub sub_dirs {
    return (qw| classification fasta reports |), $_[0]->_sub_dirs;
}

sub _sub_dirs {
    my $self = shift;
    if ( $self->sequencing_platform eq 'sanger' ) {
        return (qw/ chromat_dir edit_dir /);
    }
    return;
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

sub original_qual_file_for_all_data {
    return $_[0]->combined_original_fasta_file.'.qual';
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

    #call a separate command for sanger
    if ( $self->sequencing_platform eq 'sanger' ) {
        my $cmd = Genome::Model::MetagenomicComposition16s::Command::ProcessSangerInstrumentData->create(
            build_id => $self->id,
            );
        unless ( $cmd->prepare_instrument_data ) {
            $self->error_message("Failed to execute mc16s process sanger");
            return;
        }
        return 1;
    }

    my @instrument_data = $self->instrument_data;
    unless ( @instrument_data ) {
        $self->error_message("No instrument data found for ".$self->description);
        return;
    }

    #write a original/unprocessed/combined fasta file
    if ( not $self->fasta_from_instrument_data ) {
        Carp::confess( "Failed to get fasta from instrument data" );
    }

    #read in orig file
    my $orig_fasta = $self->combined_original_fasta_file;
    if ( not -s $orig_fasta ) {
        Carp::confess( "Original fasta file did not get created or is blank" );
    }
    my $reader =  Genome::Model::Tools::FastQual::PhredReader->create(files => [ $orig_fasta ]);
    if ( not $reader ) {
        Carp::confess( "Could not create reader for original fasta file" );
    }
    my $min_length = $self->processing_profile->amplicon_size;
    my ($attempted, $processed, $reads_attempted, $reads_processed) = (qw/ 0 0 0 0 /);

    if ( $self->amplicon_set_names_and_primers ) {
        my %primers = $self->amplicon_set_names_and_primers;
        while ( my $fastas = $reader->read ) {
            my $fasta = $fastas->[0];
            $attempted++;
            $reads_attempted++;
            # check length here
            next unless length $fasta->{seq} >= $min_length;
            my $set_name = 'none';
            my $seq = $fasta->{seq};
            REGION: for my $region ( keys %primers ) {
                for my $primer ( @{$primers{$region}} ) {
                    if ( $seq =~ s/^$primer// ) {
                        # check length again
                        $fasta->{seq} = $seq; # set new seq w/o primer
                        $set_name = $region;
                        last REGION; # go on to write 
                    }
                }
            }
            next unless length $fasta->{seq} >= $min_length;
            $fasta->{desc} = undef; # clear description
            my $writer = $self->get_writer_for_set_name($set_name);
            $writer->write([$fasta]);
            $processed++;
            $reads_processed++;
        }
    }
    else {
        my $fasta_file = $self->processed_fasta_file_for_set_name('');
        my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]);
        while ( my $seqs = $reader->read ) {
            my $seq = $seqs->[0];
            $attempted++;
            $reads_attempted++;
            next unless length $seq->{seq} >= $min_length; #seems the read iterator returns array of array of hash
            $processed++;
            $reads_processed++;
            $writer->write( [$seq] );
        }
    }

    $self->status_message( 'DONE processing original fasta file' );

    $self->amplicons_attempted($attempted);
    $self->amplicons_processed($processed);
    $self->amplicons_processed_success( $attempted > 0 ?  sprintf('%.2f', $processed / $attempted) : 0 );
    $self->reads_attempted($reads_attempted);
    $self->reads_processed($reads_processed);
    $self->reads_processed_success( $reads_attempted > 0 ?  sprintf('%.2f', $reads_processed / $reads_attempted) : 0 );

    return 1;
}

#< Fasta/Qual Readers/Writers >#
sub fasta_from_instrument_data { #dump orig fasta file
    my $self = shift;

    for my $inst_data ( $self->instrument_data ) {
        my $temp_dir = Genome::Sys->create_temp_directory;
        if ( my @fastq_files = eval {$inst_data->dump_fastqs_from_bam( $temp_dir );} ) {
            #solexa bam
            if ( not @fastq_files ) {
                Carp::confess( "Did not get any fastq files from instrument data bam path" );
            }
            $self->status_message( "Got fastqs from bam" );
            #write fasta to original.fasta.file
            if ( not $self->append_fastq_to_orig_fasta_file( @fastq_files ) ) {
                Carp::confess( "Attempt to get fasta from fastq via bam failed" );
            }
        }
        elsif (  my $rv = eval {Genome::Sys->shellcmd( cmd => "tar zxf " . $inst_data->archive_path ." -C $temp_dir" );} ) {
            #solexa archive
            my @fastq_files = glob $temp_dir.'/*';
            if ( not @fastq_files ) {
                Carp::confess( "Did not get any fastq files from instrument data archive path" );
            }
            $self->status_message( "Untarred fastqs from archive path" );
            if ( not $self->append_fastq_to_orig_fasta_file( @fastq_files ) ) {
                Carp::confess( "Attempt to get fasta from fastq via archive path failed" );
            }
        }
        elsif ( my @fasta_files = eval{$inst_data->dump_fasta_file;} ) {
            #fasta from sff files .. 454
            if ( not @fasta_files ) {
                Carp::confess( "Did not get fasta files from inst data dump_fasta_method" );
            }
            $self->status_message( "Got fasta from sff files" ); #better message?
            if ( not $self->append_fasta_to_original_fasta_file( @fasta_files ) ) {
                Carp::confess( "Attempt to append to original fasta with with new fasta failed" );
            }
        }
        else {
            Carp::confess( "Failed to get fasta from instrument data, id: ".$inst_data->id.' format: '.$inst_data->sequencing_platform );
            #maybe just skip?? probably not
        }
    }
    return 1;
}

sub append_fasta_to_original_fasta_file {
    my ( $self, @fasta_files ) = @_;

    my $writer = $self->original_fasta_writer;
    unless ( $writer ) {
        Carp::confess( "Failed to get fasta writer to write original fasta file" );
    }

    for my $file ( @fasta_files ) { #read in one file at a time .. not likely for paired reads to be in sparate files
        my $reader =  Genome::Model::Tools::FastQual::PhredReader->create(files => [ $file ]);
        if ( not $reader ) {
            Carp::confess( "Did not get fasta reader for file: $file" );
        }
        while ( my @seqs = $reader->read ) {
            for my $seq ( @seqs ) {
                $writer->write( $seq );
            }
        }
    }
    $self->status_message( "Finished writing to original fasta file, file: ".join(' ', @fasta_files) );

    return 1;
}

sub append_fastq_to_orig_fasta_file {
    my ( $self, @fastq_files ) = @_;

    my $writer = $self->original_fasta_writer;
    unless ( $writer ) {
        Carp::confess( "Failed to get fasta writer to write original fasta file" );
    }

    my $reader = Genome::Model::Tools::FastQual::FastqReader->create( files => \@fastq_files );

    while ( my $fastqs = $reader->read ) {
        $writer->write( $fastqs );
    }

    $self->status_message( "Finished writing to original fasta file, files: ".join(' ', @fastq_files) );
    return 1;
}

sub original_fasta_writer {
    my $self = shift;

    return $self->{_fasta_writer} if $self->{_fasta_writer};

    my $fasta_file = $self->combined_original_fasta_file;
    unlink $fasta_file if -e $fasta_file;

    my $writer = Genome::Model::Tools::FastQual::PhredWriter->create(files => [ $fasta_file ]); #make sure this is right
    Carp::confess("Failed to create fasta writer to write original fasta file") if not $writer;

    $self->{_fasta_writer} = $writer;

    return $self->{_fasta_writer};
}

sub fasta_and_qual_reader_for_type_and_set_name {
    my ($self, $type, $set_name) = @_;
    
    # Sanity checks - should not happen
    die "No type given to get fasta and qual reader" unless defined $type;
    die "Invalid type ($type) given to get fasta and qual reader" unless grep { $type eq $_ } (qw/ processed oriented /);
    die "No set name given to get $type fasta and qual reader for set name ($set_name)" unless defined $set_name;

    # Get method and fasta file
    my $method = $type.'_fasta_file_for_set_name';
    my $fasta_file = $self->$method($set_name);
    return unless -e $fasta_file; # ok
    my @files = $fasta_file;
    if ( $self->sequencing_platform eq 'sanger' ) { # has qual
        $method = $type.'_qual_file_for_set_name';
        my $qual_file = $self->$method($set_name);
        push @files, $qual_file if -e $qual_file;
    }

    # Create reader, return
    my $reader =  Genome::Model::Tools::FastQual::PhredReader->create(files => \@files);
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
    my $method = $type.'_fasta_file_for_set_name';
    my $fasta_file = $self->$method($set_name);
    unlink $fasta_file if -e $fasta_file;
    my %params = ( fasta_file => $fasta_file );
    my @files = $fasta_file;
    if ( $self->sequencing_platform eq 'sanger' ) { # has qual
        $method = $type.'_qual_file_for_set_name';
        my $qual_file = $self->$method($set_name);
        unlink $qual_file if -e $qual_file;
        push @files, $qual_file;
    }

    # Create writer, return
    my $writer =  Genome::Model::Tools::FastQual::PhredWriter->create(files => \@files);
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

            $writer->write([$seq]);
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

    my @amplicon_set_names = $self->amplicon_set_names;
    if ( not @amplicon_set_names ) {
        $self->error_message('No amplicon set names for '.$self->description);
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
    @metrics{qw/ attempted success error/} = (qw/ 0 0 0 /);
    for my $name ( @amplicon_set_names ) {
        my $amplicon_set = $self->amplicon_set_for_name($name);
        next if not $amplicon_set;

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

sub special_suffixes {
    return (qw/ gz rdp2-1 rdp2-2 /);
}

sub diff_rdp2_1 { return diff_rdp(@_); }
sub diff_rdp2_2 { return diff_rdp(@_); }
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

