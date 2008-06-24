package MGAP::Command::GenePredictor::Glimmer3;

use strict;
use warnings;

use Workflow;
use BAP::Job::Glimmer;

class MGAP::Command::GenePredictor::Glimmer3 {
    is => ['MGAP::Command::GenePredictor'],
    has => [
            model_file => { is => 'SCALAR', doc => 'absolute path to the model file for this fasta' },
            pwm_file => { is => 'SCALAR' , doc => 'absolute path to the pwm file for this fasta' },
    ],
};

operation_io MGAP::Command::GenePredictor::Glimmer3 {
    input => [ 'model_file', 'pwm_file', 'fasta_file' ],
    output => [ 'bio_seq_feature' ]
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;

    my $seqio = Bio::SeqIO->new(-file => $self->fasta_file(), -format => 'Fasta');

    my $seq = $seqio->next_seq();

    
    ##FIXME: The last two args are the circular dna flag and the
    ##       job_id, which are hardcoded here in a rather lame fashion.
    my $legacy_job = BAP::Job::Glimmer->new(
                                            'glimmer3',
                                            $seq,
                                            $self->model_file(),
                                            $self->pwm_file(),
                                            0,
                                            2112,
                                        );

    $legacy_job->execute();

    my @features = $legacy_job->seq()->get_SeqFeatures();
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

1;
