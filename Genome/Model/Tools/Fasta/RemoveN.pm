package Genome::Model::Tools::Fasta::RemoveN;

use strict;
use warnings;

use Genome;
use Workflow;
use File::Basename;
use IO::File;
use Bio::SeqIO;

class Genome::Model::Tools::Fasta::RemoveN
{
    is => 'Genome::Model::Tools::Fasta',
    has_input => [
            n_removed_file => {
                                    doc => 'file to write to',
                                    is => 'String',
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
    my $fasta_file = $self->fasta_file;
    my $n_removed_file = ($self->n_removed_file ? $self->n_removed_file : $fasta_file . "n_removed");
    my $fa_in_io = $self->get_fasta_reader($fasta_file);
    my $fa_out_io = $self->get_fasta_writer($n_removed_file);
    
    while (my $seq = $fa_in_io->next_seq) 
    {
        $fa_out_io->write_seq($seq) unless ($seq->seq=~'N');
    }   
    $self->n_removed_file($n_removed_file);

    return 1;
}

1;
