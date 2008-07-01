package Genome::Utility::Parser;

use strict;
use warnings;

use above "Genome";
use Command;

use IO::File;
use Text::CSV_XS;

class Genome::Utility::Parser {
    is => 'Command',
    has => [
            file => {
                     doc => 'the path to the file for parsing',
                     is => 'string',
                 },
            header => {
                       doc => "a flag if the file does not contain a header",
                       is => 'Boolean',
                       default_value => 1,
                   },
    ],
    has_optional => [
                     separator => {
                                   doc => "an optional separator charactor",
                                   is => 'string',
                                   default => ',',
                               },
                     _parser => {
                                 is => 'Text::CSV_XS',
                            },
                     header_fields => {
                                        doc => "column header fields",
                                        is => 'array',
                                    },
                     data_hash_ref => {
                              doc => "the data pulled from file",
                              is => 'hash',
                          },
                     _file_handle => {
                            doc => "The filehandle",
                            is => 'IO::File',
                     },
                     _line_number => {
                                      is => 'Integer',
                                  }
                 ],
};

sub help_brief {
    "parse a delimited text file";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 

EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $parser = Text::CSV_XS->new({ sep_char => $self->separator });
    #my $parser = defined($self->separator) 
    #? Text::CSV_XS->new({'sep_char' => $self->separator}) :
    #: Text::CSV_XS->new();

    $self->_parser($parser);

    unless (-s $self->file) {
        $self->error_message('File does not exist or has zero size'. $self->file);
        return;
    }

    my $fh = IO::File->new($self->file,'r');
    $self->_file_handle($fh);

    if ($self->header) {
        my $header = $self->_file_handle()->getline();
        unless(defined $header) {
            $self->error_message('No lines to parse from file '. $self->file);
            return;
        }
        $self->_line_number(1);
        chomp($header);
        $self->_parser->parse($header);
        my @header_fields = $self->_parser->fields();
        $self->header_fields(\@header_fields);
    }

    unless ( $self->header_fields ) {
        $self->error_message("No header fields set");
        return;
    }

    return $self;
}

sub execute {
    my $self = shift;

    my %data_hash;

    while ( my %line_hash = $self->next ) {
        $data_hash{$self->_line_number} = \%line_hash;
    }

    $self->data_hash_ref(\%data_hash);

    return 1;
}

BEGIN {
*getline = \&next;
}

sub next { 
    my $self = shift;

    my $line = $self->_file_handle()->getline()
        or return;

    return $self->_read_line($line);
}

sub _read_line {
    my $self = shift;
    my $line = shift;

    chomp($line);
    $self->_line_number( $self->_line_number + 1 );
    $self->_parser->parse($line); # check for true parse??

    my @keys = @{ $self->header_fields };
    my @values = $self->_parser->fields();

    unless (scalar(@values) == scalar(@keys)) {
        $self->error_message (
            sprintf('Un-balanced data found: %d values and %d expected on line %d',
                scalar(@values),
                scalar(@keys),
                $self->_line_number,
            )
        );
        return;
    }

    my %data_hash;
    @data_hash{@keys} = @values;

    return ( wantarray ) ? %data_hash : \%data_hash;
}

1;

#$Header$
#$Id$
