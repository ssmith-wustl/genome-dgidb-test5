package Genome::Site::WUGC;
use strict;
use warnings;

use Class::Autouse;

# configuration for internal WUGC network software & LIMS 
# this module is called by Genome::Config::edu::wustl::gsc right now on all *.gsc.wustl.edu hosts
# print STDERR "using " . __PACKAGE__ . "\n";

$INC{"UNIVERSAL/can.pm"} = 'no';

# this callback will load the GSCApp module, and initialize the app to work with GSC modules
my $initialized = ''; 
our $checks = 0;
my $callback = sub {
    my ($pkg, $method, $class) = @_;
    $checks++;
    # print "ck @_: $initialized\n";

    return if $initialized eq 'complete' or $initialized eq 'in progress';
    return unless substr($pkg,0,5) eq 'GSC::' or substr($pkg,0,5) eq 'App::';

    # load and initialize GSCApp the first time something GSC:: or App:: is used.
    # since App::Init configures its own dynamic loader we dont' do anything 
    # afterward, but we do need to wrap its configuration the first time to prevent conflicts

    warn "using internal LIMS modules...";
    $DB::single = 1;

    if ($GSCApp::{BEGIN}) {
        # We've already done "use GSCApp" somewhere, and it was not
        # done before "use Genome".  Just bail.
        $initialized = 'error';
        Carp::confess("Some code in the Genome tree has a 'use GSCApp' in it.  Please remove this.");
    }

    if ($initialized eq 'error') {
        # the above happened earlier, and apparently the app did not exit
        Carp::confess("Cannot work with $pkg.  Some code in the Genome tree has a 'use GSCApp' in it.  Please remove this.");
    }

    $initialized = 'in progress';

    # remove the placeholder from above so we can actually load this module
    delete $INC{"App/Init.pm"};
    delete $INC{"GSCApp.pm"};
    
    require GSCApp;
    GSCApp->import();

    # ensure our access to the GSC schema is rw, and that our special env variables match up
    unless (App::Init->initialized) {
        App::DB->db_access_level('rw');
    }
    _sync_env();

    # GSCApp removes our overrides to can/isa for Class::Autoloader.  Tell it to put them back.
    App::Init->_restore_isa_can_hooks();

    $initialized = 'complete';

    return $class->can($method);
};

if ($GSCApp::{BEGIN}) {
    # GSCApp is was used first.
    
    # configure Genome & UR to follow its configuration.
    _sync_env();

    # GSCApp removes our overrides to can/isa for Class::Autoloader.  Tell it to put them back.
    App::Init->_restore_isa_can_hooks();
}
else {
    # No code has used GSCApp yet.
    Class::Autouse->sugar($callback);

    # The following ensures that, if someone uses GSCApp directly later, instead
    # of using the GSC classes directly, the callback will catch it and raise an error.
    # Since App::Init messes with UNIVERSAL::{can,isa} directly we need to 
    # wrap the actual use of this module and restore those methods.
    $INC{"App/Init.pm"} ||= 'virtual';
    $INC{"GSCApp.pm"} ||= 'virtual';
}

sub _sync_env {
    if (App::DB::TableRow->use_dummy_autogenerated_ids || UR::DataSource->use_dummy_autogenerated_ids) {
        unless (App::Init->initialized) {
            App::DB::TableRow->use_dummy_autogenerated_ids(1);
        }
        UR::DataSource->use_dummy_autogenerated_ids(1);
    }
    if (App::DBI->no_commit || UR::DBI->no_commit) {
        unless (App::Init->initialized) {
            App::DBI->no_commit(1);
        }
        UR::DBI->no_commit(1);
    }
}

1;

=pod

=head1 NAME

Genome::Site::WUGC - internal configuration for the WU Institute of Genomic Medicine 

=head1 DESCRIPTION 

Configures the Genome Modeling system to work on the internal network at 
The Institute of Genomic Medicine at Washington University

This module ensures that GSCApp and related modules are avialable to the running application.

It is currently a goal that GSCApp need not be used by this module, and that individual
modules under it provide transparent wrappers for WUIGM-specific infrastructure.

=head1 BUGS

For defects with any software in the genome namespace,
contact software@genome.wustl.edu.

=head1 SEE ALSO

B<Genome>, B<Genome::Config>, B<Genome::Site>

=cut



