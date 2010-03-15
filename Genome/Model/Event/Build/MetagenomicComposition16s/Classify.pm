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

    my $amplicon_iterator = $self->build->amplicon_iterator
        or return;

    require Genome::Utility::MetagenomicClassifier::Rdp;
    #my $classifier_params = $self->processing_profile->classifier_params_as_hash; # TODO actual use them!
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp->new()
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
        
        $amplicon->classification($classification);

        unless ( $self->build->save_classification_for_amplicon($amplicon) ) {
            $self->error_message('Unable to save classification for amplicon '.$amplicon->name.'.  See above error.');
            return;
        }

        $classified++;
    }

    $self->build->amplicons_processed($processed);
    $self->build->amplicons_processed_success( $processed / $self->build->amplicons_attempted );
    $self->build->amplicons_classified($classified);
    $self->build->amplicons_classified_success( $classified / $processed );

    return 1;
}

1;

#$HeadURL$
#$Id$
