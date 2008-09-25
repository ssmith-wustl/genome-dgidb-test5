package Genome::Utility::IO::Writer;

use strict;
use warnings;

use above 'Genome';

require Cwd;
require File::Basename;
require IO::File;

class Genome::Utility::IO::Writer {
    is => 'UR::Object',
    is_abstract => 1,
    has => [
    output => {
        type => 'String',
        is_optional => 0,
        doc => 'Output (file, if from command line) to write',
    },
    ],
};

sub get_original_output { # Allow getting of original output (file)
    return shift->{original_output};
}

BEGIN {
    *new = \&create;
}

sub create {
    my $class = shift;

    unless ( $class->can('write_one') ) {
        $class->error_message("Can't write because there isn't a 'write_one' method in class ($class)");
        return;
    }

    my $self = $class->SUPER::create(@_);
    $self->error_message("Output is required for class ($class)")
        and return unless defined $self->output;

    if ( my $output_class = ref($self->output) ) {
        for my $required_method (qw/ print /) {
            unless ( $output_class->can($required_method) ) {
                $self->error_message("output class ($output_class) can't do required method ($required_method)");
                return;
            }
        }
    }
    else {
        $self->output( Cwd::abs_path( $self->output ) );
        $self->error_message( sprintf('Output file (%s) exists', $self->output) ) 
            and return if -e $self->output;
        my ($directory, $file) = File::Basename::basename($self->output);
        $self->error_message( sprintf('Directory (%s) for file (%s) is not writable', $directory, $file) ) 
            and return unless -w $directory;

        my $fh = IO::File->new('>'.$self->output);
        $self->error_message( sprintf('Can\'t open file (%s) for writing: %s', $self->output, $!) )
            and return unless $fh;
        $self->{_original_output} = $self->output;
        $self->output($fh);
    }

    return $self;
}

sub print {
    return $_[0]->output->print($_[1]);
}

1;

=pod

=head1 Name

Genome::Utility::IO::Writer;

=head1 Synopsis

Abstract stream based writer.

=head1 Usage

B<In your class>

 package Album::Writer;

 use strict;
 use warnings;

 use above 'UR'; # or Genome

 # Declare your class UR style
 class Album::Writer {
    is => 'Genome::Utility::IO::Writer',
 };

 # OPTIONAL - add a create method
 sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_); # REQUIRED to call SUPER::create

    unless ( $self->_check_something ) {
        $self->error_message("Something went wrong");
        return; # return false (undef or 0) to indicate error
    }
    
    return $self;
 }

 # REQUIRED, put you writin' code here
 sub write_one {
    my ($self, $album) = @_;

    # put your print statements here, ex:
    $self->print(
        sprintf(
            "Title: %s\nArtist: %s\nGenre: %s\n\n",
            $albumn->title,
            $albumn->artist,
            $albumn->genre,
    );
    
    return 1; # return true!
 }

B<** in the code **>

 use Album::Writer;
 use IO::File;

 my $writer = Album::Writer->create(
    output => "myalbums.txt", # file or object that can 'getline' and 'seek'
 )
    or die;

 $writer->write_one(
    {
        title => 'Kool and the Gang',
        artist => 'Kool and the Gang',
        tracks => [ { name => "Celebration", rating => 5 length => '5:55' }, etc... ],
    }
 )
    or die;

=head1 Methods to Provide in Subclasses

=head2 write_one

$writer->write_one($obj)
    or die;

=over

=item I<Synopsis>   Writes the ref to the output.

=item I<Params>     ref (scalar)

=item I<Returns>    the return value of the write_one method (boolean)

=back

=head1 Methods Provided

=head2 print

 $writer->print("$string\n");

=over

=item I<Synopsis>   Prints the string to the output

=item I<Params>     none

=item I<Returns>    result of the print (boolean)

=back

=head1 See Also

I<UR>

=head1 Disclaimer

Copyright (C) 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
