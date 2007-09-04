package Genome::Model::Command::AddReads::AssignRun::Solexa;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [ 
        model   => { is => 'String', is_optional => 0, doc => 'the genome model on which to operate' },
        run_id  => { is => 'Integer' },
    ]
);

sub help_brief {
    "Creates the appropriate items on the filesystem for a new Solexa run"
}

sub help_detail {                           
    return <<EOS 
This command is normally run automaticly as part of add-reads
EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;

    my $run = Genome::Run->get(run_id => $self->run_id);
    unless ($run) {
        $self->error_message("Did not find run info for run_id ".$self->run_id);
        return 0;
    }

    # make path
    #my $sample_path = $self->sample_path . '/runs/solexa/aml' . $self->run;
    my $sample_path = $self->full_path;
    mkpath $sample_path;
    unless (-d $sample_path) {
        $self->error_message("Sample pathname $sample_path was not created");
        return;
    }

    my $base_dir = '/gscmnt/sata114/info/medseq/aml';
    # make symbolic link to path
    #my $base_run_dir = $base_dir . '/aml' .$self->run;
    my $base_run_dir = $base_dir . '/aml' .$self->run_id;
    if (-e $base_run_dir) {
            $self->error_message("$base_run_dir already exists");
            return;
    }

    # make symbolic link to bustard
    die "FIXME: where can we get ahold of the bustard_path from?";
    my $bustard_dir = $self->bustard_path;
    if (-e "$sample_path/prb_src") {
            $self->error_message("$sample_path/prb_src already exists");
            return;
    }
    #system("ln -s $sample_path $base_run_dir");
    unless (symlink($sample_path,$base_run_dir)) {
        $self->error_message("Can't create symlink $base_run_dir pointing to $sample_path: $!");
        return;
    }
 
    #system("ln -s $bustard_dir $sample_path/prb_src");
    unless (symlink($bustard_dir, $sample_path . "/prb_src")) {
        $self->error_message("Can't create symlink $sample_path/prb_src pointing to $bustard_dir: $!");
        unlink($base_run_dir);  # Clean up symlink created above
        return;
    }
    return 1;
}
1;

