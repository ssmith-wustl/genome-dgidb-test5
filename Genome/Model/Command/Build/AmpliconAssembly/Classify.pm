package Genome::Model::Command::Build::AmpliconAssembly::Classify;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::AmpliconAssembly::Classify {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $amplicons = $self->build->get_amplicons
        or return;

    require Genome::Utility::MetagenomicClassifier::Rdp;
    my $classifier = Genome::Utility::MetagenomicClassifier::Rdp->new(
        training_set => 'broad',
    )
        or return;

    for my $amplicon ( @$amplicons ) {
        my $bioseq = $amplicon->get_bioseq
            or next;
        my $classification = $classifier->classify($bioseq);
        unless ( $classification ) {
            $self->error_message(
                sprintf(
                    'Can\'t get classification from RDP classifier for amplicon (<Amplicon %s> <Build Id %s>)', 
                    $amplicon->get_name,
                    $self->build->id,
                )
            );
            # have a counter and error if all fail?
            # $no_classification++;
            next;
        }
        $amplicon->save_classification($classification); # error?
    }

    #print $self->build->data_directory."\n"; <STDIN>;

    return 1;
}

1;

#$HeadURL$
#$Id$
