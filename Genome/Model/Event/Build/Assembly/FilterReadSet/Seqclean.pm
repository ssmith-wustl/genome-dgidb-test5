package Genome::Model::Event::Build::Assembly::FilterReadSet::Seqclean;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::Assembly::FilterReadSet::Seqclean {
    is  => 'Genome::Model::Event::Build::Assembly::FilterReadSet',
    has => [
        seqclean_report => {
            calculate_from => ['instrument_data'],
            calculate      => q|
                return $instrument_data->fasta_file .'.cln';
            |
        },
    ]
};

sub bsub_rusage {
    return "-R 'span[hosts=1]'";
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "assemble a genome";
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

    my $model           = $self->model;
    my $instrument_data = $self->instrument_data;

    unless ( -e $self->seqclean_report ) {
        my $params    = '-c 2';
        my $seq_clean = Genome::Model::Tools::454::Seqclean->create(
            in_fasta_file   => $instrument_data->fasta_file,
            seqclean_params => $params,
        );
        unless ( $seq_clean->execute ) {
            $self->error_message('Failed to run seq clean ');
            return;
        }
    }

    unless ( -e $self->seqclean_report ) {
        $self->error_message( 'Can not find seqclean report '
              . $self->seqclean_report
              . ' or it is zero size' );
        return;
    }
    return 1;
}

1;
