package Genome::Completion::Command::Update;

use strict;
use warnings;

class Genome::Completion::Command::Update {
    is => 'Genome::Command::Base',
    doc => 'update the tab completion spec files (.opts)',
};

sub help_detail {
    my $help_detail;

    $help_detail .= "Updates the tab completion spec files:\n";
    $help_detail .= " * Genome/Command.pm.opts\n";
    $help_detail .= " * Genome/Model/Tools.pm.opts";

    return $help_detail;
}

sub execute {
    my $self = shift;

    my @command_classes = ('Genome::Model::Tools', 'Genome::Command');
    for my $classname (@command_classes) {
        my $genome_completion = UR::Namespace::Command::Update::TabCompletionSpec->create(
            classname => $classname,
        );
        unless ($genome_completion->execute) {
            $self->error_message("Updating the $classname spec file did not complete succesfully!");
        }
    }

    $self->status_message("Committing any updated .opts file(s)!");
    my @files = `git status -s`;
    map { chomp $_ } @files;
    my ($gmt_opts) = grep { $_ =~ /Tools\.pm\.opts/ } @files;
    $gmt_opts =~ s/^\s*M\s*//;
    my ($genome_opts) = grep { $_ =~ /Command\.pm\.opts/ } @files;
    $genome_opts =~ s/^\s*M\s*//;
    if ($gmt_opts || $genome_opts) {
        system("git add $gmt_opts $genome_opts");
        $self->status_message("Remember to push the committed .opts file(s)!");
    }


    return 1;
}

1;
