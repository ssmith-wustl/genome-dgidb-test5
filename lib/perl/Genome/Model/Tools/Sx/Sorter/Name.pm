package Genome::Model::Tools::Sx::Sorter::Name;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require IO::File;
require File::Temp;

class Genome::Model::Tools::Sx::Sorter::Name {
    is  => 'Genome::Model::Tools::Sx::Sorter',
};

sub help_brief {
    return <<HELP 
    Sort sequences by name
HELP
}

sub help_detail {
    return <<HELP
    This module quickly sorts sequences by name (id) using unix native sort. It can sort one million sequences per minute. It does not use any intermediate files.
HELP
}

sub execute {
    my $self = shift;

    my ($reader, $writer) = $self->_open_reader_and_writer;
    return if not $reader or not $writer;
    
    my $temp_fh = File::Temp->new() or die;
    no warnings 'uninitialized';
    while ( my $seqs = $reader->read ) {
        for my $seq ( @$seqs ) { 
            $temp_fh->print(
                join("\t", map { $seq->{$_} } (qw/ id desc seq qual /))."\n"
            );
        }
    }
    $temp_fh->flush;
    $temp_fh->close;

    my $sort_fh = IO::File->new("sort -k 1 ".$temp_fh->filename." |") or die;
    while ( my $line = $sort_fh->getline ) {
        chomp $line;
        my %seq;
        @seq{qw/ id desc seq qual /} = split(/\t/, $line);
        $writer->write([ \%seq ]);
    }

    return 1;
}

1;

