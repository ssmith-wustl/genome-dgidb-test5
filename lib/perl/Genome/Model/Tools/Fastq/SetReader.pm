package Genome::Model::Tools::Fastq::SetReader;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ fastq_files _readers /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Model::Tools::FastQual::FastqReader;

sub create {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    # Fastq files
    my $fastq_files = $self->fastq_files;
    unless ( defined $fastq_files ) {
        Carp::confess("No fastq files given");
    }
    unless ( ref $fastq_files ) {
        # be nice, set to aryref
        $fastq_files = $self->fastq_files([ $fastq_files ]);
    }

    if ( @$fastq_files == 0 ) {
        Carp::confess('No fastq files given to read');
    }
    elsif ( @$fastq_files > 2 ) {
        Carp::confess('Too many fastq files given to read');
    }

    # Readers
    my  @readers;
    for my $fastq_file ( @$fastq_files ) {
        my $reader = Genome::Model::Tools::FastQual::FastqReader->create(
            fastq_file => $fastq_file,
        );
        unless ( $reader ) {
            Carp::Confess("Can't open fastq file.");
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
