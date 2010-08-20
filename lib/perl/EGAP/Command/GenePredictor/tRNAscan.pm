package EGAP::Command::GenePredictor::tRNAscan;

use strict;
use warnings;

use EGAP;
use Bio::SeqIO;
use GAP::Job::tRNAscan;
use File::Path qw(make_path);

class EGAP::Command::GenePredictor::tRNAscan {
    is => 'EGAP::Command::GenePredictor',
    has_optional => [
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

    # TODO put raw output into output directory
    my $seqio = Bio::SeqIO->new(-file => $self->fasta_file(), -format => 'Fasta');

    my $seq = $seqio->next_seq();
    
    # TODO Well, that last argument is a job id, which isn't necessary here but is required to create
    # the tRNAScan job. Kinda lame. Also, this dependency on GAP namespace should be removed.
    # TODO Just like RNAmmer, it'll be easier to rewrite this as a genome model tool and include
    # raw output capture then
    my $legacy_job = GAP::Job::tRNAscan->new(
        $seq,
        $self->domain,
        2112,
    );
    
    $DB::single = 1;
    $legacy_job->execute();
    
    my @features = $legacy_job->seq()->get_SeqFeatures();
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

1;
