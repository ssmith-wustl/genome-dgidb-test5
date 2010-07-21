
package Genome::Model::Command::Services::WebApp::FCGI::ProcManager;

use strict;
use warnings;
use base qw(FCGI::ProcManager);

sub _disabled_pm_pre_dispatch {
    my $self = shift;

#    $self->pm_notify('pre_dispatch');

    $self->SUPER::pm_pre_dispatch(@_);
}

sub pm_post_dispatch {
    my $self = shift;

#    $self->pm_notify('post_dispatch');

    exit;
#    UR::Context->rollback;
#    UR::Context->clear_cache;

    $self->SUPER::pm_post_dispatch(@_);
}


1;
