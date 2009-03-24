package Genome::Report::Generator;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';

class Genome::Report::Generator {
    is => 'UR::Object',
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
        my $property_name = $property->property_name;
        next if $property_name =~ /^_/;
        next if $property->via or $property->id_by;
        next unless $property->class_name->isa('Genome::Report::Generator');
        next if $property->class_name eq 'Genome::Report::Generator';
        #print Dumper($property_name);
        $params{$property_name} = ( $property->is_many )
        ? [ $self->$property_name ]
        : $self->$property_name;
    }

    return \%params;
}

#< Data Generation Helper Methods >#
sub _generate_csv_string {
    my ($self, %params) = @_;

    $self->_validate_aryref(
        name => 'headers',
        value => $params{headers},
        method => '_generate_csv_string',
    )
        or return;

    $self->_validate_aryref(
        name => 'data',
        value => $params{data},
        method => '_generate_csv_string',
    )
        or return;

    my $io = IO::String->new();
    my $svw = Genome::Utility::IO::SeparatedValueWriter->create(
        output => $io,
        headers => $params{headers},
    )
        or return;

    for my $row ( @{$params{data}} ) {
        my %data;
        @data{ @{$params{headers}} } = @$row;
        unless ( $svw->write_one(\%data) ) {
            $self->error_message("Error writing row");
            return;
        }
    }

    $io->seek(0, 0);

    return join('', $io->getlines);
}

sub _generate_html_table {
    my ($self, %params) = @_;

    $self->_validate_aryref(
        name => 'headers',
        value => $params{headers},
        method => '_generate_html_table',
    )
        or return;

    $self->_validate_aryref(
        name => 'data',
        value => $params{data},
        method => '_generate_html_table',
    )
        or return;

    my $table = $self->_start_hmtl_table(%params)
        or return;

    my @data = _convert_data_with_undef_and_empty_strings_to_html_spaces(@{$params{data}});
    my $entry_attrs = ( $params{entry_attrs} ? ' '.$params{entry_attrs} : '' );

    for my $row ( @data ) {
        $table .= '<tr>';
        $table .= join('', map { sprintf('<td%s>%s</td>', $entry_attrs, $_) } @$row );
        $table .= "</tr>\n";
    }

    $table .= "</table>\n";

    return $table;
}

sub _generate_vertical_html_table {
    my ($self, %params) = @_;

    $self->_validate_aryref(
        name => 'horizontal headers',
        value => $params{horizontal_headers},
        method => '_generate_vertical_html_table',
    )
        or return;

    $self->_validate_aryref(
        name => 'data',
        value => $params{data},
        method => '_generate_vertical_html_table',
    )
        or return;

    my $table = $self->_start_hmtl_table(%params)
        or return;

    my @data = _convert_data_with_undef_and_empty_strings_to_html_spaces(@{$params{data}});
    my $entry_attrs = ( $params{entry_attrs} ? ' '.$params{entry_attrs} : '' );

    for ( my $i = 0; $i < @{$params{horizontal_headers}}; $i++ ) {
        # header
        $table .= sprintf('<tr><td%s><b>%s</b></td>', $entry_attrs, $params{horizontal_headers}->[$i]);
        # data
        for my $data ( @data ) {
            $table .= join('', map { sprintf('<td%s>%s</td>', $entry_attrs, $_) } $data->[$i]);
        }
        $table .= "</tr>\n";
    }

    $table .= "</table>\n";

    return $table;
}

sub _html_table_attrs {
    return (
        table_attrs => 'style="text-align:left;border:groove;border-width:3"',
        header_attrs => 'style="border:groove;border-width:1"',
        entry_attrs => 'style="border:groove;border-width:1"',
    );
}

sub _start_hmtl_table {
    my ($self, %params) = @_;

    my $table;
    if ( $params{title} ) {
        $table = '<h2>'.$params{title}.'</h2><br>';
    }

    $table .= sprintf('<table %s>', ( $params{table_attrs} || '' ));

    my $header_attrs = ( $params{header_attrs} ? ' '.$params{header_attrs} : '');
    $table .=  join(
        '', 
        map { 
            sprintf(
                '<th%s>%s</th>',
                $header_attrs,
                $_,
            ) 
        } map { 
            defined $_ ? $_ : '&nbsp'
        } 
        _convert_undef_and_empty_strings_to_html_spaces(@{$params{headers}})
    );

    return $table;
}

sub _validate_aryref { 
    my ($self, %params) = @_;

    # value => value of attr
    # name => name of attr
    # method => caller method
    
    unless ( $params{value} ) {
        $self->error_message(ucfirst($params{name}).' are required for '.$params{method});
        return;
    }

    unless ( ref($params{value}) eq 'ARRAY' ) {
        $self->error_message(ucfirst($params{name}).' are required to be an array reference for '.$params{desc});
        return;
    }

    return 1;
}

sub _convert_data_with_undef_and_empty_strings_to_html_spaces { # takes an aryref of aryrefs in @_ - no self/class
    my @new_data;
    for my $aryref ( @_ ) {
        push @new_data, [ _convert_undef_and_empty_strings_to_html_spaces(@$aryref) ];
    }
    return @new_data;
}

sub _convert_undef_and_empty_strings_to_html_spaces { # straight ary in @_ - no 'self' or class
    return map { (( not defined($_) or $_ eq "" ) ? "&nbsp" : $_ ) } @_;
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
