package BAP::Job::Phase2BlastP;

use strict;
use warnings;

use Bio::SeqIO;
use Bio::SearchIO;
use Carp;
use English;
use File::Temp;
use IO::File;
use Sys::Hostname;

use IPC::Run;

use base qw(GAP::Job);


sub new {

    my ($class, $seq, $db, $job_id, $core_num, $use_local_nr) = @_;
    
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

    unless (defined($db)) {
        croak 'missing db!';
    }
    $self->{_db} = $db;

    unless (defined($core_num)) {
        croak 'missing number of cores to run blast in Job!';
    }
    $self->{_core_num} = $core_num;

    unless (defined $use_local_nr) {
        $use_local_nr = 1;
    }
    $self->{_use_local_nr} = $use_local_nr;
    
    return $self;
}

sub execute {
    
    my ($self) = @_;

    my $local_db = "/opt/databases/bacterial_nr/bacterial_nr";
    if ($self->{_use_local_nr}) {
        my $fh = IO::File->new("/gscuser/bdericks/using_local_nr", "a");
        $fh->print("local NR flag set!\n");

        if (-e $local_db) {
            $self->{_db} = $local_db;
        }
        else {
            warn "Could not find local NR database, using default at " . $self->{_db} . "!";
            my $host = hostname;
            my $email_msg = "User: $ENV{USER}\n" .
                            "Host: $host\n" .
                            "Could not find local NR database at $local_db!\n";

            App::Mail->mail(
                To => 'bdericks@genome.wustl.edu',
                From => $ENV{USER} . '@genome.wustl.edu',
                Subject => 'Could not find local NR database!',
                Message => $email_msg,
            );
        } 
    }
    else {
        my $fh = IO::File->new("/gscuser/bdericks/not_using_local_nr", "a");
        $fh->print("use_local_nr flag NOT set\n");
    }

    $self->SUPER::execute(@_);

    my $seq = $self->{_seq};

    my $seq_fh = $self->_write_seqfile($seq);
    
    my ($blast_stdout, $blast_stderr);

    my $temp_fh = File::Temp->new();
    close($temp_fh);
   
    my $core_num = $self->{_core_num};

    my @cmd = (
               'blastp',
               $self->{_db},
               $seq_fh->filename(),
               '-cpus',
               $core_num,
               'E=1e-6',
               '-o',
               $temp_fh->filename(),
           );
    eval {
        
        IPC::Run::run(
                      \@cmd,
                      undef,
                      '>',
                      \$blast_stdout,
                      '2>',
                      \$blast_stderr, 
                  ) || die $CHILD_ERROR;
        
    };

    if ($EVAL_ERROR) {
        die "Failed to exec blastp: $EVAL_ERROR";
    }

    my $searchio = Bio::SearchIO->new(-format => 'blast', -file => $temp_fh->filename());

    $self->{_evidence} = { };

    RESULT: while (my $result = $searchio->next_result()) {

        if (defined($result)) {

            my $query_name = $result->query_name();
            
            HIT: while (my $hit = $result->next_hit()) {

                my $desc = $hit->description();
                my @desc = split /\s+\>/, $desc;
                
                my $hypothetical_count = 0;

                foreach my $d (@desc) { 
                    if ($d =~ /hypothetical/i) {
                        $hypothetical_count += 1;
                    }
                }
                
                if ($hypothetical_count == scalar(@desc)) {
                    next HIT;
                }
                
                my $bits = $hit->bits();

                if (defined($bits)) {

                    if ($bits > 130) {

                        while (my $hsp = $hit->next_hsp()) {

                            my $coverage = (($hsp->length('hsp') / $hsp->length('query')) * 100);
                            
                            if (
                                ($coverage >= 30) &&
                                ($hsp->percent_identity() >= 30)
                            ) {
                                
                                $self->{_evidence}->{$query_name} = 1;
                                next RESULT;
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
}

sub evidence {

    my ($self) = @_;


    return $self->{_evidence};

}

sub _write_seqfile {

    my ($self, @seq) = @_;


    my $seq_fh = File::Temp->new();

    my $seqstream = Bio::SeqIO->new(
                                    -fh     => $seq_fh,
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
