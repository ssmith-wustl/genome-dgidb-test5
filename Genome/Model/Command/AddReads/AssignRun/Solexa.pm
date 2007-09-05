package Genome::Model::Command::AddReads::AssignRun::Solexa;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Genome::Model::FileSystemInfo;

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
This command is normally run automatically as part of add-reads
EOS
}

sub execute {
    my $self = shift;

    $DB::single=1;

    my $run = Genome::RunChunk->get(id => $self->run_id);
    unless ($run) {
        $self->error_message("Did not find run info for run_id " . $self->run_id);
        return 0;
    }
    
    my $model = Genome::Model->get( name => $self->model );

    # create a space for links to bustards for this sample / platform / DNA type combination, unless exists
    my $run_sample_path = $model->sample_path . '/runs/' . $run->sequencing_platform . '/' . $model->dna_type;
    mkpath $run_sample_path unless (-e $run_sample_path && -d $run_sample_path);
    unless (-d $run_sample_path) {
        $self->error_message("Run Sample pathname $run_sample_path was not created");
        return;
    }

    # ensure symbolic link to bustard not already present
    my $bustard_dir = $run->full_path;
    if (-e "$run_sample_path/prb_src") {
            $self->error_message("$run_sample_path/prb_src already exists");
            return;
    }
 
    # make symbolic link to bustard
    unless (symlink($bustard_dir, $run_sample_path . "/prb_src")) {
        $self->error_message("Can't create symlink $run_sample_path/prb_src pointing to $bustard_dir: $!");
        return;
    }
    
    return 1;
}
1;

