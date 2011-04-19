package Genome::Model::Tools::FastQual::PhredReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::PhredReader {
    is => 'Genome::Model::Tools::FastQual::SeqReader',
    has => [ 
        _fasta_io => { is_optional => 1, },
        _qual_io => { is_optional => 1, }, 
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my @fhs = $self->_fhs;
    $self->_fasta_io($fhs[0]);
    $self->_qual_io($fhs[1]);

    return $self;
}

sub _read {
    my $self = shift;

    my %seq;
    @seq{qw/ id desc seq /} = $self->_parse_io( $self->_fasta_io );
    return if not $seq{seq};
    $seq{seq} =~ tr/ \t\n\r//d;	# Remove whitespace

    return \%seq if not $self->_qual_io;

    my ($id, $desc, $data) = $self->_parse_io( $self->_qual_io );
    if ( not defined $id ) {
        Carp::confess("No qualities found for fasta: ".$seq{id});
    }
    if ( $seq{id} ne $id ) {
        Carp::confess('Fasta and quality ids do not match: '.$seq{id}." <=> $id");
    }

    $seq{qual} = join('', map { chr($_ + 33) } split(/[\s\n]+/, $data));
    if ( not $seq{qual} ) {
        Carp::confess("Could not convert phred quality to sanger: $data");
    }
    if ( length($seq{seq}) != length($seq{qual}) ) {
        Carp::confess("Number of qualities does not match number of bases for fasta $id. Have ".length($seq{seq}).' bases and '.length($seq{qual}).' qualities');
    }

    return [ \%seq ];
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

1;

