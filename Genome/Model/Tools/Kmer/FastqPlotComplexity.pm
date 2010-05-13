package Genome::Model::Tools::Kmer::FastqPlotComplexity;

use strict;
use warnings;

use Genome;
use GD::Graph::lines;

class Genome::Model::Tools::Kmer::FastqPlotComplexity {
    is => ['Genome::Model::Tools::Kmer'],
    has => [
        fastq_files => {
            is => 'Text',
            doc => 'All the fastq files to plot complexity of seperated by commas',
        },
        output_directory => {
            is => 'Text',
            doc => 'The path to dump all output files',
        },
    ],
    has_optional => [
        index_name => {},
        index_log_file => {},
        occurence_ratio_output_file => { },
        plot_file => {},
    ],
};

sub execute {
    my $self = shift;

    my @fastq_files = split(/,/,$self->fastq_files);
    my @fasta_files;
    my @fastq_basenames;
    my $max_read_length;
    for my $fastq_file (@fastq_files) {
        my ($fastq_basename,$fastq_dirname,$fastq_suffix) = File::Basename::fileparse($fastq_file,qw/\.fastq \.fq \.txt/);
        unless ($fastq_basename) {
            die('Failed to parse fastq file path '. $fastq_file);
        }
        my $fasta_file = $self->output_directory .'/'. $fastq_basename .'.fa';
        push @fastq_basenames, $fastq_basename;
        unless (-e $fasta_file) {
            unless (Genome::Model::Tools::Fastq::ToFasta->execute(
                fastq_file => $fastq_file,
                fasta_file => $fasta_file,
            )) {
                die('Failed to convert fastq_file '. $fastq_file .' to fasta file '. $fasta_file);
            }
        }
        my $fasta_fh = Genome::Utility::FileSystem->open_file_for_reading($fasta_file);
        while (my $line = $fasta_fh->getline){
            chomp($line);
            if ($line =~ /^>/) { next; }
            my $read_length = length($line);
            if (!defined($max_read_length) || ($read_length > $max_read_length)) {
                $max_read_length = $read_length;
            }
        }
        push @fasta_files, $fasta_file;
    }
    $self->index_name($self->output_directory .'/'. join('_', @fastq_basenames));
    $self->index_log_file($self->output_directory .'/'. join('_', @fastq_basenames) .'.log');
    unless (Genome::Model::Tools::Kmer::Suffixerator->execute(
        fasta_files => \@fasta_files,
        index_name => $self->index_name,
        log_file => $self->index_log_file,
    )) {
        die("Failed to run suffixerator on fasta files:\n". join("\n", @fasta_files) );
    }
    $self->occurence_ratio_output_file($self->index_name .'_occurence_ratio.dat');
    unless (Genome::Model::Tools::Kmer::OccurrenceRatio->execute(
        index_name => $self->index_name,
        minimum_mer_size => 1,
        maximum_mer_size => $max_read_length,
        output_file => $self->occurence_ratio_output_file,
        output_type => 'nonuniquemulti relative',
    )) {
        die('Failed to generate occurence ratio from index '. $self->index_name);
    }
    my $occratio_fh = Genome::Utility::FileSystem->open_file_for_reading($self->occurence_ratio_output_file);
    my @x;
    my @y;
    while (my $line = $occratio_fh->getline){
        chomp($line);
        if ($line =~ /^#/) { next; }
        my ($mer_size,$count,$ratio) = split(/\s+/,$line);
        push @x, $mer_size;
        push @y, $ratio;
    }
    $occratio_fh->close;
    my $data = [\@x,\@y];
    my $graph = new GD::Graph::lines(800,600);
    $graph->set(
                x_label         => 'K-mer Size',
                y_label         => 'Duplication Rate',
                title           => 'K-mer Based Duplication Rate',
                x_min_value     => 0,
                x_max_value     => $max_read_length,
                x_label_position => .5,
                x_label_skip    => 5,
            )
        or warn $graph->error;
    my $gd = $graph->plot($data) or die $graph->error;
    $self->plot_file($self->index_name .'_plot.png');
    open(IMG, '>'. $self->plot_file) or die $!;
    binmode IMG;
    print IMG $gd->png;
    close(IMG);
    return 1;
}
