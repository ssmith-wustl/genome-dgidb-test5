package Genome::Model::Tools::FastQual::FastqSetWriter;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ id files _writers _write_strategy stats /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Model::Tools::FastQual::FastqWriter;

my $id = 0;
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
        Carp::confess('No fastq files given to write');
    }
    elsif ( @$files > 2 ) {
        Carp::confess('Too many fastq files given to write');
    }

    # Writers
    my  @writers;
    for my $file ( @$files ) {
        my $writer = Genome::Model::Tools::FastQual::FastqWriter->create(
            file => $file,
        );
        unless ( $writer ) {
            Carp::confess("Can't open fastq file.");
        }
        push @writers, $writer;
    }
    $self->_writers(\@writers);
    $self->_write_strategy( 
        @writers == 1 ? '_collate' : '_separate'
    );

    $self->id(++$id);

    return $self;
}

sub write {
    my ($self, $fastqs) = @_;

    unless ( $fastqs ) {
        Carp::confess("No fastqs to write");
    }

    my $write_strategy = $self->_write_strategy;
    return $self->$write_strategy($fastqs);
}
    
sub _separate {
    my ($self, $fastqs) = @_;

    for my $i (0..1) {
        $self->_writers->[$i]->write($fastqs->[$i])
            or Carp::confess("Can't write fastq: ".Dumper($fastqs->[$i]));
    }

    return 1;
}

sub _collate {
    my ($self, $fastqs)  = @_;

    my $writer = $self->_writers->[0];
    for my $fastq ( @$fastqs ) {
        $writer->write($fastq)
            or Carp::confess("Can't write fastq: ".Dumper($fastq));
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
