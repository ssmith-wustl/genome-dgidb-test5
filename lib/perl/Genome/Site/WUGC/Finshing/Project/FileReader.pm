package Finishing::Project::FileReader;

use strict;
use warnings;

use base 'Finfo::Reader';

use Data::Dumper;

sub _next
{
    my $self = shift;

    my $line = $self->_getline;

    return unless defined $line;

    chomp $line;
    
    my %project;
    foreach my $prop ( split(/\s+/, $line) )
    {
        my ($attr, $val) = split('=', $prop);
        $project{$attr} = $val;
    }

    return \%project;
}

1;

=pod

=head1 Name

Finishing::Project::FileReader

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/FileReader.pm $
#$Id: FileReader.pm 29849 2007-11-07 18:58:55Z ebelter $

