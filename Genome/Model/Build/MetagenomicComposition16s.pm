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
        length_of_16s_region => {
            is => 'Integer',
            default_value => 1542,
            is_constant => 1,
        },
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
            is => 'Integer',
            via => 'metrics',
            is_mutable => 1,
            where => [ name => 'amplicons classified success' ],
            to => 'value',
            doc => 'Number of amplicons that were successfully classified in this build.'
        },
    ],
};

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
    return __PACKAGE__->_resolve_subclass_name_by_sequencing_platform(@_);
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
    return ( $_[0]->sequencing_platform eq 'sanger' ) 
    ? ( '' ) 
    : (qw/ I II III /);
}

sub amplicon_sets {
    my $self = shift;

    my @amplicon_sets;
    for my $set_name ( $self->amplicon_set_names ) {
        unless ( push @amplicon_sets, $self->amplicon_set_for_name($set_name) ) {
            $self->error_message("Unable to get amplicon set ($set_name) for ".$self->description);
            return;
        }
    }

    return @amplicon_sets;
}

sub amplicon_set_for_name {
    my ($self, $set_name) = @_;

    my $amplicon_iterator = $self->_amplicon_iterator_for_name($set_name)
        or return;

    # Genome::Model::Build::MetagenomicComposition16s::AmpliconSet->create(
    # name => $set_name,
    # amplicon_iterator => $amplicon_iterator,
    # );
    
    return $amplicon_iterator;
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
    return $_[0]->_fasta_and_qual_reader($_[0]->processed_fasta_file, $_[0]->processed_qual_file);
}
    
sub processed_fasta_and_qual_writer {
    return $_[0]->_fasta_and_qual_writer($_[0]->processed_fasta_file, $_[0]->processed_qual_file);
}

# oriented
sub oriented_fasta_file {
    return $_[0]->fasta_dir.'/'.$_[0]->file_base_name.'.oriented.fasta';
}

sub oriented_qual_file {
    return $_[0]->oriented_fasta_file.'.qual';
}

sub oriented_fasta_and_qual_reader {
    return $_[0]->_fasta_and_qual_reader($_[0]->oriented_fasta_file, $_[0]->oriented_qual_file);
}

sub oriented_fasta_and_qual_writer {
    return $_[0]->_fasta_and_qual_writer($_[0]->oriented_fasta_file, $_[0]->oriented_qual_file);
}

# reader/writer helpers
sub _fasta_and_qual_reader {
    my ($self, $fasta_file, $qual_file) = @_;

    my %params = ( fasta_file => $fasta_file);
    if ( -e $qual_file ) { 
        $params{qual_file} = $qual_file;
    }

    return Genome::Utility::BioPerl::FastaAndQualReader->create(%params);
}

sub _fasta_and_qual_writer {
    my ($self, $fasta_file, $qual_file) = @_;

    my %params = ( fasta_file => $fasta_file);
    if ( $self->sequencing_platform eq 'sanger' ) { # FIXME better way? 454 don't have qual?
        $params{qual_file} = $qual_file;
    }

    return Genome::Utility::BioPerl::FastaAndQualWriter->create(%params);
}

#< Orient >#
sub orient_amplicons_by_classification {
    my $self = shift;

    my @amplicon_sets = $self->amplicon_sets
        or return;

    my $writer = $self->oriented_fasta_and_qual_writer
        or return;

    for my $amplicon_set ( @amplicon_sets ) {
        while ( my $amplicon = $amplicon_set->() ) {
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

            $writer->write_seq($bioseq);
        }
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
