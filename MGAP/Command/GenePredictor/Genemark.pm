package MGAP::Command::GenePredictor::Genemark;

use strict;
use warnings;

use Workflow;
use BAP::Job::Genemark;

use IO::Dir;

class MGAP::Command::GenePredictor::Genemark {
    is => ['MGAP::Command::GenePredictor'],
    has => [
            gc_percent => { is => 'Float', doc => 'GC content' },
            model_file => { is => 'SCALAR', is_optional => 1, doc => 'Genemark model file' },
    ],
};

operation_io MGAP::Command::GenePredictor::Genemark {
    input => [ 'gc_percent', 'fasta_file' ],
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

    my $gc_percent = sprintf("%.0f", $self->gc_percent());
    my $gc_model = $self->_select_model($gc_percent);

    $self->model_file($gc_model);
    
    ##FIXME: The last arg is the job_id, which is hardcoded here in 
    ##       a rather lame fashion.
    my $legacy_job = BAP::Job::Genemark->new(
                                             $seq,
                                             $gc_model,
                                             2112,
                                        );

    $legacy_job->execute();

    my @features = $legacy_job->seq()->get_SeqFeatures();
    
    $self->bio_seq_feature(\@features);
           
    return 1;
    
}

sub _select_model {

    my $self       = shift;
    my $gc_percent = shift;
    

    ##FIXME: This should probably not be hardcoded, at least not here
    my $model_dir = '/gsc/pkg/bio/genemark.hmm/installed/modeldir';

    unless (-e $model_dir) {
        die "model directory does not seem to exist: $model_dir";
    }

    my $dh = IO::Dir->new($model_dir);

    my @model_files = $dh->read();

    my ($model_file) = grep { $_ =~ /heu_11_$gc_percent\.mod/ } @model_files;

    unless (defined($model_file)) {
        die "could not locate model file for gc content of $gc_percent percent";
    }

    return "$model_dir/$model_file";
    
}

1;
