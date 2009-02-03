package Genome::Model::Command::Build::CombineVariants::ConfirmQueues; 

use strict;
use warnings;
use Genome;
use PP::JobScheduler;

class Genome::Model::Command::Build::CombineVariants::ConfirmQueues {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    # This bare query is used because it is much faster than any alternative
    # It finds all queue pse's associated with the 3730 pipeline
    my $queue_pse_query = "select tp.*, pse.*
    from process_step_executions pse
    join process_steps ps on ps.ps_id = pse.ps_ps_id
    join tpp_pse tp on pse.pse_id = tp.pse_id and pse.tp_id = tp.tp_id and container_position = 0 and barcode = '000000'
    join process_step_executions pse_prior on pse_prior.pse_id = tp.prior_pse_id
    join process_steps ps_prior on ps_prior.ps_id = pse_prior.ps_ps_id
    where ps.pro_process_to = 'queue instrument data for genome modeling'
        and ps_prior.pro_process_to = 'evaluate sequence variation'
    order by pse.date_scheduled desc";

    # Get all scheduled 3730 queue pse's
    my @pses = GSC::PSE->get(
        sql => $queue_pse_query,
    );
    @pses = grep {$_->pse_status eq 'scheduled'} @pses;

    my %pses_for_assembly;
    for my $pse ( @pses ){
        my $assembly_project_name = $self->ap_name($pse); 
        push @{$pses_for_assembly{$assembly_project_name}}, $pse->id;
    }

    # Split up the PSE confirms between a bunch of lsf jobs because we run out of memory if we do it all in one process
    # FIXME figure out how to do this in a sane way...
    my @jobs = ();
    for my $assembly_name (keys %pses_for_assembly) {
        my @pse_ids = @{$pses_for_assembly{$assembly_name}};

        my $pp = undef;

        my $pse_string = join(",", @pse_ids);
        my $pse_out = join("_", @pse_ids);
        my $command = 'genome-model build combine-variants confirm-queues confirm-queue-pses-for-assembly --pse-ids '.$pse_string;

        my $log_dir = $self->build->resolve_log_directory;
        while (!$pp) {
            $pp = PP->create(
                pp_type => 'lsf',
                q       => 'short',
                command => $command,
                J       => 'TCGA_queue_pse_confirm',
                u       => $ENV{USER} . '@watson.wustl.edu', #FIXME env user instead? Change later
                oo      => "$log_dir/$pse_out.out", 
                eo      => "$log_dir/$pse_out.error", 
            );

            if (!$pp) {
                warn "Failed to create LSF job for $pse_string";
                sleep 10;
            }
            else {
                push @jobs, $pp;
                print "$pse_string scheduled\n";
            }
        }
    }


    # Schedule the jobs and wait for them to complete
    if (@jobs){

        my $scheduler = new PP::JobScheduler(
            job_list         => \@jobs,
            day_max          => 100,
            night_max        => 100,
            refresh_interval => 60,
        );
        $scheduler->start();

        # Wait for all of the jobs to complete
        my @running_jobs = @jobs;
        while (1){
            sleep 30;
            @running_jobs = grep {$_->is_held || $_->is_in_queue} @running_jobs;
            last unless @running_jobs;
        }
    }

    return 1;
}

# Return the prior pse
sub prior{
    my ($self, $pse) = @_;

    return GSC::PSE->get($pse->added_param('control_pse_id'));
}

# Return the assembly projecty name
sub ap_name{
    my ($self, $pse) = @_;

    my $ap = prior($pse)->assembly_project_name;
    return $ap;
}

