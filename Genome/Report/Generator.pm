package Genome::Report::Generator;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

class Genome::Report::Generator {
    is => 'UR::Object',
    is_abstract => 1,
    has => [
    name => { 
        is => 'Text',
        doc => 'Name of the report',
    },
    ],
};

#< Get/Create >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->name ) {
        $self->error_message("Name is required to create");
        $self->delete;
        return;
    }

    return $self;
}

#< Report Generation >#
sub generate_report {
    my $self = shift;

    unless ( $self->can('_generate_data') ) {
        confess "This report class does not implement '_generate_data' method.  Please correct.";
    }

    my $data = $self->_generate_data;
    unless ( $data ) { 
        $self->error_message("Could not generate report data");
        return;
    }

    $data->{name} = $self->name;
    $data->{date} = UR::Time->now;
    $data->{generator} = $self->class;
    $data->{generator_params} = $self->_get_params_for_generation;

    #print Dumper($data);

    return Genome::Report->create(
        name => $self->name,
        data => $data,
    );
}

sub _get_params_for_generation {
    my $self = shift;

    my %params;
    for my $property ( $self->get_class_object->get_all_property_objects ) {
        next if $property->via or $property->id_by;
        next unless $property->class_name->isa('Genome::Report::Generator');
        next if $property->class_name eq 'Genome::Report::Generator';
        my $property_name = $property->property_name;
        #print Dumper($property_name);
        $params{$property_name} = $self->$property_name;
    }

    return \%params;
}

#< Data Generation Helper Methods >#

################################
## TEST GENERATOR FOR TESTING ##
################################

package Genome::Report::Generator::ForTesting;

use strict;
use warnings;

class Genome::Report::Generator::ForTesting {
    is => 'Genome::Report::Generator',
};

sub _generate_data {
    return {
        description => 'something about nothing',
        html => '<html></html>',
        csv => "c1,c2\nr1,r2\n",
    };
}

1;

=pod

=head1 Name

Genome::Report::Generator

=head1 Synopsis

Base class for report generators.  Use this class as a base for yours...then implement a '_generate_data' method that returns a hashref.

=head1 Usage

 my $generator = Genome::Report::Generator->create(
    name => 'Happy', # required
    ..other params...
 );

 my $report = $generator->generate_report
    or die;
 
 $report->save('some_directory')
    or die;

=head1 Public Methods

=head2 generate_report

 my $report = $generator->generate_report
    or die;

=over

=item I<Synopsis>   Generates data and creates a Genome::Report

=item I<Arguments>  none

=item I<Returns>    Genome::Report

=back

=head1 Private Methods Implemented in Subclasses

=head2 _generate_data

=over

=item I<Synopsis>   Generates data and returns a hashref containing keys description, html (opt) and csv (opt)

=item I<Arguments>  none

=item I<Returns>    hashref 

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
