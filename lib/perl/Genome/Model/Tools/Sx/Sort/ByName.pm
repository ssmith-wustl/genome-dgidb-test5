package Genome::Model::Tools::Sx::Sort::ByName;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require IO::File;
require File::Temp;

class Genome::Model::Tools::Sx::Sort::ByName {
    is  => 'Genome::Model::Tools::Sx',
};

sub help_brief {
    return 'Sort sequences by name';
}

sub execute {
    my $self = shift;

    my $init = $self->_init;
    return if not $init;

    my $reader = $self->_reader;
    my $writer = $self->_writer;

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

