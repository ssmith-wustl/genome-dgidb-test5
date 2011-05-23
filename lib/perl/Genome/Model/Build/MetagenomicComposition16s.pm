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
    return ( '' ) 
}

sub amplicon_sets {
    my $self = shift;

    my @amplicon_sets;
    for my $set_name ( $self->amplicon_set_names ) {
        my $amplicon_set = $self->amplicon_set_for_name($set_name);
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

#< Dirs >#
sub sub_dirs {
    return (qw| classification fasta reports |), $_[0]->_sub_dirs;
}

sub _sub_dirs { return; }

sub classification_dir {
    return $_[0]->data_directory.'/classification';
}

sub fasta_dir {
    return $_[0]->data_directory.'/fasta';
}

sub reports_dir {
    return $_[0]->data_directory.'/reports';
}

#< Files >#
sub file_base_name {
    return $_[0]->subject_name;
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

#< Fasta/Qual Readers/Writers >#
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
        $self->subject_name,
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

#< Diff>
sub files_ignored_by_diff {
    return qw(
        build.xml
        reports/Build_Initialized/report.xml
        reports/Build_Succeeded/report.xml
        reports/Composition/report.xml
        reports/Summary/report.html
        reports/Summary/report.xml
        classification/.*rdp2-1
        reports/Composition/.*counts.tsv
    );
}

sub dirs_ignored_by_diff {
    return qw(
        logs/
    );
}

1;

