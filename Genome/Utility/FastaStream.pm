package Genome::Utility::FastaStream;

use strict;
use warnings;
use Data::Dumper;


use IO::File;

sub new{
    my $class = shift;
    my $file = shift;
    my $io = IO::File->new($file);
    die "can't create io" unless $io;
    my $next_line = $io->getline;
    my $self = bless({_io => $io, next_line => $next_line },$class);
    return $self;
}

sub parse_header{
    my $self = shift;
    my $line = shift;
    my ($header) = $line =~ />(\S+)/;
    # my $header = substr($line,1,1);
    return $header;
}

sub next_line{
    my $self = shift;
    return unless $self->{next_line}; 
    if (substr($self->{next_line},0,1) eq '>'){
        return undef;
    }
    my $next_line = $self->{next_line};
    $self->{next_line} = $self->{_io}->getline;
    chomp $next_line;
    return uc $next_line;
}

sub next_header{
    my $self = shift;
    if (not defined $self->{next_line}){
        return undef;
    }elsif (substr($self->{next_line},0,1) eq '>' ){
        $self->{current_header_line} = $self->{next_line};
        $self->{current_header} = $self->parse_header( $self->{current_header_line} );
        $self->{next_line} = $self->{_io}->getline;
    }else{
        die 'not at seq end' ;
    }
    return $self->{current_header};
}

sub current_header_line{
    my $self = shift;
    my $line = $self->{current_header_line};
    chomp $line;
    return $line;
}

sub lookahead{
    my ($self, $distance) = @_;
    my $pos = $self->{_io}->tell;
    my $string = $self->{next_line};
    chomp $string;
    while (length $string < $distance){
        my $next_line =$self->{_io}->getline;
        last if substr($next_line,0,1) eq '>'; 
        chomp $next_line;
        $string.=$next_line;
    }
    $self->{_io}->seek($pos, 0);
    return substr($string, 0, $distance);
}

=pod

=head1 FastaStream
fasta file input stream used in genome-model-tools apply-diff-to-fasta

=head2 Synopsis

This streams through a fasta file, returning fasta sequence and header data;

my $fs = Genome::Utility::FastaStream->new( <file_name> );
my $first_header = $fh->next_header;
my $first_header_line = $fh->current_header_line;
my $sequence;
while (my $line = $fh->next_line){
$sequence.=$line;
}

This object can be used to read a fasta file in a streaming format.  The header returned from a fasta section is the first \S+ match following the '>' in the header line.  If you want to recreate the header line, use current_header_line() before advancing to the next fasta section

=head2 Subs

=head3 next_header
reads and returns the next header in the file.  If the current fasta sequence section hasn't been fully streamed through, an error is returned.  Used at the end of a fasta section to advance to the next section 

=head3 next_line
reads and returnts the next line in the current fasta section.  Returns undef when the end of the section is reached. 

=head3 current_header_line
Returns the entire fasta section description line of the current section, as opposed to just the first \S+ sequence after the '>'.  Useful when rewriting a file with identical section descriptions.  Does not advance through the file.

=head3 lookahead(int $distance)
returns the next $distance chars of the current fasta section, from the current position in that section.  If the lookahead distance exceeds the length of the fasta section, returns the sequence until the end of the section.   Does not advance the file.
=cut

1;
