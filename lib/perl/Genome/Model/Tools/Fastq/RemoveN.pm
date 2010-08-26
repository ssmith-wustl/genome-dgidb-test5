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
            cutoff =>   {
                                    doc => 'minimum # of N\'s to screen on.  Set to 0 to disable',
                                    is => 'Number',
                                    is_optional => 1,
                                    default => 1, 
                        },
            save_screened_reads => 
                                {
                                    doc => 'save screened reads in separate file',
                                    is => 'Boolean',
                                    is_optional => 1,
                                    default => 0,
                                },
         ],
    has_output => [
          passed_reads => {
                                    is=>'Number',
                                    doc => 'number of reads passed screening',
                                    is_optional => 1
          },
          failed_reads => {
                                    is=>'Number',
                                    doc => 'number of reads failed screening',
                                    is_optional => 1
          },
    ]
};

sub help_brief 
{
    "remove reads from file containing N";
}

sub help_detail
{   
    "Removes reads that have internal N's, or more than cutoff amount of N's on ends.  By default, removes for a single N.  Set cutoff to 0 to disable";
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
    my $cutoff = $self->cutoff;
    my $save_screened_reads = $self->save_screened_reads;

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

    my $passed_reads = 0;
    my $failed_reads = 0;

    while (my $header = $input_fh->getline) 
    {
        my $seq = $input_fh->getline;
        my $sep = $input_fh->getline;
        my $qual = $input_fh->getline;
        my $count = 0;

        $seq=~s/(N)/$count++;$1/eg; # get N-count
        if ($cutoff > 0 and $count >= $cutoff) {
            $failed_reads++;
        } else {
            $passed_reads++;   
            $output_fh->print("$header$seq$sep$qual");
        }
    }   

    $input_fh->close;
    $output_fh->close;

    $self->passed_reads($passed_reads);
    $self->failed_reads($failed_reads);

    return 1;
}

1;
