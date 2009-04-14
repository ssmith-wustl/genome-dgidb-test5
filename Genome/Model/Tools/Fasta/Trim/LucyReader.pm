package Genome::Model::Tools::Fasta::Trim::LucyReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Fasta::Trim::LucyReader {
    is => 'Genome::Utility::IO::Reader',
};

#H_KM-aab04h11.g1        CLR     86      907     CLB     86      907     CLN     86      907     CLZ     0       0       CL V     54      0
sub next {
    my $self = shift;

    my $line = $self->getline
        or return;

    chomp$line;
    
    my @tokens = split(/\s+/, $line)
        or return;
    
    my %lucy;
    @lucy{qw/
        id clr_left clr_right clb_left clb_right cln_left cln_right 
        clz_left clz_right clv_left clv_right 
        /} = @tokens[0,2,3,5,6,8,9,11,12,14,15];
    
    return \%lucy;
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

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

