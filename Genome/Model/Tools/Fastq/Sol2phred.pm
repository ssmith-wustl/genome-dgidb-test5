package Genome::Model::Tools::Fastq::Sol2phred;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Fastq::Sol2phred {
    is => 'Genome::Model::Tools::Fastq',
    has => [
            phred_fastq_file => {
                                 is => 'Text',
                                 is_optional => 1,
                                 doc => 'The output fastq file for phred quality sequences',
                             },
        ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless ($self->phred_fastq_file) {
        $self->phred_fastq_file($self->fastq_file .'.phred');
    }

    return $self;
}

# prints solexa ascii characters for 0-40
#perl -e 'for (0 .. 40) { print  chr($_ + 64) ."\n"; }'
# prints phred ascii characters for 0-40
#perl -e 'for (0 .. 40) { print  chr($_ + 33) ."\n"; }'

#For the new Solexa-Phred qualities with an offset of 64, the equation
#simplifies to
#  $fastq = chr(ord($solq) - 64 + 33);
#or just
#  $fastq = chr(ord($solq) - 31);

sub execute {
    my $self = shift;

    my $reader = $self->get_fastq_reader($self->fastq_file);
    my $writer = $self->get_fastq_writer($self->phred_fastq_file);
    while (my $seq = $reader->next_seq) {
        my $sol_quals_ref = $seq->qual;
        my @phred_quals;
        for my $solq (@{$sol_quals_ref}) {
            push @phred_quals, $solq - 31;
        }
        $seq->qual(\@phred_quals);
        $writer->write_fastq($seq);
    }
    $writer->close;
    $reader->close;
    return 1;
};

1;
