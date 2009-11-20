package Genome::Report::Dataset;
#:adukes is this general enough to live outside Report namespace?

use strict;
use warnings;

use Genome;

use Carp 'confess';
use Data::Dumper 'Dumper';
use XML::LibXML;

class Genome::Report::Dataset {
    is => 'UR::Object',
    has => [
    name => { 
        is => 'Text',
        doc => 'Name of the dataset.',
    },
    row_name => {
        is => 'Text',
        doc => 'The name for each row of data.',
    },
    headers => {
        is => 'ARRAY',
        doc => 'Headers for the data.'
    },
    ],
    has_optional => [
    attributes => {
        is => 'HASH',
        default_value => {},
        doc => 'Attributes of the dataset.'
    },
    rows => {
        is => 'ARRAY',
        default_value => [],
        doc => 'Rows of data.'
    },
    _xml_element => {
        is => 'XML::LibXML::Node',
        doc => 'The XML node.',
    },
    ],
};

#< Rows >#
sub add_row {
    my ($self, $row) = @_;

    $self->_validate_aryref(
        name => 'row',
        value => $row,
        method => 'add row',
    )or return;
    
    $self->_xml_element(undef); # undef xml element so we regen it, it'll have the new data
    
    return push @{$self->rows}, $row;
}

#< Attributes >#
sub get_attribute {
    my ($self, $name) = @_;

    confess $self->error_message("No name to get attribute") unless $name;
    
    return $self->attributes->{$name};
}

sub set_attribute {
    my ($self, $name, $value) = @_;

    $self->_validate_string_for_xml(
        name => 'name of attribute to set',
        value => $name,
        method => 'set attribute',
    ) or return;
    
    $self->_xml_element(undef); # undef xml element so we regen it, it'll have the new data

    return $self->attributes->{$name} = $value;
}

#< Data Grab >#
sub get_row_values_for_header {
    my ($self, $header) = @_;

    unless ( @{$self->rows}) { 
        $self->error_message("No rows to getvaalues from for header.");
        return;
    }

    unless ( $header ) {
        $self->error_message("No header given to get values from rows.");
        return;
    }

    my $pos;
    my $headers = $self->headers;
    for (my $i = 0; $i <= @{$self->headers}; $i++) {
        if ( $headers->[$i] eq $header ) {
            $pos = $i;
            last;
        }
    }
    unless ( defined $pos ) {
        $self->error_message("Header ($header) not found in headers.");
        return;
    }

    return map { $_->[$pos] } @{$self->rows};
}

#< Create >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    # Names
    for my $attr (qw/ name row_name /) {
        $self->_validate_string_for_xml(
            name => join(' ', split('_', $attr)),
            value => $self->$attr,
            method => 'create',
        ) or return;
    }

    # Headers
    $self->_validate_aryref(
        name => 'headers',
        value => $self->headers,
        method => 'create',
    ) or return;
    for my $header ( @{$self->headers} ) {
        $self->_validate_string_for_xml(
            name => 'header',
            value => $header,
            method => 'create',
        ) or return;
    }

    # Rows
    if ( $self->rows ) {
        $self->_validate_aryref(
            name => 'rows',
            value => $self->rows,
            method => 'create',
        ) or return;
        for my $row ( @{$self->rows} ) {
            $self->_validate_aryref(
                name => 'row of rows',
                value => $row,
                method => 'create',
            ) or return;
        }
    }

    return $self;
}

sub create_from_xml_element {
    my ($class, $element) = @_;

    # Row Nodes
    my @row_nodes = grep { $_->nodeType == 1 } $element->findnodes('*');

    confess "No rows found in element to create dataset." unless @row_nodes;
    
    # Names
    my $name = $element->nodeName;
    my $row_name = $row_nodes[0]->nodeName;

    # Headers
    my $headers = [ map { 
        $_->nodeName 
    } grep {
        $_->nodeType == 1
    } $row_nodes[0]->findnodes('*') ];

    # Rows
    my @rows;
    for my $row ( @row_nodes ) {
        push @rows, [ map { $_->to_literal } grep { $_->nodeType == 1 } $row->getChildnodes ];
    }

    my %attributes;
    for my $attribute_node ( $element->attributes ) {
        $attributes{ $attribute_node->nodeName } = $attribute_node->getValue;
    }

    # Create
    return $class->create(
        name => $name,
        row_name => $row_name,
        headers => $headers,
        rows => \@rows,
        attributes => \%attributes,
        _xml_node => $element,
    );
}

#< Validations >#
sub _validate_aryref { 
    my ($self, %params) = @_;

    # value => value of attr
    # name => name of attr
    # method => caller method

    unless ( $params{value} ) {
        $self->error_message(
            sprintf(
                '"%s" is/are required to "%s"',
                ucfirst($params{name}),
                $params{method},
            )
        );
        return;
    }

    my $ref = ref $params{value};
    unless ( $ref and $ref eq 'ARRAY' ) {
        $self->error_message(
            sprintf(
                '"%s" is/are required to be an array reference to "%s"',
                ucfirst($params{name}),
                $params{method},
            )
        );
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
        $self->error_message( 
            sprintf(
                '"%s" is/are required to "%s"',
                ucfirst($params{name}),
                $params{method}
            )
        );
        return;
    }

    if ( $params{value} =~ /\s/ ) {
        $self->error_message(
            sprintf(
                'Spaces were found in "%s" from method "%s", and are not allowed',
                $params{name},
                $params{method},
            )
        );
        return;
    }

    return 1;
}

#< XML - Create on the fly >#
sub to_xml_string {
    my $self = shift;
    
    my $node = $self->to_xml_element;
    unless ( $node ) {
        $self->error_message("Can't get xml element, which is necessarty to get xml string");
        return;
    }

    return $node->toString;
}

sub to_xml_element {
    my $self = shift;

    return $self->_xml_element if $self->_xml_element;
    
    my $libxml = XML::LibXML->new();
    
    # Element
    my $element = XML::LibXML::Element->new( $self->name )
        or return;

    # Rows
    my $headers = $self->headers;
    for my $row ( @{$self->rows} ) {
        my $row_element = XML::LibXML::Element->new( $self->row_name )
            or return;
        $element->addChild($row_element)
            or return;
        for ( my $i = 0; $i < @$headers; $i++ ) {
            #print Dumper([$headers->[$i], $row->[$i]]);
            my $element = $row_element->addChild( XML::LibXML::Element->new($headers->[$i]) )
                or return;
            $element->appendTextNode($row->[$i]);
            #$row_element->addChild( $libxml->createAttribute($headers->[$i], $row->[$i]) )
            #    or return;
        }
    }

    # Add dataset attributes
    if ( my $attrs = $self->attributes ) {
        for my $attr ( keys %$attrs ) {
            $element->addChild( XML::LibXML::Attr->new($attr, $attrs->{$attr}) )
                or return;
        }
    }
    return $self->_xml_element($element);
}

#< SVS >#
sub to_separated_value_string {
    my $self = shift;

    my $separator = ( @_ ) ? $_[0] : ',';
    my $svs = join($separator, @{$self->headers})."\n";
    for my $row ( @{$self->rows} ) {
        $svs .= join($separator, @$row)."\n";
    }

    return $svs;
}

1;

=pod

=head1 Name

Genome::Report::Dataset

=head1 Synopsis

=head1 Usage

 use Genome;
 
 # Get or generate a report...
 my $report = Genome::Report->create_report_from_directory(...);
 
 # Grab a xslt file
 my $xslt_file = ...;
 
 # Transform
 my $xslt = Genome::Report::XSLT->transform_report(
    report => $report, # required
    xslt_file => $xslt_file, #required
 );

 print "Content: ".$xslt->{content}."\n";

 ...
 
=head1 Public Methods

=head2 transform_report

 my $string = Genome::Report::XSLT->transform_report(report => $report, xslt_file => $xslt_file);

=over

=item I<Synopsis>   Takes a report and an xslt file (as a hash), and returns the transformed report as a string

=item I<Arguments>  report (Genome::Report), xslt_file (readable file)

=item I<Returns>    hashref with content, media_type, and encoding keys.

=back

=head1 Disclaimer

Copyright (C) 2009 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
