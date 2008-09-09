package Genome::Model::Tools::FastaToFastq;

use strict;
use warnings;

use Genome;
use Command;

use Bio::SeqIO;
use Bio::Seq::Quality;

class Genome::Model::Tools::FastaToFastq {
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
            fasta_file => {
                           is => 'String',
                           doc => 'the fasta file path to convert to fastq',
                       },
            qual_file => {
                          is => 'String',
                          doc => 'the quality file to convert to fastq',
                      },
            fastq_file => {
                           is => 'String',
                          doc => 'the file path to write fastq format to',
                       }
    ],
    has_optional => [
                     _fasta_io => {is => 'Bio::SeqIO'},
                     _qual_io => {is => 'Bio::SeqIO'},
                     _fastq_io => {is => 'Bio::SeqIO'},
                 ],
};

sub help_brief {
    "convert from fasta sequence and qual files to a fastq format file"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 

EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    my $fasta_io = Bio::SeqIO->new(
                                   -file => '<'. $self->fasta_file,
                                   -format => 'fasta',
                               );
    unless ($fasta_io) {
        $self->error_message('Can not read fasta file '. $self->fasta_file);
        return;
    }
    $self->_fasta_io($fasta_io);
    my $qual_io = Bio::SeqIO->new(
                                  -file => '<'. $self->qual_file,
                                  -format => 'qual',
                              );
    unless ($qual_io) {
        $self->error_message('Can not read qual file '. $self->qual_file);
        return;
    }
    $self->_qual_io($qual_io);
    my $fastq_io = Bio::SeqIO->new(
                                   -file => '>'. $self->fastq_file,
                                   -format => 'fastq',
                          );
    unless ($fastq_io) {
        $self->error_message('Can not write fastq file '. $self->fastq_file);
        return;
    }
    $self->_fastq_io($fastq_io);
    return $self;
}

sub execute {
    my $self = shift;
    while (my $seq = $self->_fasta_io->next_seq) {
        my $qual = $self->_qual_io->next_seq;
        unless ($qual->length == $seq->length) {
            $self->error_message('length of sequence and quality not equal');
            return;
        }
        unless ($qual->accession_number eq $seq->accession_number) {
            $self->error_message('accession_number of sequence and quality not equal');
            return;
        }
        unless ($qual->id eq $seq->id) {
            $self->error_message('id of sequence and quality not equal');
            return;
        }
        my $seq_with_qual = Bio::Seq::Quality->new(
                                                   -seq => $seq->seq,
                                                   -qual => $qual->qual,
                                                   -force_flush => 1,
                                                   -accession_number => $seq->accession_number,
                                                   -id => $seq->id,
                                           );
        unless ($seq_with_qual) {
            $self->error_message('failed to create seq with quality object');
            return;
        }
        $self->_fastq_io->write_fastq($seq_with_qual);
    }
    return 1;
}


1;


