package Genome::Model::Tools::Consed::ListToNavigation;

use strict;
use warnings;

use above 'Genome';

use Genome::Consed::Navigation::ListReader;
use Genome::Consed::Navigation::Writer;

class Genome::Model::Tools::Consed::ListToNavigation {
    is => 'Command',
    has => [
    list_input => {
        is => 'String', 
        is_optional => 0,
        doc => 'List input (file, if from command line) for reading',
    },
    nav_input => {
        is => 'String',
        is_optional => 0,
        doc => 'Navigation output (file, if from command line) for writing'
    },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    $self->{_reader} = Genome::Consed::Navigation::ListReader->create(
        input => $self->list_input,
    )
        or return;

    $self->{_writer} = Genome::Consed::Navigation::Writer->create(
        output => $self->nav_output,
        title => $self->{_reader}->title,
    )
        or return;

    return $self;
}

sub execute
{
    my $self = shift;

    my $count = 0;
    while ( my $nav = $self->{_reader}->next ) {
        $self->{_writer}->write_one($nav)
            or return;
        $count++;
    }

    if ( $count ) { 
        return 1;
    }
    else {
        $self->error_message('Not sure why, but no navigations were written');
        return;
    }
}

1;

=pod

=head1 Name

Genome::Model::Tools::Consed::ListToNavigation

=head1 Synopsis

Converts a consed list input to a consed navigation output.

=head1 Usage

 use Genome::Model::Tools::Consed::ListToNavigation;
 
 my $converter = Finishing::Assembly::Consed::Navigation::ConvertFromList->create(
     list_input => 'repeats.list', # file, or object that can 'getline' and 'seek'
     nav_output => 'repeats.nav', # file, or object that can 'print'
 )
     or die;
 
 $converter->execute
     or die;

=head1 Methods

=head2 execute

 $reader->execute
    or die;

=over

=item I<Synopsis>   Converts the list to nav

=item I<Params>     none

=item I<Returns>    boolean

=back

=head1 See Also

I<Genome::Consed::Navigation directory>, I<Genome::Model::Tools directory>, I<consed>

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

