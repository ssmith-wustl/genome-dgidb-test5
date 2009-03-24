package Genome::Report::FromSeparatedValueFile;

use strict;
use warnings;

use Genome;

use IO::File;
use IO::String;

class Genome::Report::FromSeparatedValueFile {
    is => 'Genome::Report::Generator',
    has => [
    description => {
        is => 'Text',
        doc => 'Report description',
    },
    file => {
        is => 'Text',
        doc => 'Separated value file to import',
    },
    _svr => {
        is => 'Genome::Utility::IO::SeparatedValueReader',
    },
    ],
    has_optional => [
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
    html_table_type => {
        is => 'Text', # Enum
        default_value => 'horizontal',
        doc => 'Html Table type to create',
    },
    ],
};

#< Create >#
sub create { 
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->description ) {
        $self->error_message("Description is required to create");
        $self->delete;
        return;
    }
    
    unless ( grep { $self->html_table_type eq $_ } (qw/ horizontal vertical /) ) {
        $self->error_message('Invalid html table type: '.$self->html_table_type);
        $self->delete;
        return;
    }

    my $svr = Genome::Utility::IO::SeparatedValueReader->create(
        input => $self->file,
        separator => $self->separator,
        is_regex => $self->is_regex,
    );

    unless ( $svr ) {
        $self->error_message('Unable to create separated value reader');
        $self->delete;
        return;
    }

    $self->_svr( $svr );

    return $self;
}

#< Generate >#
sub _generate_data {
    my $self = shift;

    my $svr = $self->_svr;
    
    my @data;
    while ( my $ref = $self->_svr->next ) {
        push @data, [ map { $ref->{$_} } @{$svr->headers} ];
    }
    unless ( @data ) {
        $self->error_message("No data found in separated value file ()");
        return;
    }
    
    my $table_method = ( $self->html_table_type eq 'horizontal' )
    ? '_generate_html_table'
    : '_generate_vertical_html_table';
    
    my $html = $self->_generate_html_table(
        headers => [ map { join('', map { ucfirst } split(/\s\_/, $_)) } @{$self->_svr->headers} ],
        data => \@data,
        $self->_html_table_attrs,
    )
        or return;

    my $csv = $self->_generate_csv_string(
        headers => $self->_svr->headers,
        data => \@data,
    )
        or return;
    
    return {
        description => $self->description,
        html => '<html>'.$html.'</html>',
        csv => $csv,
    };
}

1;

#$HeadURL$
#$Id$
