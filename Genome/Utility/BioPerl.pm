package Genome::Utility::BioPerl;

use strict;
use warnings;

use Genome;

require Bio::SeqIO;
require Bio::Seq;
require Bio::Seq::Quality;
use Data::Dumper 'Dumper';

class Genome::Utility::BioPerl {
};

sub _create_bioseq_io {
    my ($self, $fh, $format) = @_;

    my $bioseq_io;
    eval{
        $bioseq_io = Bio::SeqIO->new(
            '-fh' => $fh,
            '-format' => $format,
        ); 
    };
    unless ( $bioseq_io ) {
        $self->error_message(
            sprintf(
                "Failed to create %s Bio::SeqIO => %s",
                $format,
                $@,
            )
        );
        return;
    }

    return $bioseq_io;
}

sub create_bioseq_writer {
    my ($self, $file, $format) = @_;

    my $fh = Genome::Utility::FileSystem->open_file_for_writing($file)
        or return;

    $format = 'fasta' unless defined $format;

    return $self->_create_bioseq_io($fh, $format);
}

sub create_bioseq_reader {
    my ($self, $file, $format) = @_;

    my $fh = Genome::Utility::FileSystem->open_file_for_reading($file)
        or return;

    $format = 'fasta' unless defined $format;

    return $self->_create_bioseq_io($fh, $format);
}

sub create_bioseq_from_fasta_and_qual {
    my ($self, %params) = @_;

    $self->validate_fasta_and_qual_bioseq($params{fasta}, $params{qual})
        or return;
    
    my $bioseq;
    eval {
        $bioseq = Bio::Seq::Quality->new(
            '-id' => $params{fasta}->id,
            '-desc' => $params{fasta}->desc,
            '-alphabet' => 'dna',
            '-force_flush' => 1,
            '-seq' => $params{fasta}->seq,
            '-qual' => $params{qual}->qual,
        ),
    };

    if ( $@ ) {
        $self->error_message(
            "Can't create combined fasta/qual (".$params{fasta}->id.") bioseq: $@"
        );
        return;
    }

    return $bioseq;
}

sub validate_fasta_and_qual_bioseq {
    my ($self, $fasta, $qual) = @_;

    unless ( $fasta ) {
        die $self->class." => No fasta given to validate.";
    }

    unless ( $qual ) {
        die $self->class." => No qual given to validate.";
    }

    unless ( $fasta->seq =~ /^[ATGCNX]+$/i ) {
        die sprintf(
            "%s => Illegal characters found in fasta (%s) seq:\n%s",
            $self->class,
            $fasta->id,
            $fasta->seq,
        );
    }

    unless ( length($fasta->seq) == scalar(@{$qual->qual}) ) {
        die sprintf(
            '%s => Unequal length for fasta (%s) and quality (%s)',
            $self->class,
            $fasta->id,
            $qual->id,
        );
    }

    return 1;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
