package Genome::Model::Command::AddReads::AssignRun::454;

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
        model   => { is => 'String', is_optional => 0, doc => 'the genome model on which to operate' }
    ]
);

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_detail {                           
    return <<EOS 
not implemented
EOS
}

sub execute {
    my $self = shift;
    my $model = Genome::Model->get(name=>$self->model);
    $self->error_message("running " . $self->command_name . " on " . $model->name . "!");
    $self->status_message("Model Info:\n" . $model->pretty_print_text);
    return 0; 
}

# old logic goes here and needs cleaning up
sub Xexecute {
    my $self = shift;
    $DB::single=1;
    Genome::Model->add_run_info( 
        run_number => $self->run,
        lanes => $self->lanes,
        bustard_path => $self->bustard_path,
        sample_path => $self->sample_path
    );
    # make path
    my $sample_path = $self->sample_path . '/runs/solexa/aml' . $self->run;
    mkpath $sample_path;
    my $base_dir = '/gscmnt/sata114/info/medseq/aml';
    # make symbolic link to path
    my $base_run_dir = $base_dir . '/aml' .$self->run;
    if (-e $base_run_dir) {
            $self->error_message("$base_run_dir already exists");
            return;
    }
    # make symbolic link to bustard
    my $bustard_dir = $self->bustard_path;
    if (-e "$sample_path/prb_src") {
            $self->error_message("$sample_path/prb_src already exists");
            return;
    }
    system("ln -s $sample_path $base_run_dir");
    system("ln -s $bustard_dir $sample_path/prb_src");
    return 1;
}
1;

