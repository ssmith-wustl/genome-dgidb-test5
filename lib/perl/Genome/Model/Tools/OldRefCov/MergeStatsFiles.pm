package Genome::Model::Tools::OldRefCov::MergeStatsFiles;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::OldRefCov::MergeStatsFiles {
    is => ['Command','Genome::Sys'],
    has_input => [
                  input_stats_files => { is => 'List', },
                  output_stats_file => { is => 'Text', },
              ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless (ref($self->input_stats_files) eq 'ARRAY') {
        my @input_stats_files = ($self->input_stats_files);
        $self->input_stats_files(\@input_stats_files);
    }
    for my $input_stats_file (@{$self->input_stats_files}) {
        unless ($self->validate_file_for_reading($input_stats_file)) {
            $self->error_message('Failed to validate file for reading '. $input_stats_file);
            die($self->error_message);
        }
    }
    if (ref($self->output_stats_file) eq 'ARRAY') {
        $self->output_stats_file( @{ $self->output_stats_file }[0] );
    }

    unless ($self->validate_file_for_writing($self->output_stats_file)) {
        $self->error_message('Failed to validate file for writing '. $self->output_stats_file);
        die($self->error_message);
    }
    return $self;
}


sub execute {
    my $self = shift;
    my %lines;
    my $total_size;
    for my $input_stats_file (@{$self->input_stats_files}) {
        $total_size += -s $input_stats_file;
        my @header_fields = (0 .. 17);
        my $parser = Genome::Utility::Parser->create(
                                                     file => $input_stats_file,
                                                     separator => "\t",
                                                     header => 0,
                                                     header_fields => \@header_fields,
                                                 );
        unless ($parser) {
            $self->error_message('Failed to create tab delimited parser for file '. $input_stats_file);
            die($self->error_message);
        }
        while (my %fields = $parser->next) {
            unless (scalar(keys %fields) >= 18) {
                $self->error_message('Only found '. scalar(keys %fields) .' fields per line but expecting 18');
                die($self->error_message);
            }
            if (defined $lines{$fields{0}}) {
                $self->error_message('Found more than one occurance of '. $fields{0});
                die($self->error_message);
            }
            my @values;
            for (@header_fields) {
                push @values, $fields{$_};
            }
            $lines{$fields{0}} = \@values;
        }
    }
    my $fh = $self->open_file_for_writing($self->output_stats_file);
    unless ($fh) {
        $self->error_message('Failed to create writable filehandle for file '. $self->output_stats_file);
        die($self->error_message);
    }
    for my $key (sort {$a cmp $b} keys %lines) {
        my $line_array_ref = $lines{$key};
        print $fh join("\t",@{$line_array_ref}) ."\n";
    }
    $fh->close;
    unless (-s $self->output_stats_file >= $total_size) {
        $self->error_message('Output stats file '. $self->output_stats_file .' with size '. -s $self->output_stats_file .' but expecting '. $total_size);
        die($self->error_message);
    }
    return 1;
}

1;
