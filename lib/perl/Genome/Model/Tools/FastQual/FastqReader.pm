package Genome::Model::Tools::FastQual::FastqReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::FastQual::FastqReader {
    is => 'Genome::Model::Tools::FastQual::SeqReader',
    has => [
        _fhs => { is_optional => 1, is_many => 1, }, 
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    # Fastq files
    my @files = $self->files;
    if ( not @files ) {
        Carp::confess("No fastq files given");
    }
    elsif ( @files > 2 ) {
        Carp::confess('Too many fastq files given to read');
    }

    my  @fhs;
    for my $file ( @files ) {
        my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
        if ( not $fh ) {
            $self->error_message('Failed to open fastq file: '.$@);
            return;
        }
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);

    return $self;
}

sub next {
    my $self = shift;

    my @fastqs;
    my @fhs = $self->_fhs;
    for my $fh ( @fhs ) {
        my $fastq = $self->_next($fh);
        next unless $fastq;
        push @fastqs, $fastq;
    }
    return unless @fastqs; # ok

    unless ( @fastqs == @fhs ) { # not ok??
        Carp::confess("Have ".scalar(@fhs)." files but only got ".scalar(@fastqs)." fastqs: ".Dumper(\@fastqs));
    }

    return \@fastqs;
}

sub _next {
    my ($self, $fh) = @_;

    my $line = $fh->getline
        or return; #ok
    chomp $line;
    my ($id, $desc) = split(/\s/, $line, 2);
    $id =~ s/^@//;

    my $seq = $fh->getline;
    chomp $seq; 

    $fh->getline; 
    
    my $qual = $fh->getline;
    chomp $qual;

    return {
        id => $id,
        desc => $desc,
        seq => $seq,
        qual => $qual,
    };
}

1;

