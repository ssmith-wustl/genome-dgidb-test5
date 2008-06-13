package GAP::Job::tRNAscan;

use strict;
use warnings;

use GAP::Job;
use Bio::Tools::Run::tRNAscanSE;
use Carp;

use base qw(GAP::Job);


sub new {

    my ($class, $seq, $job_id) = @_;

    
    my $self = { };
    bless $self, $class;
       
    unless (defined($job_id)) {
        croak 'missing job id';
    }

    $self->job_id($job_id);
    
    unless (defined($seq)) {
        croak 'missing seq object!';
    }

    unless ($seq->isa('Bio::PrimarySeqI')) {
        croak 'seq object is not a Bio::PrimaySeqI!';
    }
    
    $self->{_seq} = $seq;
    
    return $self;
    
}

sub execute {
    
    my ($self) = @_;

    $self->SUPER::execute(@_);


    my $seq = $self->{_seq};
    
    my $factory = Bio::Tools::Run::tRNAscanSE->new(
                                                   '-program' => 'tRNAscan-SE',
                                               );
    
    
    my $parser = $factory->run($seq);
    
    while (my $gene = $parser->next_prediction()) {
        $seq->add_SeqFeature($gene);
    }            
    
}

1;
