package Genome::Model::Build::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::MetagenomicClassifier::SequenceClassification;

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

#< Dirs >#
sub sub_dirs {
    return (qw| classification amplicons fasta reports sys |), $_[0]->_sub_dirs;
}

sub classification_dir {
    return $_[0]->data_directory.'/classification';
}

sub amplicon_classifications_dir {
    return $_[0]->data_directory.'/sys';
}

sub fasta_dir {
    return $_[0]->data_directory.'/fasta';
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
    return $_[0]->_files_for_amplicon_sets('classifcation');
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

    my $amplicons_processed = $self->amplicons_processed;
    if ( not defined $amplicons_processed ) {
        $self->error_message('Cannot orient apmplicons because "amplicon processed" is not set on build '.$self->description);
        return;
    }

    if ( $amplicons_processed == 0 ) {
        return 1;
    }

    my @amplicon_sets = $self->amplicon_sets
        or return;

    for my $amplicon_set ( @amplicon_sets ) {
        my $writer = $self->fasta_and_qual_writer_for_type_and_set_name('oriented', $amplicon_set->name)
            or return;

        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            my $seq = $amplicon->seq;
            next if not $seq; #OK

            my $classification = $amplicon->classification;
            unless ( $classification ) {
                warn "No classification for ".$amplicon->name;
                next;
            }

            if ( $classification->is_complemented ) {
                $seq->{seq} = reverse $seq->{seq};
                $seq->{seq} =~ tr/ATGCatgc/TACGtacg/;
            }

            $writer->write([$seq]);
        }
    }

    return 1;
}

#< Classify >#
sub classifications_files {
    my $self = shift;
}

sub classifications_files_as_string {
}

sub classification_file_for_set_name {
    my ($self, $set_name) = @_;
    
    die "No set name given to get classification file for ".$self->description unless defined $set_name;

    return sprintf(
        '%s/%s%s.%s',
        $self->classification_dir,
        $self->subject_name,
        ( $set_name eq '' ? '' : ".$set_name" ),
        lc($self->classifier),
    );
}

sub classification_file_for_amplicon_name {
    my ($self, $name) = @_;

    die "No amplicon name given to get classification file for ".$self->description unless defined $name;

    return $self->amplicon_classifications_dir."/$name.classification.stor";
}

sub classify_amplicons {
    my $self = shift;
   
    $self->status_message('Classify amplicons...');

    my @amplicon_set_names = $self->amplicon_set_names;
    Carp::confess('No amplicon set names for '.$self->description) if not @amplicon_set_names; # bad

    my $classifier;
    my %classifier_params = $self->processing_profile->classifier_params_as_hash;
    if ( $self->classifier eq 'rdp2-1' ) {
        $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Version2x1->new(%classifier_params);
    }
    elsif ( $self->classifier eq 'rdp2-2' ) {
        $classifier = Genome::Utility::MetagenomicClassifier::Rdp::Version2x2->new(%classifier_params);
    }
    else {
        $self->error_message("Invalid classifier (".$self->classifier.") for ".$self->description);
        return;
    }

    my $processed = 0;
    my $classified = 0;
    my $classification_error = 0;
    for my $name ( @amplicon_set_names ) {
        my $amplicon_set = $self->amplicon_set_for_name($name);
        next if not $amplicon_set;

        my $classification_file = $amplicon_set->classification_file;
        unlink $classification_file if -e $classification_file;
        my $writer =  Genome::Utility::MetagenomicClassifier::SequenceClassification::Writer->create(
            output => $classification_file,
            format => 'hmp_fix_ranks',
        );
        unless ( $writer ) {
            $self->error_message("Could not create classification writer for file ($classification_file) for writing.");
            return; # bad
        }

        while ( my $amplicon = $amplicon_set->next_amplicon ) {
            my $seq = $amplicon->seq
                or next;
            $processed++;

            # Try to classify 2X - per kathie 2009mar3
            my $parsed_seq = $classifier->create_parsed_seq($seq);
            my $classification = $classifier->classify_parsed_seq($parsed_seq);
            unless ( $classification ) { # try again
                $classification = $classifier->classify_parsed_seq($parsed_seq);
                unless ( $classification ) { # warn , go on
                    $self->error_message('Amplicon '.$amplicon->name.' length ('.length($seq->{seq}).') did not classify for '.$self->description."\n".$seq->{seq}."\n");
                    $classification_error++;
                    next;
                }
            }

            $classified++;

            # Save classification
            unless ( $amplicon->classification($classification) ) {
                $self->error_message(
                    'Unable to save classification for amplicon '.$amplicon->name.' for '.$self->description
                );
                return; # next??
            }

            # Write classification to file
            $writer->write_one($classification);
        }
    }

    my $attempted = $self->amplicons_attempted;
    $self->amplicons_processed($processed);
    $self->amplicons_processed_success( 
        defined $attempted and $attempted > 0 ?  sprintf('%.2f', $processed / $attempted) : 0 
    );
    $self->amplicons_classified($classified);
    $self->amplicons_classified_success( 
        $processed > 0 ?  sprintf('%.2f', $classified / $processed) : 0
    );
    $self->amplicons_classification_error($classification_error);

    $self->status_message(
        sprintf(
            'Classified %s of %s (%s) amplicons',
            $self->amplicons_processed,
            $self->amplicons_processed,
            $self->amplicons_classified,
            $self->amplicons_classified_success * 100,
        )
    );

    return 1;
}

#< Reports >#
sub summary_report {
    my $self = shift;
}

sub composition_report {
}

sub files_ignored_by_diff {
    return qw(
        build.xml
        reports/Build_Initialized/report.xml
        reports/Build_Succeeded/report.xml
        reports/Composition/report.xml
        reports/Summary/report.html
        reports/Summary/report.xml
        sys/.*classification.stor
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

