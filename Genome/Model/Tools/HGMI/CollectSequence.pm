package Genome::Model::Tools::HGMI::CollectSequence;

use strict;
use warnings;

use Genome;
use Command;
use Carp;
use Bio::Seq;
use Bio::SeqIO;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        'sequence_file' => { is => 'String',
                             doc => "Fasta file of contigs", },
        'minimum_length' => { is => 'Integer',
                              doc => "Minimum contig length", },
        'output' => { is => 'String',
                      doc => "Output fasta file", },

    ]
);

sub help_brief
{
    "tool for picking out only the sequences of specified length";
}

sub help_synopsis
{
    my $self = shift;
    return <<"EOS"
need to put help synopsis here
EOS
}

sub help_detail
{
    my $self = shift;
    return <<"EOS"
need to put help detail here.
EOS
}


sub execute
{
    my $self = shift;
    my $in = $self->sequence_file;
    my $out = $self->output;
    
    my $seq = new Bio::SeqIO(-file => $in, -format => "fasta");
    my $seqout = new Bio::SeqIO(-file => ">$out", -format => "fasta");
    while( my $s = $seq->next_seq() )
    {
        if(length($s->seq) >= $self->minimum_length)
        {
            $seqout->write_seq($s);
        }
    }

    return 1;
}

1;
