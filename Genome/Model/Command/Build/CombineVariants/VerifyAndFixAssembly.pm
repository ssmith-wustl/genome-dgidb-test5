package Genome::Model::Command::Build::CombineVariants::VerifyAndFixAssembly;

use strict;
use warnings;
use Genome;
use PP::JobScheduler;

class Genome::Model::Command::Build::CombineVariants::VerifyAndFixAssembly {
    is => 'Genome::Model::Event',
};
 
sub execute {
    my $self = shift;
    
    my $assembly_file = $self->build->assemblies_to_run_file;
    my $assembly_directory = $self->build->assembly_directory;
    my $log_dir = $self->resolve_log_directory;
 
    my $assembly_fh = IO::File->new($assembly_file);
    unless($assembly_fh) {
        $self->error_message("Could not open filehandle for $assembly_file");
        return;
    }

    my @assembly_names;
    while (my $assembly = $assembly_fh->getline) {
        chomp $assembly;
        push @assembly_names, $assembly;
    }

    my @jobs;
    for my $assembly_name (@assembly_names) {
        my $ace_file = "$assembly_directory/edit_dir/$assembly_name.ace";
        my $command = "genome-model build verify-and-fix-assembly single-assembly --assembly_name $assembly_name --assembly-directory $assembly_directory --ace-file $ace_file";

        my $pp;
        while (!$pp) {
            $pp = PP->create(
                pp_type => 'lsf',
                q       => 'long',
                command => $command,
                J       => "verify_and_fix_$assembly_name",
                u       =>  $ENV{USER}.'@genome.wustl.edu',
            );

            if (!$pp) {
                $self->warning_message("Failed to create LSF job for $assembly_name");
                sleep 10;
            }
            else {
                push @jobs, $pp;
                $self->status_message("$command scheduled for assembly $assembly_name");
            }
        }
    }

    if (@jobs){

        $self->status_message(scalar @jobs." verify and fix assembly jobs created, beginning scheduler");

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


