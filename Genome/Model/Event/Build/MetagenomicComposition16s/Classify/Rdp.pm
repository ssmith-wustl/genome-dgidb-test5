package Genome::Model::Event::Build::MetagenomicComposition16s::Classify::Rdp;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Event::Build::MetagenomicComposition16s::Classify::Rdp {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s::Classify',
};

sub execute {
    my $self = shift;

    my $amplicon_iterator = $self->build->amplicon_iterator
        or return;

    require Genome::Utility::MetagenomicClassifier::Rdp;
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp->new()
        or return;

    my $classifier_params = $self->processing_profile->classifier_params_as_hash; # TODO actual use them!
    while ( my $amplicon = $amplicon_iterator->() ) {
        my $bioseq = $amplicon->bioseq
            or next;
        my $classification = $classifier->classify($bioseq);
        unless ( $classification ) { # ok, warn
            $self->error_message('Amplicon '.$amplicon->name.' did not classify');
            next;
        }

        $amplicon->classification($classification);
        unless ( $self->build->save_classification_for_amplicon($amplicon) ) {
            $self->error_message('Unable to save classification for amplicon '.$amplicon->name.'.  See above error.');
            return;
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
