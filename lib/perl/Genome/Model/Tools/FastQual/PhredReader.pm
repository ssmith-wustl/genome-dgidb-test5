package Genome::Model::Tools::FastQual::PhredReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::PhredReader {
    is => 'Genome::Model::Tools::FastQual::SeqReaderWriter',
    has => [
        _fasta_io => { is_optional => 1, }, 
        _qual_io => { is_optional => 1, },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @files = $self->files;
    if ( not @files ) {
        Carp::confess("No fasta files given");
    }
    elsif ( @files > 2 ) {
        Carp::confess('Too many fastq files given to read');
    }

    my $fasta_fh = eval{ Genome::Sys->open_file_for_reading($files[0]) };
    if ( not defined $fasta_fh ) {
        Carp::confess('Failed to open fasta file ('.$files[0].'): '.$@);
    }
    $self->_fasta_io($fasta_fh);
    
    if ( $files[1] ) {
        my $qual_fh = eval{ Genome::Sys->open_file_for_reading($files[1]); };
        if ( not defined $qual_fh ) {
            Carp::confess('Failed to open quality file ('.$files[1].'): '.$@);
        }
        $self->_qual_io($qual_fh);
    }

    return $self;
}

sub next {
    my $self = shift;

    my $seq = $self->_read_seq;
    return if not $seq;

    if ( $self->_qual_io ) {
        $self->_add_qual($seq);
    }

    return [ $seq ];
}

sub _parse_io {
    my ($self, $io) = @_;

    local $/ = "\n>";

    my $entry = $io->getline;
    return unless defined $entry;
    chomp $entry;

    if ( $entry eq '>' )  { # very first one
        $entry = $io->getline;
        return unless $entry;
        chomp $entry;
    }

    my ($header, $data) = split(/\n/, $entry, 2);
    defined $data && $data =~ s/>//g;

    my ($id, $desc) = split(/\s+/, $header);
    if ( not defined $id or $id eq '' ) {
        Carp::confess("Cannot get id from header ($header) for entry:\n$entry");
    }
    $id =~ s/>//;

    if ( not defined $data ) {
        Carp::confess("No data found for $id entry:\n$entry");
    }

    return ($id, $desc, $data);
}

sub _read_seq {
    my $self = shift;

    my ($id, $desc, $seq) = $self->_parse_io( $self->_fasta_io )
        or return;

    $seq =~ tr/ \t\n\r//d;	# Remove whitespace

    return {
        id => $id,
        desc => $desc,
        seq => $seq,
    };
}

sub _add_qual {
    my ($self, $seq) = @_;

    my ($id, $desc, $data) = $self->_parse_io( $self->_qual_io );
    if ( not defined $id ) {
        Carp::confess("No qualities found for fasta: ".$seq->{id});
    }
    if ( $seq->{id} ne $id ) {
        Carp::confess('Fasta and quality ids do not match: '.$seq->{id}." <=> $id");
    }

    my @quals = split(/[\s\n]+/, $data);
    if ( not @quals ) {
        Carp::confess("Could not split quality string for $id: $data");
    }
    if ( length( $seq->{seq} ) != @quals ) {
        Carp::confess("Number of qualities does not match number of bases for fasta $id. Have ".length($seq->{seq}).' bases and '.scalar(@quals).' qualities');
    }

    $seq->{qual} = \@quals;

    return 1;
}

1;

