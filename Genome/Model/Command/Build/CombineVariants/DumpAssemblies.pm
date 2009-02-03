package Genome::Model::Command::Build::CombineVariants::DumpAssemblies;

use strict;
use warnings;

use Genome;
use IO::File;
use PP::JobScheduler;

class Genome::Model::Command::Build::CombineVariants::DumpAssemblies {
    is => 'Genome::Model::Event',
};

sub help_brief {
    "Dumps assemblies to be used in the 3730 variant detection pipeline, given assembly names.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt combine-variants dump-assemblies
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;
    
    my $assembly_file = $self->build->assemblies_to_run_file;
    my $assembly_directory = $self->build->assembly_directory;
    my $assembly_fh = IO::File->new($assembly_file);
    unless($assembly_fh) {
        $self->error_message("Could not open filehandle for $assembly_file");
    }

    my @assembly_names;
    while (my $assembly = $assembly_fh->getline) {
        chomp $assembly;
        push @assembly_names, $assembly;
    }

    unless (scalar(@assembly_names) > 0) {
        $self->error_message("Did not get any assembly names");
        return;
    }

    unless (-d $assembly_directory) {
        $self->error_message("Destination directory $assembly_directory does not exist");
        return;
    }

    my $assembly_count;
    my @jobs;
    for my $assembly_name (@assembly_names) {
 
        # For now lets shortcut...
        if (-d "$assembly_directory/$assembly_name") {
            $self->status_message("Found $assembly_name existing... skipping");
            next;
        }
        
        $self->status_message("Checking out $assembly_name\n");

        $assembly_count++;

        my $assembly_project = GSC::AssemblyProject->get(assembly_project_name=>$assembly_name);
        unless ($assembly_project) {
            $self->error_message("no assembly_project for $assembly_name");
            return;
        }

        my $asp_id = $assembly_project->asp_id;
        unless ($asp_id) {
            $self->error_message("no asp_id for $assembly_project");
            return;
        }

        my $command = "perl /gsc/scripts/bin/check_out_assembly_project -asp-id $asp_id -target-dir $assembly_directory";

        my $pp;
        while (!$pp) {
            $pp = PP->create(
                pp_type => 'lsf',
                q       => 'long',
                command => $command,
                J       => "assembly_dump_$assembly_name",
                u       =>  $ENV{USER}.'@genome.wustl.edu',
            );

            if (!$pp) {
                $self->warning_message("Failed to create LSF job for $assembly_name.$asp_id");
                sleep 10;
            }
            else {
                push @jobs, $pp;
                $self->status_message("$command scheduled for assembly $assembly_name");
            }
        }
    }

    unless (scalar @jobs == $assembly_count){
        $self->error_message("Didn't schedule correct amount of jobs(".scalar @jobs.") for # assemblies($assembly_count)");
        return;
    }

    if (@jobs){
        $self->status_message(scalar @jobs." assembly dump jobs created, beginning scheduler");

        my $scheduler = new PP::JobScheduler(
            job_list         => \@jobs,
            day_max          => 50,
            night_max        => 100,
            refresh_interval => 120,
        );
        $scheduler->start();
        
        my @running_jobs = @jobs;
        while (1){
            sleep 30;
            @running_jobs = grep {$_->is_held || $_->is_in_queue} @running_jobs;
            last unless @running_jobs;
        }

    }else{
        $self->error_message("no jobs!");
        return;
    }



    return 1;
}

1;

