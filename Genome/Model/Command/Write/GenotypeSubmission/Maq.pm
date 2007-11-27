package Genome::Model::Command::Write::GenotypeSubmission::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;

use lib "/gsc/scripts/gsc/medseq/lib";
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

class Genome::Model::Command::Write::GenotypeSubmission::Maq {
    is => 'Command',
    has => [
        ref_seq_id => { is => 'Integer', is_optional => 0, doc => 'the reference sequence on which to operate (default = "all_sequences")', default=>'all_sequences'},
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
        mutation_data => { is => 'Listref', is_optional => 1, doc => 'Use this pre-computed mutation data to generate the file, instead of computing it itself.  Should only be used internally.'},
    ]
};

sub help_brief {
    "Write a genotype submission file from a variation set created by maq";
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments write-genotype-submission maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}


sub execute {
    my $self = shift;
    $DB::single = 1;
    
    my $model = Genome::Model->get($self->model_id);

    my @run_events = grep {defined $_->run_id}
                          Genome::Model::Event->get(model_id=>$self->model_id,
                                                    event_type => { operator =>'like',
                                                                    value => 'genome-model add-reads assign-run%'
                                                                   });
    
    my $platform;
    foreach my $event (@run_events) {
        my ($p) = $event->event_type =~ m/genome-model add-reads assign-run (\w+)$/;
        if (!defined $platform) {
            $platform = $p;
        }
        if ($p ne $platform) {
            $self->error_message("mixing runs of multiple sequencing platforms, maq only works with solexa runs!");
            return;
        }
    }
    
    my $mut_list;
    if ($self->mutation_data) {
        $mut_list = $self->mutation_data;
    } else {
        my $gproc = Genome::Model::GenotypeProcessor::Maq->create(ref_seq_id=>$self->ref_seq_id,
                                                                  model_id=>$self->model_id);
        $mut_list = $gproc->get_mutations();
    }

    my $fh = Genome::Model::Command::Write::GenotypeSubmission::Open($model->data_directory . "/" . $_->ref_seq_id);
    unless (defined($fh)) {
        $self->error_message("Unable to open genotype submission file for writing");
	return;
    }
    
    foreach (@$mut_list) {
        
        Genome::Model::Command::Write::GenotypeSubmission::Write($fh,
                                                                 $_->{software},
                                                                 $_->{build},
                                                                 $_->{chromosome},
                                                                 $_->{plus_minus},
                                                                 $_->{start},
                                                                 $_->{end},
                                                                 $_->{sample_id},
                                                                 $_->{genotype_allele1},
                                                                 $_->{genotype_allele2},
                                                                 $_->{scores},
                                                                 $_->{count});        
    }
    
    $fh->close();

    return 1;
}

1;

