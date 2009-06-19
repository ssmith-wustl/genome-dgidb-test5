package Genome::Utility::Text;

use strict;
use warnings;

use Genome;

require Data::Dumper;
require Carp;

class Genome::Utility::Text {
};

#< Camel Case >#
sub string_to_camel_case {
    return join('', map { ucfirst } split(/[\s_]+/, $_[0]));
}

sub camel_case_to_string {
    my $camel_case = shift;
    my $join = ( @_ )
    ? $_[0]
    : ' '; 
    my @words = $camel_case =~ /([A-Z](?:[A-Z]*(?=$|[A-Z][a-z])|[a-z]*))/g;
    return join($join, map { lc } @words);
}

#< Module to/from Class >#
sub class_to_module {
    my $class = shift;
    $class =~ s/::/\//g;
    $class .= '.pm';
    return $class;
}

sub module_to_class {
    my $module = shift;
    $module =~ s#\.pm##;
    $module =~ s#/#::#g;
    return $module;
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

