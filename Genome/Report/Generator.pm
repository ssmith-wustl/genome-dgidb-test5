package Genome::Report::Generator;

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use IO::String;
use XML::LibXML;

class Genome::Report::Generator {
    is => 'UR::Object',
    has => [
    name => {
        is => 'Text',
        doc => 'Name to give the report.  Will usually have a default/calculated value',
    },
    description => {
        is => 'Text',
        doc => 'Description to give the report.  Will usually have a default/calculated value',
    },
    ]
};

#< Create >#
sub create {
    my $class = shift;

    unless ( $class->can('_generate_data') ) {
        confess "This report generator class does not implement '_generate_data' method.  Please correct.";
    }

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->name ) {
        $self->error_message('No name for generator to give report');
        $self->delete;
        return;
    }

    unless ( $self->description ) {
        $self->error_message('No description for generator to give report');
        $self->delete;
        return;
    }
    
    # XML doc
    $self->{_xml} = XML::LibXML->createDocument;
    unless ( $self->{_xml} ) {
        $self->error_message("Can't create XML object");
        $self->delete;
        return;
    }

    # main node
    $self->{_main_node} = $self->_xml->createElement('report')
        or Carp::confess('Create main node to XML');
    $self->_xml->addChild( $self->_main_node )
        or Carp::confess('Add main node to XML');
    $self->_xml->setDocumentElement( $self->_main_node );
    
    # meta node
    $self->{_meta_node} = $self->_xml->createElement('report-meta')
        or Carp::confess('Create meta node to XML');
    $self->_main_node->addChild( $self->_meta_node )
        or Carp::confess('Add meta node to main node');
    
    return $self;
}

#< Report Generation >#
sub generate_report {
    my $self = shift;

    # Data
    my $data;
    unless ( $data = $self->_generate_data ) {
        $self->error_message("Could not generate report data");
        return;
    }

    # Meta data
    $self->_add_report_meta_data
        or return;

    my $report = Genome::Report->create(
        xml => $self->_xml,
    );

    # DATA - BACKWARD COMPATIBILITY - THIS WILL BE REMOVED!
    if ( ref($data) ) {
        $self->warning_message("Generating a report w/ 'data' is deprecated.  Please store data as XML");
        $report->data($data);
    }

    return $report;
}

sub _add_report_meta_data {
    my $self = shift;

    # Basics
    for my $attr (qw/ name description date generator /) {
        $self->_meta_node->addChild( $self->_xml->createElement($attr) )->appendTextNode($self->$attr);
    }

    # Generator params
    my %generation_params = $self->_get_params_for_generation;
    my $gen_params_node = $self->_xml->createElement('generator-params')
        or return;
    $self->_meta_node->addChild($gen_params_node)
        or return;
    for my $param ( keys %generation_params ) {
        for my $value ( @{$generation_params{$param}} ) {
            my $element = $gen_params_node->addChild( $self->_xml->createElement($param) )
                or return;
            $element->appendTextNode($value);
        }
    }

    return $self->_meta_node;
}

sub generator { # lets this be overwritten
    return $_[0]->class;
}

sub date { # lets this be overwritten
    return UR::Time->now; 
}

sub _get_params_for_generation {
    my $self = shift;

    my %params;
    for my $property ( $self->get_class_object->all_property_metas ) {
        my $property_name = $property->property_name;
        next if $property_name =~ /^_/;
        next if grep { $property_name eq $_ } (qw/ name description /);
        next if $property->via or $property->id_by;
        next unless $property->class_name->isa('Genome::Report::Generator');
        next if $property->class_name eq 'Genome::Report::Generator';
        #print Dumper($property_name);
        my $key = $property_name;
        $key =~ s#_#\-#g;
        $params{$key} = [ $self->$property_name ];
    }

    return %params;
}

#< Helpers >#
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
        $self->error_message(ucfirst($params{name}).' are required to be an array reference for '.$params{method});
        return;
    }

    return 1;
}

sub _validate_string_for_xml { 
    my ($self, %params) = @_;

    # value => value of attr
    # name => name of attr
    # method => caller method
    
    unless ( $params{value} ) {
        $self->error_message(ucfirst($params{name}).' is required for '.$params{method});
        return;
    }

    if ( $params{value} =~ /\s/ ) {
        $self->error_message(
            sprintf(
                'Spaces were found in %s from method %s, and are not allowed',
                $params{name},
                $params{method},
            )
        );
        return;
    }

    return 1;
}

#< XML >#
sub _xml {
    return $_[0]->{_xml};
}

sub _main_node {
    return $_[0]->{_main_node};
}

sub _meta_node {
    return $_[0]->{_meta_node};
}

sub _datasets_node {
    my $self = shift;

    unless ( $self->{_datasets_node} ) {
        $self->{_datasets_node} = $self->_xml->createElement('datasets')
            or return;
        $self->_main_node->addChild( $self->{_datasets_node} )
            or return;
    }

    return $self->{_datasets_node};
}

sub _add_dataset {
    my ($self, %params) = @_;

    # Names
    my $dataset_name = delete $params{name};
    $self->_validate_string_for_xml(
        name => 'dataset_name',
        value => $dataset_name,
        method => '_add_dataset',
    )
        or return;
    my $row_name = delete $params{row_name};
    $self->_validate_string_for_xml(
        name => 'row_name',
        value => $row_name,
        method => '_add_dataset',
    )
        or return;

    # Headers
    my $headers = delete $params{headers};
    $self->_validate_aryref(
        name => 'headers',
        value => $headers,
        method => '_add_dataset',
    ) or return;
    for my $header ( @$headers ) {
        $self->_validate_string_for_xml(
            name => 'header',
            value => $header,
            method => '_add_dataset',
        )
            or return;
    }

    # Rows
    my $rows = delete $params{rows};
    $self->_validate_aryref(
        name => 'rows',
        value => $rows,
        method => '_add_dataset',
    ) or return;

    # Dataset node
    my $dataset_node = $self->_xml->createElement($dataset_name)
        or return;
    $self->_datasets_node->addChild($dataset_node)
        or return;

    # Add data
    my $i;
    for my $row ( @$rows ) {
        my $row_node = $self->_xml->createElement($row_name)
            or return;
        $dataset_node->addChild($row_node)
            or return;
        for ( $i = 0; $i < @$headers; $i++ ) {
            #print Dumper([$headers->[$i], $row->[$i]]);
            my $element = $row_node->addChild( $self->_xml->createElement($headers->[$i]) )
                or return;
            $element->appendTextNode($row->[$i]);
            #$row_node->addChild( $self->_xml->createAttribute($headers->[$i], $row->[$i]) )
            #    or return;
        }
    }

    # Add dataset attributes
    for my $attr ( keys %params ) {
        $dataset_node->addChild( $self->_xml->createAttribute($attr, $params{$attr}) )
            or return;
    }

    return $dataset_node;
}

=pod
CDATA....
    my $csv = IO::String->new;
    unless ( $csv ) {
        $self->error_message("Can't create IO::String: $!");
        return;
    }
    my $svw = Genome::Utility::IO::SeparatedValueWriter->create(
        headers => $headers,
        output => $csv,
    )
        or return;
    for my $row ( @$rows ) {
        my %data;
        @data{ @$headers } = @$row;
        $svw->write_one(\%data)
            or return;
    }
    $csv->seek(0, 0);
    my $cdata_node = XML::LibXML::CDATASection->new( join('', $csv->getlines) )
        or return;
    $csv_node->addChild($cdata_node)
        or return;
=cut

sub _add_node_with_multiple_values {
    my ($self, %params) = @_;

    unless ( $params{parent_node} ) {
        $self->error_message("Need parent_node to add node with multiple values");
        return;
    }

    unless ( $params{tag_name} ) {
        $self->error_message("Need tag_name to add node with multiple values");
        return;
    }

    unless ( $params{child_tag_name} ) {
        $self->error_message("Need child_tag_name to add node with multiple values");
        return;
    }

    $self->_validate_aryref(
        name => $params{child_tag_name},
        value => $params{'values'},
        method => 'create node with multiple values',
    )
        or return;
    
    my $node = $self->_xml->createElement($params{tag_name})
        or return;
    $params{parent_node}->addChild($node)
        or return;
    
    for my $value ( @{$params{'values'}} ) {
        my $child_node = $self->_xml->createElement($params{child_tag_name});
        $child_node->addChild( $self->_xml->createTextNode($value) );
        $node->addChild($child_node);
    }
    
    return $node;
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
