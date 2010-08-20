package EGAP::Command::GenePredictor::RfamScan;

use strict;
use warnings;

use EGAP;
use Bio::SeqIO;
use GAP::Job::RfamScan;
use File::Path qw(make_path);

class EGAP::Command::GenePredictor::RfamScan {
    is => 'EGAP::Command::GenePredictor',
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

    # TODO Put raw output into output directory

    my $seqio = Bio::SeqIO->new(-file => $self->fasta_file(), -format => 'Fasta');

    my $seq = $seqio->next_seq();
    
    # TODO Remove this dependency on GAP
    # TODO Also, raw output capture will be much easier to do if I just rewrite
    # the whole tool as a genome model tool
    my $legacy_job = GAP::Job::RfamScan->new(
                                             $seq,
                                             2112,
                                         );
    
    $legacy_job->execute();
    
    my @features = $legacy_job->seq()->get_SeqFeatures();
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

1;
