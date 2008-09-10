package Genome::Model::Command::Build::Assembly::FilterReadSet::Seqclean;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly::FilterReadSet::Seqclean {
    is => 'Genome::Model::Command::Build::Assembly::FilterReadSet',
    has => [
            sff_file => {
                         is_input => 1,
                         via => 'prior_event'
                     },
            fasta_file => {
                           is_output => 1,
                           calculate_from => ['sff_file'],
                           calculate => q|
                               my $fasta_file = $sff_file;
                               $fasta_file =~ s/\.sff$/\.fna/;
                               return $fasta_file;
                           |
                       },
            seqclean_report => {
                                is_output => 1,
                                calculate_from => ['fasta_file'],
                                calculate => q|
                                     return $fasta_file .'.cln';
                                 |
                             },
        ]
};

sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $model = $self->model;

    #Need to dump fasta or convert from sff
    unless (-e $self->fasta_file) {
        my $fasta_converter = Genome::Model::Tools::454::Sffinfo->create(
                                                                         sff_file => $self->sff_file,
                                                                         output_file => $self->fasta_file,
                                                                         params => '-s',
                                                                     );
        unless ($fasta_converter->execute) {
            $self->error_message("Failed to run fasta converter on event ". $self->id);
            return;
        }
    }

    unless (-e $self->seqclean_report) {
        my $params = '-c 2';
        my $seq_clean = Genome::Model::Tools::454::Seqclean->create(
                                                                    in_fasta_file => $self->fasta_file,
                                                                    seqclean_params => $params,
                                                                );
        unless ($seq_clean->execute) {
            $self->error_message('Failed to run seq clean ');
            return;
        }
    }

    unless (-e $self->seqclean_report) {
        $self->error_message('Can not find seqclean report '. $self->seqclean_report .' or it is zero size');
        return;
    }
    return 1;
}


1;
