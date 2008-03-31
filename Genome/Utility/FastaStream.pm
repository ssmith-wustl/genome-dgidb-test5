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

1;
