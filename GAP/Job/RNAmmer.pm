package GAP::Job::RNAmmer;

use strict;
use warnings;

use GAP::Job;
use Bio::SeqIO;
use Bio::Tools::GFF;
use Carp;
use English;
use File::Temp qw/tempdir/;
use IO::File;
use IPC::Run;

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

    my $seq_fh = $self->_write_seqfile($seq);
    
    my ($rnammer_stdout, $rnammer_stderr);

    my $temp_fh       = File::Temp->new();
    my $temp_filename = $temp_fh->filename();
    
    close($temp_fh);
    
    my $tempdir = tempdir(CLEANUP => 1);
    
    my @cmd = (
               'rnammer',
               '-S',
               'bac',
               '-T',
               $tempdir,
               '-gff',
               $temp_filename,
           );
    eval {
        
        IPC::Run::run(
                      \@cmd,
                      IO::File->new($seq_fh->filename()),
                      '>',
                      \$rnammer_stdout,
                      '2>',
                      \$rnammer_stderr, 
                  ) || die $CHILD_ERROR;
        
    };

    if ($EVAL_ERROR) {
        die "Failed to exec rnammer: $EVAL_ERROR";
    }

    my $gff = Bio::Tools::GFF->new(-file => $temp_filename, -gff_version => 1);

    while (my $feature = $gff->next_feature()) {
    
        $seq->add_SeqFeature($feature);

    }
        
}

sub genes {

    my ($self) = @_;


    return $self->{_genes};

}

sub _write_seqfile {

    my ($self, @seq) = @_;


    my $seq_fh = File::Temp->new();

    my $seqstream = Bio::SeqIO->new(
                                    -fh => $seq_fh,
                                    -format => 'Fasta',
                                );

    foreach my $seq (@seq) {
        $seqstream->write_seq($seq);
    }

    close($seq_fh);
    $seqstream->close();

    return $seq_fh;
    
}

1;
