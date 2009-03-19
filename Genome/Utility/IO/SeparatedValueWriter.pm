package Genome::Utility::IO::SeparatedValueWriter;

use strict;
use warnings;

use Genome;

use Data::Dumper;

class Genome::Utility::IO::SeparatedValueWriter {
    is => 'Genome::Utility::IO::Writer', 
    has_optional => [
    separator => {
        type => 'String',
        default => ',',
        doc => 'The value of the separator character.  Default: ","'
    },
    ],
};

sub get_column_count {
    return $_[0]->{_column_count};
}

sub _get_or_set_column_count {
    my ($self, $aryref) = @_;

    return $self->{_column_count} if $self->{_column_count};

    return $self->{_column_count} = scalar @$aryref;
}

sub print { 
    my $self = shift;
    return $self->write_one(@_);
}

sub write_one {
    my ($self, $aryref) = @_;

    $self->_validate_aryref($aryref)
        or return;

    return $self->output->print(
        join(',', map { defined $_ ? $_ : '' } @$aryref)."\n"
    );
}

sub _validate_aryref {
    my ($self, $aryref) = @_;

    unless ( $aryref ) {
        $self->error_message("No data sent to 'write_one'");
        return;
    }

    unless ( ref $aryref eq 'ARRAY' ) {
        $self->error_message("Need data as an array ref to 'write_one'. Received:\n".Dumper($aryref));
        return;
    }

    unless ( @$aryref ) {
        $self->error_message("Empty array ref sent to 'write_one'");
        return;
    }
    
    unless ( @$aryref == $self->_get_or_set_column_count($aryref) ) {
        $self->error_message("Array values differ than those previously written:\n".Dumper($aryref));
        return;
    }

    return 1;
}

1;

=pod

=head1 Name

Genome::Utility::IO::SeparatedValueWriter

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
