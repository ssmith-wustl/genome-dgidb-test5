package Genome::Model::Command::AddReads::UploadDatabase::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use IO::File;

#use lib "/gsc/scripts/gsc/medseq/lib";
#use MG::Transform::Coordinates::TranscriptToGenomic;
use MG::IO::GenotypeSubmission;

class Genome::Model::Command::AddReads::UploadDatabase::Maq {
    is => 'Genome::Model::Command::AddReads::UploadDatabase',
};

sub help_brief {
    "Upload a variation set created by maq to the medical genomics database";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads upload-database maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the postprocess-alignments process
EOS
}

sub should_bsub { 1;}


# This part is stolen and refactored from Brian's original G::M::Command::Write::GenotypeSubmission::Maq
# Maybe it should be moved to a Maq-specific tools module at some point?

# This used to be a command-line arg to the submitter.  Looks like it's pretty much
# always 0.  If that's true, then it can be removed.  If it changes, then it should be made an
# attribute of the model
our $QC_CUTOFF = 0;

sub execute {
    return 1;
    
    my $self = shift;
    
$DB::single = $DB::stopper;
    my $model = $self->model;

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

    unless ($mut_list) {
        $self->error_message("No mutations found");
        return;
    }


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

    # Looks like some things deep in the bowels of MG::* can call die() in some cases
    # so let's trap those
$SIG{'__DIE__'} = sub {
$DB::single = $DB::stopper;
1;
};
    eval {
        MG::IO::GenotypeSubmission::LoadDatabase($mutations,
                                                 #check => $check,
                                                 #rccheck => $rccheck,
                                                 #verbose => $verbose,
                                                 source => 'wugsc',
                                                 tech_type => $platform,
                                                 mapping_reference => ($model->dna_type eq "whole" ? 'hg' : 'ccds_merged'), 
                                                 run_identifier => $model->sample_name . "_" . $run_count,  
                                             );
    };
    if ($@) {
        $self->error_message($@);
        return;
    }

    #my $submission_file_writer = Genome::Model::Command::Write::GenotypeSubmission::Maq->create(
    #                                    ref_seq_id    => $self->ref_seq_id,
    #                                    model_id      => $self->model_id,
    #                                    mutation_data => $mutations,
    #                                  );
    #unless ($submission_file_writer) {
    #    $self->error_message("Unable to create a submisstion file writer command");
    #    return;
    #}
    #
    #$submission_file_writer->execute() || return;

    return 1;
}

sub bsub_rusage {
    return "-R 'rusage[mem=4000]'";
}


1;

