
package Genome::Model::Command::Tools::SetupHierarchy;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
		has => [ 'run', 'lanes', 'sample_path', 'bustard_path' ]
);

sub help_brief {
    "add reads to a genome model"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 


EOS
}

sub execute {
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

