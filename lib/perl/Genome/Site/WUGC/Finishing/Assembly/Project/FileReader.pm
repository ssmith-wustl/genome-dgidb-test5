package Genome::Site::WUGC::Finishing::Assembly::Project::FileReader;

use strict;
use warnings;

use base 'Finfo::Reader';

use Data::Dumper;

sub START
{
    my $self = shift;

    my $line = $self->_getline;

    $self->fatal_msg() unless $line;

    $self->fatl_msg("Invalid file") unless $line eq '>project';
    
    return 1;
}

sub _next
{
    my $self = shift;

    my %project;
    my $prev_pos;
    while ( 1 )
    {
        $prev_pos = $self->io->tell;
        
        my $line = $self->_getline;
        last unless defined $line;
        chomp $line;

        if ( $line eq '>project' )
        {
            $self->io->seek($prev_pos, 0);
            last;
        }
        
        my ($attr, $val) = split('=', $line);
        $project{$attr} = $val;
    }

    print Dumper(\%project);
    
    return unless %project;

    return \%project;
}

1;

=pod

=head1 Name

Genome::Site::WUGC::Finishing::Project::FileReader

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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Assembly/Project/FileReader.pm $
#$Id: FileReader.pm 31534 2008-01-07 22:01:01Z ebelter $

