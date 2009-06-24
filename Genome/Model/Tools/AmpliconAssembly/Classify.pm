package Genome::Model::Tools::AmpliconAssembly::Classify;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Tools::AmpliconAssembly::Classify {
    is => 'Genome::Model::Tools::AmpliconAssembly',
    # TODO classifier and params
};

sub execute {
    my $self = shift;

    my $amplicons = $self->get_amplicons
        or return;

    require Genome::Utility::MetagenomicClassifier::Rdp;
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp->new(
        #training_set => 'broad', # switched to regular set 4/14
    )
        or return;

    for my $amplicon ( @$amplicons ) {
        my $bioseq = $amplicon->get_bioseq
            or next;
        my $classification = $classifier->classify($bioseq);
        unless ( $classification ) {
            $self->error_message(
                sprintf(
                    'Can\'t get classification from RDP classifier for amplicon (%s)', 
                    $amplicon->get_name,
                )
            );
            # have a counter and error if all fail?
            # $no_classification++;
            next;
        }
        $amplicon->save_classification($classification); # error?
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
