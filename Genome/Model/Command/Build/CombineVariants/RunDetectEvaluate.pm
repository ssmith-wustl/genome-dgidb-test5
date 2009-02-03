package Genome::Model::Command::Build::CombineVariants::RunDetectEvaluate;

use strict;
use warnings;
use Genome;
use PP::JobScheduler;

class Genome::Model::Command::Build::CombineVariants::RunDetectEvaluate {
    is => 'Genome::Model::Event',
};
 
sub execute {
    my $self = shift;
    
    my $assembly_directory = $self->build->assembly_directory;
    my $assemblies_file = $self->build->assemblies_to_run_file;
    my $log_dir = $self->resolve_log_directory;
 
    my $assembly_fh = IO::File->new($assemblies_file);
    unless($assembly_fh) {
        $self->error_message("Could not open filehandle for $assemblies_file");
        return;
    }

    my @assembly_names;
    while (my $assembly = $assembly_fh->getline) {
        chomp $assembly;
        push @assembly_names, $assembly;
    }

    my @jobs;
    for my $assembly_name (@assembly_names){
        my $command = "genome-model utility run-detect-evaluate --assembly_name $assembly_name --assembly-directory $assembly_directory";

        my $pp;
        while (!$pp) {
            $pp = PP->create(
                pp_type => 'lsf',
                q       => 'long',
                command => $command,
                J       => "$log_dir/assembly_dump_$assembly_name",
                u       =>  $ENV{USER}.'@genome.wustl.edu',
            );

            if (!$pp) {
                warn "Failed to create LSF job for $assembly_name";
                sleep 10;
            }
            else {
                push @jobs, $pp;
                print "$command scheduled for assembly $assembly_name\n";
            }
        }
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
    }else{
        $self->error_message("no jobs!");
        return;
    }
}

=pod

=head1 NAME
ScriptTemplate - template for new perl script

=head1 SYNOPSIS

=head1 DESCRIPTION 

=cut

#$HeadURL$
#$Id$


