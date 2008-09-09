package Genome::Utility::Parser;

use strict;
use warnings;

use Genome;

use IO::File;
use Text::CSV_XS;

class Genome::Utility::Parser {
    is => 'UR::Object',
    has => [
            file => {
                     doc => 'the path to the file for parsing',
                     is => 'string',
                 },
            header => {
                       doc => "flag if the file contains a header",
                       is => 'Boolean',
                       default_value => 1,
                   },
            separator => {
                          doc => "a separator character, default is ','",
                          is => 'string',
                          default_value => ',',
                      },
            allow_whitespace => {
                                 doc => "allow whitespace in each field",
                                 is => 'Boolean',
                                 default_value => 1,
                             },
    ],
    has_optional => [
                     header_fields => {
                                       doc => "column header fields",
                                       is => 'array',
                                   },
                     data_hash_ref => {
                                       doc => "the data pulled from file",
                                       is => 'hash',
                                   },
                     _parser => {
                                 is => 'Text::CSV_XS',
                             },
                     _file_handle => {
                            doc => "The filehandle",
                            is => 'IO::File',
                     },
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

    # UR seems to add an additional un-necessary escape
    #my $sep_char = $self->separator;
    #$sep_char =~ s/\\\\/\\/;
    #$self->separator($sep_char);


    # Passing the allow_whitespace argument does not appear to work
    # We will do our own whitespace trimming in execute()
    my $parser = Text::CSV_XS->new(
                                   {
                                    sep_char => $self->separator,
                                    allow_whitespace => $self->allow_whitespace,
                                }
                               );
    #my $parser = defined($self->separator) 
    #? Text::CSV_XS->new({'sep_char' => $self->separator}) :
    #: Text::CSV_XS->new();

    $self->_parser($parser);

    unless (-e $self->file) {
        $self->error_message('File does not exist '. $self->file);
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
        chomp($header);
        $self->_parser->parse($header);
        my @header_fields = $self->_parser->fields();
        if ($self->allow_whitespace) {
            for (@header_fields) {
                $_ =~ s/^\s*|\s*$//g;
            }
        }
        $self->header_fields(\@header_fields);
    }

    unless ( $self->header_fields ) {
        $self->error_message("No header fields set");
        return;
    }

    return $self;
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
    $self->_parser->parse($line); # check for true parse??

    my @keys = @{ $self->header_fields };
    my @values = $self->_parser->fields();
    if ($self->allow_whitespace) {
        for (@values) {
            $_ =~ s/^\s*|\s*$//g;
        }
    }
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

sub close {
    my $self = shift;
    $self->_file_handle->close;
}

1;

#$Header$
#$Id$
