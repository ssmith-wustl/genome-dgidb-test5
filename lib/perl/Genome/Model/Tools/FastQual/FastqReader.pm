package Genome::Model::Tools::FastQual::FastqReader;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ files _fhs /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Model::Tools::FastQual::FastqReader;

sub create {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    # Fastq files
    my $files = $self->files;
    unless ( defined $files ) {
        Carp::confess("No fastq files given");
    }
    unless ( ref $files ) {
        # be nice, set to aryref
        $files = $self->files([ $files ]);
    }

    if ( @$files == 0 ) {
        Carp::confess('No fastq files given to read');
    }
    elsif ( @$files > 2 ) {
        Carp::confess('Too many fastq files given to read');
    }

    my  @fhs;
    for my $file ( @$files ) {
        my $fh = Genome::Sys->open_file_for_reading($file);
        unless ( $fh ) {
            Carp::confess("Can't open fastq file.");
        }
        push @fhs, $fh;
    }
    $self->_fhs(\@fhs);

    return $self;
}

sub next {
    my $self = shift;

    my @fastqs;
    my $fhs = $self->_fhs;
    for my $fh ( @$fhs ) {
        my $fastq = $self->_next($fh);
        next unless $fastq;
        push @fastqs, $fastq;
    }
    return unless @fastqs; # ok

    unless ( @fastqs == @$fhs ) { # not ok??
        Carp::confess("Have ".scalar(@$fhs)." files but only got ".scalar(@fastqs)." fastqs: ".Dumper(\@fastqs));
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

