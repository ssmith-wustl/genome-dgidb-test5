package Genome::Model::Tools::Fastq::RemoveN;

use strict;
use warnings;

use Genome;
use Workflow;
use File::Basename;
use IO::File;
use Bio::SeqIO;

class Genome::Model::Tools::Fastq::RemoveN
{
    is => 'Genome::Model::Tools::Fastq',
    has_input => [
            n_removed_file => {
                                    doc => 'file to write to',
                                    is => 'Text',
                                    is_output => 1,
                                    is_optional => 1,
                                },
         ],
};

sub help_brief 
{
    "remove reads from file containing N";
}

sub help_detail
{   
    "Removes reads that have internal N's, or more than cutoff amount of N's on ends.  Cutoff is 6 for 75-mer, 9 for 100-mer";
}

sub help_synopsis 
{
    return <<"EOS"
EOS
}

sub create 
{
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return $self;
}

sub execute 
{
    my $self = shift;
    my $fastq_file = $self->fastq_file;
    my $n_removed_file = ($self->n_removed_file ? $self->n_removed_file : $fastq_file . "n_removed");

    my $input_fh = IO::File->new($fastq_file);
    unless ($input_fh) {
        $self->error_message("Failed to open input file " . $fastq_file . ": $!");
        return;
    }

    my $output_fh = IO::File->new('>'.$n_removed_file);
    unless ($output_fh) {
        $self->error_message("Failed to open output file " . $n_removed_file . ": $!");
        return;
    }

    
    while (my $header = $input_fh->getline) 
    {
        my $seq = $input_fh->getline;
        my $sep = $input_fh->getline;
        my $qual = $input_fh->getline;

        $output_fh->print("$header$seq$sep$qual") unless ($seq=~'N');
    }   

    $input_fh->close;
    $output_fh->close;

    return 1;
}

1;
