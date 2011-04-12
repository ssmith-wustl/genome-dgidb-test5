package Genome::Model::Tools::FastQual::FastqSetReader;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ files _readers /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Model::Tools::FastQual::FastqReader;

sub Xcreate {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    my $fh = Genome::Sys->open_file_for_reading( $self->file );
    unless ( $fh ) {
        Carp::confess("Can't open fastq file.");
    }
    $self->_io($fh);
    
    return $self;
}

sub Xnext {
    my $self = shift;

    my $fh = $self->_io;
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

    # Readers
    my  @readers;
    for my $file ( @$files ) {
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create(
            file => $file,
        );
        unless ( $reader ) {
            Carp::confess("Can't open fastq file.");
        }
        push @readers, $reader;
    }
    $self->_readers(\@readers);

    return $self;
}

sub next {
    my $self = shift;

    my @fastqs;
    my $readers = $self->_readers;
    for my $reader ( @$readers ) {
        my $fastq = $reader->next;
        next unless $fastq;
        push @fastqs, $fastq;
    }
    return unless @fastqs; # ok

    unless ( @fastqs == @$readers ) { # not ok??
        Carp::confess("Have ".scalar(@$readers)." readers but only got ".scalar(@fastqs)." fastqs: ".Dumper(\@fastqs));
    }

    return \@fastqs;
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
