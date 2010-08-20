package EGAP::Command::GenePredictor::RNAmmer;

use strict;
use warnings;

use EGAP;
use Bio::SeqIO;
use File::Path qw(make_path);

# TODO Revove this dependency!
use GAP::Job::RNAmmer;

class EGAP::Command::GenePredictor::RNAmmer {
    is => 'EGAP::Command::GenePredictor',
    has => [        
        domain => {
            is => 'Text',
            is_input => 1,
            valid_values => ['archaea', 'bacteria', 'eukaryota'],
            default => 'eukaryota',
        },
    ],
};

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;
    
    # TODO Will need to support multi fasta files in the near future
    my $seqio = Bio::SeqIO->new(-file => $self->fasta_file(), -format => 'Fasta');
    my $seq = $seqio->next_seq();
    
    # TODO Need to remove this dependency on the GAP namspace, plus I've never really
    # liked these jobs...
    # TODO It'll be easier to rewrite this job module as a genome model tool and include
    # raw output capture than to mess with the existing code.
    my $legacy_job = GAP::Job::RNAmmer->new(
        $seq,
        $self->domain,
        2112,
    );
    $legacy_job->execute();

    my @features = $legacy_job->seq()->get_SeqFeatures();
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

1;
