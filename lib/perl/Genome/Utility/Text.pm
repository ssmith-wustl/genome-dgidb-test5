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
    my $string = shift;
    unless ( $string ) {
        Carp::cluck('No string to convert to camel case');
        return;
    }
    return join('', map { ucfirst } split(/[\s_]+/, $string));
}

sub camel_case_to_words {
    my $camel_case = shift;
    unless ( $camel_case ) {
        Carp::cluck('No camel case to get words');
        return;
    }
    my @words = split( /(?=(?<![A-Z])[A-Z])|(?=(?<!\d)\d)/, $camel_case); #split on the first capital or the start of a number
    return @words;
}

sub camel_case_to_string {
    my @words = camel_case_to_words(shift);
    my $join = ( @_ ) ? $_[0] : ' '; 
    return join($join, map { lc } @words);
}

sub camel_case_to_capitalized_words {
    my @words = camel_case_to_words(shift);
    my $join = ( @_ ) ? $_[0] : ' '; 
    return join($join, map { ucfirst } @words);
}

#< Module to/from Class >#
sub class_to_module {
    my $class = shift;
    unless ( $class ) {
        Carp::cluck('No class to convert to module');
        return;
    }
    $class =~ s/::/\//g;
    $class .= '.pm';
    return $class;
}

sub module_to_class {
    my $module = shift;
    unless ( $module ) {
        Carp::cluck('No module to convert to class');
        return;
    }
    $module =~ s#\.pm##;
    $module =~ s#/#::#g;
    return $module;
}

#< Params as String and Hash >#
sub param_string_to_hash {
    my ($param_string, $value_split) = @_;
    #my $param_string = shift;

    unless ( $param_string ) {
        Carp::cluck('No param string to convert to hash');
        return;
    }

    unless ($param_string =~ m#^-#) {
        Carp::cluck('Param string must start with a dash (-)');
        return;
    }

    my %params;
    my @params = split(/\s?(\-{1,2}\D[\w\d\-]*)\s?/, $param_string);
    shift @params;
    for ( my $i = 0; $i < @params; $i += 2 ) {
        my $key = $params[$i];
        $key =~ s/^\-{1,2}//;
        Carp::cluck("Malformed param string ($param_string).  Found empty dash (-).") if $key eq '';
        my $value = $params[$i + 1];
        #$params{$key} = ( $value ne '' ? $value : 1 );
        $value =~ s/\s*$//;
        if ( $value eq '' ) {
            $params{$key} = 1;
        }
        elsif ( defined $value_split ) { 
            $params{$key} = [ split($value_split, $value) ];
        }
        else {
            $params{$key} = $value;
        }
    }

    #print Dumper(\@params, \%params);
    return %params;
}

sub hash_to_string {
    my ($hash) = @_;
    my @params;
    for my $key (sort keys %$hash) {
        next unless defined $hash->{$key};
        push @params, "$key => '" . $hash->{$key} . "'";
    }
    return join(",", @params);
}

#< Sanitize for File System >#
sub sanitize_string_for_filesystem {
    my $string = shift;
    unless ( $string ) {
        Carp::cluck('No string to sanitize for filesystem.');
        return;
    }
    my $OK_CHARS = '-a-zA-Z0-9_./';
    $string =~ s/[^$OK_CHARS]/_/go;
    return $string;
}

#< Capitalize >#
sub capitalize_words {
    my $string = shift;

    unless ( $string ) {
        Carp::confess('No string to capitalize words.');
    }

    my $seps = join('', ' ', @_); # allow other separators
    my $regexp = qr/[$seps]+/;

    return join(' ', map { ucfirst } split($regexp, $string));
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

