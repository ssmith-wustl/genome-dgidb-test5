package Genome::Model::Command::AddReads::UploadDatabase::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;

use lib "/gsc/scripts/gsc/medseq/lib";
use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

class Genome::Model::Command::AddReads::UploadDatabase::Maq {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

sub help_brief {
    "Upload a variation set created by maq to the medical genomics database";
}

sub help_synopsis {
    return <<"EOS"
    genome-model postprocess-alignments upload-database maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}


# This part is stolen and refactored from Brian's original G::M::Command::Write::GenotypeSubmission::Maq
# Maybe it should be moved to a Maq-specific tools module at some point?

# This used to be a command-line arg to the submitter.  Looks like it's pretty much
# always 0.  If that's true, then it can be removed.  If it changes, then it should be made an
# attribute of the model
our $QC_CUTOFF = 0;

sub execute {
    my $self = shift;
    

    
    my $model = Genome::Model->get($self->model_id);

    my @run_events = grep {defined $_->run_id} Genome::Model::Event->get(model_id=>$self->model_id,
                                                                         event_type => {operator =>'like',
                                                                         value => 'genome-model add-reads assign-run%'});
    
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
    
    my %run_ids = map {$_->run_id, 1} @run_events;
    my $run_count = scalar keys %run_ids;

    my $gproc = Genome::Model::GenotypeProcessor::Maq->create(ref_seq_id=>$self->ref_seq_id,
                                                              model_id=>$self->model_id);

    my $mut_list = $gproc->get_mutations();


    my $mutations = {};
    
    foreach (@$mut_list) {

        $mutations = MG::IO::GenotypeSubmission::AddMutation($mutations,$_->{software},
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

    MG::IO::GenotypeSubmission::LoadDatabase($mutations,
                                             #check => $check,
                                             #rccheck => $rccheck,
                                             #verbose => $verbose,
                                             source => 'wugsc',
                                             tech_type => $platform,
                                             mapping_reference => ($model->dna_type eq "whole" ? 'hg' : 'ccds_merged'), 
                                             run_identifier => $model->sample_name . "_" . $run_count,  
                                         );
    my $submission_file_writer = Genome::Model::Command::Write::GenotypeSubmission::Maq->create(
                                        ref_seq_id    => $self->ref_seq_id,
                                        model_id      => $self->model_id,
                                        mutation_data => $mutations,
                                      );
    unless ($submission_file_writer) {
        $self->error_message("Unable to create a submisstion file writer command");
        return;
    }

    $submission_file_writer->execute() || return;

    return 1;
}

sub bsub_rusage {
    return "-R 'rusage[mem=4000]'";
}

1;

