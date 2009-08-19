package Genome::Model::Command::Build::Run;

use strict;
use warnings;

use Genome;
use Workflow;

use Regexp::Common;

class Genome::Model::Command::Build::Run{
    is => 'Genome::Model::Command',
    has => [
            build_id =>{
                         is => 'Number',
                         doc => 'The id of the build in which to update status',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
            restart => {
                is => 'Boolean',
                is_optional => 1,
                doc => 'Restart a new Workflow Instance. Overrides the default behavior of resuming an existing workflow.' 
            }
    ],
};

sub help_brief {
    'Launch all jobs for a build using the workflow framework.  This command is a replacement for the old run-jobs'
}

sub help_detail {
    return <<EOS 
EOS
}
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless (defined $self->build_id ) {
        my $model = $self->model;
        unless ($model) {
            $self->delete;
            return;
        }
        my $build_id = $model->current_running_build_id;
        unless ($build_id) {
            $self->error_message('Failed to get build_id for model '. $model->id);
        }
        $self->build_id($build_id);
    }
    unless ( $self->_verify_build ) {
        $self->delete;
        return;
    }
    return $self;
}

sub _verify_build {
    my $self = shift;

    unless ( defined $self->build_id ) {
        $self->error_message("No build id given");
        return;
    }

    unless ( $self->build_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Build id given (%s) is not an integer', $self->build_id) );
        return;
    }

    unless ( $self->build ) {
        $self->error_message( sprintf('Can\'t get build for id (%s) ', $self->build_id) );
        return;
    }

    return 1;
}

sub execute {
    my $self = shift;

    my $build = $self->build;

    my $xmlfile = $self->build->data_directory . '/build.xml';

    if (!-e $xmlfile) {
        $self->error_message("Can't find xml file for build (" . $self->build_id . "): " . $xmlfile);
        return 0;
    }

    require Workflow::Simple;

    my $loc_file = $self->build->data_directory . '/server_location.txt';
    if (-e $loc_file) {
        $self->error_message("Server location file in build data directory exists, if you are sure it is not currently running remove it and run again: $loc_file");
        return 0;
    } 

    $Workflow::Simple::server_location_file = $loc_file;

    my $w = $build->newest_workflow_instance;
    if ($w && !$self->restart) {
        if ($w->is_done) {
            $self->error_message("Workflow Instance is complete, if you are sure you need to restart use the --restart option");
            return 0;
        }
    }


    $self->build->initialize;
    UR::Context->commit;

    my $w = $build->newest_workflow_instance;
    
    my $output;
    
    if ($w && !$self->restart) {
        $output = Workflow::Simple::resume_lsf($w->id);
    } else {

        $output = Workflow::Simple::run_workflow_lsf(
            $xmlfile,
            prior_result => 1
        );
    }

    if ( $output ) { # Success
        $build->success;
    }
    else { # Fail
        $build->fail( @Workflow::Simple::ERROR );
    }

    return 1;
}

1;
