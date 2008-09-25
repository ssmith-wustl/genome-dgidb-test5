package Genome::Utility::IO::SeparatedValueReader;

use strict;
use warnings;

use above 'Genome';

use Data::Dumper;

class Genome::Utility::IO::SeparatedValueReader {
    is => 'Genome::Utility::IO::Reader', 
    has => [
    headers => {
        type => 'Array',
        doc => 'Headers for the file.  If none given, they will be retrieved from the input.'
    },
    separator => {
        type => 'String',
        default => ',',
        doc => 'The value of the separator character.  Default: ","'
    },
    is_regex => {
        type => 'Boolean',
        default => 0,
        doc => 'Interprets separator as regex'
    },
    ],
};

   
sub line_number {
    return $_[0]->{_line_number};
}

sub reset { 
    my $self = shift;

    $self->SUPER::reset;
    $self->{_line_number} = 0;

    if ( $self->_headers_were_in_input ) { # skip to data
        $self->getline;
    }

    return 1;
}

sub getline { 
    my $self = shift;

    my $line = $self->SUPER::getline
        or return;

    $self->_increment_line_number;

    return $line;
}

sub create {
    my ($class, %params) = @_;

    my $headers = delete $params{headers}; # prevent UR from sorting our headers!
    my $self = $class->SUPER::create;

    my $sep = $self->separator;
    if ($self->is_regex){ 
        # Adding -1 as the LIMIT argument to split ensures that the correct # of values on the line 
        #  are returned, regardless of empty trailing results
        $self->{_split} = sub{ return split(/$sep/, $_[0], -1) };
    }
    else{
        $self->{_split} = sub{ return split(/\Q$sep\E/, $_[0], -1) };
    }

    if ( $headers ) {
        $self->headers($headers);
    }
    else {
        my @headers = $self->_getline_and_split;
        $self->error_msg("No headers found in io")
            and return unless @headers;
        $self->{_headers_were_in_input} = 1;
        return $self->headers(\@headers);
    }

    return $self;
}

sub next {
    my $self = shift;

    my @values = $self->_getline_and_split
        or return;
    foreach (@values) { # FIXME param this replacing quotes and spaces?
        $_ =~ s/^\s*['"]?//;
        $_ =~ s/['"]?\s*$//;
    }

    $self->fatal_msg (
        sprintf(
            'Expected %d values, got %d on line %d in %s', 
            scalar @{$self->headers}, 
            scalar @values,
            $self->_line_number,
            ( $self->_file || ref $self->io ),
        )
    ) unless @{$self->headers} == @values;
    
    my %data;
    @data{ @{$self->headers} } = @values;
    return \%data;
}

sub _getline_and_split {
    my $self = shift;

    my $line = $self->getline
        or return;
    chomp $line;

    return $self->_split->($line); 
}

sub _increment_line_number {
    return $_[0]->{_line_number}++;
}

sub _split { 
    return $_[0]->{_split};
}

sub _headers_were_in_input {
    return $_[0]->{_headers_were_in_input};
}

1;

=pod

=head1 Name

Genome::Utility::IO::SeparatedValueReader

=head1 Synopsis

A stream based reader that splits each line by the given separator.  If no headers are given, they will be derived from the first line of the io, being split by the separator.

=head1 Usage

 use Genome::Utility::IO::SeparatedValueReader;

 my $reader = Genome::Utility::IO::SeparatedValueReader->new (
    input => 'albums.txt', # REQ: file or object that can 'getline' and 'seek'
    headers => [qw/ title artist /], # OPT; headers for the file
    separator => '\t', # OPT; default is ','
    is_regex => 1, # OPT: 'set this flag if your separator is a regular expression, otherwise the literal characters of the separator will be used'
 );

 while ( my $album = $reader->next ) {
    print sprintf('%s by the famous %s', $album->{title}, $album->{artist}),"\n";
 }

=head1 Methods 

=head2 next

 my $ref = $reader->next;

=over

=item I<Synopsis>   Gets the next hashref form the input.

=item I<Params>     none

=item I<Returns>    scalar (hashref)

=back

=head2 all

 my @refs (or objects) = $reader->all;

=over

=item I<Synopsis>   Gets all the refs/objects form the input.  Calls _next in your class until it returns undefined or an error is encountered

=item I<Params>     none

=item I<Returns>    array (hashrefs or objects)

=back

=head2 getline

 $reader->getline
    or die;

=over

=item I<Synopsis>   Returns the next line form the input (not chomped)

=item I<Params>     none

=item I<Returns>    scalar (string)

=back

=head2 reset

 $reader->reset
    or die;

=over

=item I<Synopsis>   Resets (seek) the input to the beginning

=item I<Params>     none

=item I<Returns>    the result of the $self->input->seek (boolean)

=back

=head2 line_number

 my $line_number = $reader->line_number;

=over

=item I<Synopsis>   Gets the current line number (position) of the input

=item I<Params>     none

=item I<Returns>    line numeber (int)

=back

=head1 See Also

I<Genome::Utility::IO::SeparatedValueReader> (inherits from), I<UR>, I<Genome>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
