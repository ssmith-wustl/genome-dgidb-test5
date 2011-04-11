package Genome::Model::Tools::FastQual::FastqReader;

use strict;
use warnings;

use base 'Class::Accessor';

__PACKAGE__->mk_accessors(qw/ file _io /);

require Carp;
use Data::Dumper 'Dumper';
require Genome::Sys;

sub create {
    my ($class, %params) = @_;

    my $self = bless \%params, $class;

    my $fh = Genome::Sys->open_file_for_reading( $self->file );
    unless ( $fh ) {
        Carp::confess("Can't open fastq file.");
    }
    $self->_io($fh);
    
    return $self;
}

sub next {
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

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

