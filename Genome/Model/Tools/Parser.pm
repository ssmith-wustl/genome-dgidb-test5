package Genome::Model::Tools::Parser;

use strict;
use warnings;

use above "Genome";
use Command;

use IO::File;
use Text::CSV_XS;

class Genome::Model::Tools::Parser {
    is => 'Command',
    has => [
            file => {
                     doc => 'the path to the file for parsing',
                     is => 'string',
                 }
    ],
    has_optional => [
                     separator => {
                                   doc => "an optional separator charactor",
                                   is => 'string',
                               },
                     _parser => {
                                 is => 'Text::CSV_XS',
                            },
                     #header_fields => {
                     #                       doc => "column header fields",
                     #                       is => 'array',
                     #                   },
                     data_hash_ref => {
                              doc => "the data pulled from file",
                              is => 'hash',
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

    my $parser = defined($self->separator) ?
        Text::CSV_XS->new({'sep_char' => $self->separator}) :
              Text::CSV_XS->new();
    $self->_parser($parser);
    return $self;
}

sub execute {
    my $self = shift;
    my %return;
    unless (-s $self->file) {
        $self->error_message('File does not exist or has zero size'. $self->file);
        return;
    }
    my $fh = IO::File->new($self->file,'r');
    my @keys;
    #if (defined($self->header_fields)) {
    #    @keys = @{$self->header_fields};
    #} else {

    my $header = <$fh>;
    chomp($header);
    $self->_parser->parse($header);
    @keys = $self->_parser->fields();
    #}

    my $line_num = 0;
    while (<$fh>) {
        $line_num++;
        my $line = $_;
        chomp($line);
        $self->_parser->parse($line);
        my @values = $self->_parser->fields();
        if (scalar(@values) ne scalar(@keys)) {
            $self->error_message('un-balanced data. found '. scalar(@values)
                                 .' values and '. scalar(@keys) .' expected');
            return;
        }
        for (my $i=0; $i < scalar(@values); $i++) {
            $return{$line_num}{$keys[$i]} = $values[$i];
        }
    }
    $self->data_hash_ref(\%return);
    return 1;
}


1;


