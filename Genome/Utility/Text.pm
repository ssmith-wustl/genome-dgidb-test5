package Genome::Utility::Text;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
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

#< Params as String and Hash >#
sub param_string_to_hash {
    my $param_string = shift;

    unless ( $param_string ) {
        Carp::cluck('No param string to convert to hash');
        return;
    }

    unless ($param_string =~ m#^-#) {
        Carp::cluck('Param string must start with a dash (-)');
        return;
    }

    my %params;
    my @params = split(/\s?(\-{1,2}\D[\w\d]*)\s?/, $param_string);
    shift @params;
    for ( my $i = 0; $i < @params; $i += 2 ) {
        my $key = $params[$i];
        $key =~ s/^\-{1,2}//;
        Carp::cluck("Malformed param string ($param_string).  Found empty dash (-).") if $key eq '';
        my $value = $params[$i + 1];
        $params{$key} = ( $value ne '' ? $value : 1 );
    }
    
    #print Dumper(\@params, \%params);
    return %params;
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

