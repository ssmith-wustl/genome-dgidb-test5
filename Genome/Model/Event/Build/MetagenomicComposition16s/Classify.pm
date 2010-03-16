package Genome::Model::Event::Build::MetagenomicComposition16s::Classify;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::Classify {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
};

sub execute {
    my $self = shift;

    $self->_open_classification_fh
        or return;
    
    my $amplicon_iterator = $self->build->amplicon_iterator
        or return;

    my $classifier = $self->_create_classifier
        or return;

    my $processed = 0;
    my $classified = 0;
    while ( my $amplicon = $amplicon_iterator->() ) {
        my $bioseq = $amplicon->bioseq
            or next;
        $processed++;

        # Try to classify 2X - per kathie 2009mar3
        my $classification = $classifier->classify($bioseq);
        unless ( $classification ) { # try again
            $classification = $classifier->classify($bioseq);
            unless ( $classification ) { # warn , go on
                $self->error_message('Amplicon '.$amplicon->name.' did not classify for '.$self->build->description);
                next;
            }
        }
        
        $classified++;
        
        # Set and save classification
        $amplicon->classification($classification);
        unless ( $self->build->save_classification_for_amplicon($amplicon) ) {
            $self->error_message('Unable to save classification for amplicon '.$amplicon->name.'.  See above error.');
            return;
        }

        # Wrtie classification to file
        $self->_write_classification($classification)
            or return;
    }

    unless ( $processed > 0 ) {
        $self->error_message("There were no processed amplicons available to classify for ".$self->build->description);
        return;
    }

    $self->build->amplicons_processed($processed);
    $self->build->amplicons_processed_success( $processed / $self->build->amplicons_attempted );
    $self->build->amplicons_classified($classified);
    $self->build->amplicons_classified_success( $classified / $processed );

    $self->_close_classification_fh
        or return; # file is not written unless it is closed

    return 1;
}

sub _open_classification_fh {
    my $self = shift;

    my $classification_file = $self->build->classification_file;
    unlink $classification_file if -e $classification_file;
    $self->{_classification_fh} = Genome::Utility::FileSystem->open_file_for_writing(
        $classification_file
    );
    unless ( $self->{_classification_fh} ) {
        $self->error_message("Could not open classification file ($classification_file) for writing. See above error.");
        return;
    }

    return $self->{_classification_fh};
}

sub _close_classification_fh {
    return $_[0]->{_classification_fh}->close;
}

sub _create_classifier {
    my $self = shift;

    my $classifier_params = $self->processing_profile->classifier_params_as_hash;
    if ( $self->build->classifier eq 'rdp' ) {
        require Genome::Utility::MetagenomicClassifier::Rdp;
        return Genome::Utility::MetagenomicClassifier::Rdp->new();
    }
    else {
        $self->error_message("Invalid classifier (".$self->build->classifier.") for ".$self->build->description);
    }
}

sub _write_classification {
    my ($self, $classification) = @_;

    #print $classification->to_string."\n";
    $self->{_classification_fh}->print($classification->to_string."\n");
    
    return 1;
}

1;

#$HeadURL$
#$Id$
