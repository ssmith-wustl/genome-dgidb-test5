package Genome::Utility::GeneHeader::Reader;

use strict;
use warnings;

use IO::File;
use Data::Dumper;

use above "Genome";

# Could inherit from Parser but no known column headers
class Genome::Utility::GeneHeader::Reader {
    is => 'Command',
    has => [
            file => {
                     doc => 'the gene header file to read',
                     is => 'string',
                 },
        ],
    has_optional => [
                     gene_hash_ref => {
                                       doc => "the genes read from file",
                                       is => 'hash',
                          },
                 ],
};

sub help_brief {
    "parse a gene header file";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 

EOS
}


sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    unless (-s $self->file) {
        $self->error_message('File '. $self->file .' does not exist or is zero size');
        return;
    }
    return $self;
}

sub execute {
    my $self = shift;
    my $fh = IO::File->new($self->file,'r');
    my %data;
    while (my $line = $fh->getline) {
        my $gene_name;
        my @fields = split(/,\s*/,$line);
        for my $field (@fields) {
            if ($field =~ /GeneName/) {
                my @tmp = split(/:/,$field);
                $gene_name = $tmp[1];
                if (defined $data{$gene_name}) {
                    $self->error_message("Gene '$gene_name' already defined in gene header file ". $self->file);
                    return;
                }
                $data{$gene_name}{'name'} = $gene_name;
            } elsif ($field =~ /Chr/) {
                my @tmp = split(/\:/,$field);
                unless ($gene_name) {
                    $self->error_message("No GeneName found for line '$line' in gene header file ". $self->file);
                    return;
                }
                $data{$gene_name}{'chrom'} = $tmp[1];
            } elsif ($field =~ /Coords/) {
                my @tmp = split(/\s+/,$field);
                my $coords_string = $tmp[1];
                my ($gene_chr_start, $gene_chr_stop) = split(/\-/, $coords_string);
                unless ($gene_name) {
                    $self->error_message("No GeneName found for line '$line' in gene header file ". $self->file);
                    return;
                }
                $data{$gene_name}{'start'} = $gene_chr_start;
                $data{$gene_name}{'stop'} = $gene_chr_stop;
            }
        }
    }
    $self->gene_hash_ref(\%data);
    return 1;
}


1;


