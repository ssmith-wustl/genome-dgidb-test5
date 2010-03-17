package Genome::Model::Build::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

require Bio::SeqIO;
require Bio::Seq;
require Bio::Seq::Quality;
use Carp 'confess';
use Data::Dumper 'Dumper';
require Genome::Utility::MetagenomicClassifier::SequenceClassification;

class Genome::Model::Build::MetagenomicComposition16s {
    is => 'Genome::Model::Build',
    is_abstract => 1,
    sub_classification_method_name => '_resolve_subclass_name',
    has => [
        map( { 
                $_ => { via => 'processing_profile' } 
            } Genome::ProcessingProfile::MetagenomicComposition16s->params_for_class 
        ),
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
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons classified success' ],
            to => 'value',
            doc => 'Number of amplicons that were successfully classified in this build.'
        },
    ],
};

sub length_of_16s_region {
    return 1542;
}

#< UR >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;
    return $self if $class eq __PACKAGE__; # so UR doesn't try to re-subclass

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
    Genome::Utility::FileSystem->create_directory($self->data_directory )
        or return;

    for my $dir ( $self->sub_dirs ) {
        Genome::Utility::FileSystem->create_directory( $self->data_directory."/$dir" )
            or return;
    }

    return $self;
}

sub _resolve_subclass_name { # only temporary, subclass will soon be stored
    my $class = shift;

    my $sequencing_platform;
    if (ref($_[0])) {
        if ($_[0]->isa(__PACKAGE__) || $_[0]->can('model')) {
            $sequencing_platform = $_[0]->model->sequencing_platform;
        }
    } else {
        my %params = @_;
        my $model_id = $params{model_id};
        $class->_validate_model_id($params{model_id})
            or return;
        my $model = Genome::Model->get($params{model_id});
        unless ( $model ) {
            confess "Can't get model for id: .".$params{model_id};
        }
        $sequencing_platform = $model->sequencing_platform;
    }

    return unless $sequencing_platform;

    return 'Genome::Model::Build::MetagenomicComposition16s::'.Genome::Utility::Text::string_to_camel_case($sequencing_platform);
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

#< Dirs >#
sub sub_dirs {
    return (qw/ classification fasta reports /), $_[0]->_sub_dirs;
}

sub classification_dir {
    return $_[0]->data_directory.'/classification';
}

sub fasta_dir {
    return $_[0]->data_directory.'/fasta';
}

#< Files >#
sub file_base_name {
    return $_[0]->subject_name;
}

# processsed
sub processed_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.processed.fasta';
}

sub processed_qual_file {
    return $_[0]->processed_fasta_file.'.qual';
}

sub processed_fasta_and_qual_reader {
    return $_[0]->fasta_and_qual_reader($_[0]->processed_fasta_file, $_[0]->processed_qual_file);
}
    
sub processed_fasta_and_qual_writer {
    return $_[0]->fasta_and_qual_writer($_[0]->processed_fasta_file, $_[0]->processed_qual_file);
}

# oriented
sub oriented_fasta { return oriented_fasta_file(@_); }
sub oriented_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.oriented.fasta';
}

sub oriented_qual { return oriented_qual_file(@_); }
sub oriented_qual_file {
    return $_[0]->oriented_fasta_file.'.qual';
}

sub oriented_fasta_and_qual_reader {
    return $_[0]->fasta_and_qual_reader($_[0]->oriented_fasta_file, $_[0]->oriented_qual_file);
}

sub oriented_fasta_and_qual_writer {
    return $_[0]->fasta_and_qual_writer($_[0]->oriented_fasta_file, $_[0]->oriented_qual_file);
}

# reader/writer helpers
sub fasta_and_qual_reader {
    my ($self, $fasta_file, $qual_file) = @_;

    my $fasta_reader = $self->_bioseq_reader($fasta_file, 'fasta')
        or return;
    my $qual_reader;
    if ( -e $qual_file ) { 
         $qual_reader = $self->_bioseq_reader($qual_file, 'qual')
            or return;
    }

    return sub {
        my $fasta = $fasta_reader->next_seq
            or return;
        
        return $fasta unless $qual_reader;
        
        my $qual = $qual_reader->next_seq;

        my $bioseq = $self->_create_bioseq_from_fasta_and_qual($fasta, $qual)
            or die;

        return $bioseq;
    };
}

sub fasta_and_qual_writer {
    my ($self, $fasta_file, $qual_file) = @_;

    my @writers;
    push @writers, $self->_bioseq_writer($fasta_file, 'fasta')
        or return;
    if ( $self->sequencing_platform eq 'sanger' ) { # FIXME better way? 454 don't have qual?
        push @writers, $self->_bioseq_writer($qual_file, 'qual')
            or return;
    }

    return sub {
        my $bioseq = shift;

        for my $writer ( @writers ) {
            eval { $writer->write_seq($bioseq); };
            if ( $@ ) {
                $self->error_message(
                    sprintf(
                        "Can't write bioseq (%s) for %s: %s",
                        $bioseq->id,
                        $self->description,
                        $@,
                    )
                );
                return;
            }
        }
        
        return 1;
    };
}

sub _bioseq_io {
    my ($self, $file, $format, $rw) = @_;

    my $bioseq_io;
    eval{
        $bioseq_io = Bio::SeqIO->new(
            '-file' => $rw.$file,
            '-format' => $format,
        ); 
    };
    unless ( $bioseq_io ) {
        $self->error_message("Can't open $format file ($file) for build (".$self->id."): $@");
        return;
    }

    return $bioseq_io;
}

sub _bioseq_reader {
    my ($self, $file, $format) = @_;

    die "No file given to open bioseq writer" unless $file;
    die "No format given to open bioseq writer" unless $format;

    Genome::Utility::FileSystem->validate_file_for_reading($file)
        or return;

    return $self->_bioseq_io($file, $format, '<');
}

sub _bioseq_writer {
    my ($self, $file, $format) = @_;

    die "No file given to open bioseq writer" unless $file;
    die "No format given to open bioseq writer" unless $format;
    
    unlink $file if -e $file;
    Genome::Utility::FileSystem->validate_file_for_writing($file)
        or return;

    return $self->_bioseq_io($file, $format, '>');
}

sub _create_bioseq_from_fasta_and_qual {
    my ($self, $fasta, $qual) = @_;

    $self->_validate_fasta_and_qual_bioseq($fasta, $qual)
        or return;
    
    my $bioseq;
    eval {
        $bioseq = Bio::Seq::Quality->new(
            '-id' => $fasta->id,
            '-desc' => $fasta->desc,
            '-alphabet' => 'dna',
            '-force_flush' => 1,
            '-seq' => $fasta->seq,
            '-qual' => $qual->qual,
        ),
    };

    if ( $@ ) {
        $self->error_message("Can't create combined fasta/qual (".$fasta->id.") bioseq for ".$self->description.": $@");
        return;
    }

    return $bioseq;
}

sub _validate_fasta_and_qual_bioseq {
    my ($self, $fasta, $qual) = @_;

    unless ( $fasta ) {
        $self->error_message("No fasta given to validate for ".$self->description);
        return;
    }

    unless ( $qual ) {
        $self->error_message("No qual given to validate for ".$self->description);
        return;
    }

    unless ( $fasta->seq =~ /^[ATGCNX]+$/i ) {
        $self->error_message(
            sprintf(
                "Illegal characters found in fasta (%s) seq:\n%s",
                $fasta->id,
                $fasta->seq,
            )
        );
        return;
    }

    unless ( $fasta->length == $qual->length ) {
        $self->error_message(
            sprintf(
                'Unequal length for fasta (%s) and quality (%s)',
                $fasta->id,
                $qual->id,
            )
        );
        return;
    }
    
    return 1;
}

#< Orient >#
sub orient_amplicons_by_classification {
    my $self = shift;

    my $amplicon_iterator = $self->amplicon_iterator
        or return;

    my $writer = $self->oriented_fasta_and_qual_writer
        or return;
    
    while ( my $amplicon = $amplicon_iterator->() ) {
        my $bioseq = $amplicon->bioseq;
        unless ( $bioseq ) { 
            # OK
            next;
        }
        
        my $classification = $amplicon->classification;
        unless ( $classification ) {
            warn "No classification for ".$amplicon->name;
            next;
        }

        if ( $classification->is_complemented ) {
            eval { $bioseq = $bioseq->revcom; };
            unless ( $bioseq ) {
                die "Can't reverse complement biobioseq for amplicon (".$amplicon->name."): $!";
            }
        }

        $writer->($bioseq);
    }

    return 1;
}

#< Classification >#
sub classification_file {
    my $self = shift;

    return $self->classification_dir.'/classifications.tsv';
    #return $self->classification_dir.'/'.$self->classifier.'.tsv';
}

sub classification_file_for_amplicon {
    my ($self, $amplicon) = @_;
    return $self->classification_dir.'/'.$amplicon->name.'.classification.stor';
}
    
sub load_classification_for_amplicon {
    my ($self, $amplicon) = @_;

    unless ( $amplicon ) {
        $self->error_message('No amplicon to get classification for '.$self->description);
        die;
    }

    my $classification_file = $self->classification_file_for_amplicon($amplicon);
    return unless -s $classification_file; # ok

    my $classification;
    eval {
        $classification = Storable::retrieve($classification_file);
    };
    unless ( $classification ) {
        $self->error_message("Can't retrieve amplicon's (".$amplicon->name.") classification from file ($classification_file) for ".$self->description);
        die;
    }

    $amplicon->classification($classification);

    return 1;
}

sub save_classification_for_amplicon {
    my ($self, $amplicon) = @_;

    unless ( $amplicon ) {
        $self->error_message('No amplicon to save classification for '.$self->description);
        die;
    }

    my $classification = $amplicon->classification;
    unless ( $classification ) {
        $self->error_message('No classification to save for amplicon ('.$amplicon->name.') for '.$self->description);
        die;
    }

    my $classification_file = $self->classification_file_for_amplicon($amplicon);
    unlink $classification_file if -e $classification_file;
    eval {
        Storable::store($classification, $classification_file);
    };
    if ( $@ ) {
        $self->error_message("Can't store amplicon's (".$amplicon->name.") classification to file ($classification_file) for ".$self->description);
        die;
    }

    return 1;
}

#< Reports >#
sub summary_report {
    my $self = shift;
}

sub composition_report {
}

1;

#$HeadURL$
#$Id$
