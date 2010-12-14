package Genome::Config;

use strict;
use warnings;

our $VERSION = $Genome::VERSION;

BEGIN {
    if (my $config = $ENV{GENOME_CONFIG}) {
        # call the specified configuration module;
        eval "use Genome::Config::$config";
        die $@ if $@;
    }
    else {
        # look for a config module matching all or part of the hostname 
        use Sys::Hostname;
        my $hostname = Sys::Hostname::hostname();
        my @hwords = reverse split('\.',$hostname);
        while (@hwords) {
            my $pkg = 'Genome::Config::' . join("::",@hwords);
            local $SIG{__DIE__};
            local $SIG{__WARN__};
            eval "use $pkg";
            if ($@) {
                pop @hwords;
                next;
            }
            else {
                last;
            }
        }
    }
}
use UR;
use Sys::Hostname;

# This module potentially conflicts to the perl-supplied Config.pm if you've
# set up your @INC or -I options incorrectly.  For example, you used -I /path/to/modules/Genome/
# instead of -I /path/to/modules/.  Many modules use the real Config.pm to get info and
# you'll get wierd failures if it loads this module instead of the right one.
{
    my @caller_info = caller(0);
    if ($caller_info[3] eq '(eval)' and $caller_info[6] eq 'Config.pm') {
        die "package Genome::Config was loaded from a 'use Config' statement, and is not want you wanted.  Are your \@INC and -I options correct?";
    }
}

my $arch_os;
sub arch_os {
    unless ($arch_os) {
        $arch_os = `uname -m`;
        chomp($arch_os);
    }
    return $arch_os;
}

# in dev mode we use dev search, dev wiki, dev memcache, etc, but production database still ;)
my $dev_mode = exists $ENV{GENOME_DEV_MODE} ? $ENV{GENOME_DEV_MODE} : (UR::DBI->no_commit ? 1 : 0);
if ($dev_mode) {
    my $h = hostname;
    warn "***** GENOME_DEV_MODE ($h) *****";
}

sub dev_mode {
    shift;
    if (@_ && !$ENV{GENOME_DEV_MODE}) {
        $dev_mode = shift;
    }

    return $dev_mode;
}

sub base_web_uri {

    if (Genome::Config::dev_mode()) {
        return 'https://aims-dev.gsc.wustl.edu/view';
    } else {
        return 'https://imp.gsc.wustl.edu/view';
    }
}

sub user_email {
    my $self = shift;
    my $user = shift;
    $user ||= $ENV{USER};
    return $user . '@genome.wustl.edu';
}

sub current_user_id {
    return $ENV{USER} . '@genome.wustl.edu';
}

sub admin_notice_users {
    qw/abrummet boberkfe jeldred jlolofie ssmith apipe-run/;
}

sub namespaces {
#    my @ns = (qw/BAP Command EGAP GAP Genome MGAP PAP UR Workflow/);
    my @ns = (qw/Genome UR Workflow/);
    return @ns;
}

# operating directories

sub deploy_path {

    if (Genome::Config::dev_mode()) {
        return '/tmp/gsc/scripts/lib/perl';
    } else {
        return '/gsc/scripts/lib/perl';
    }
}

sub snapshot_paths {

    my @snapshot_paths = (
        '/gsc/scripts/opt/passed-model-tests',
        '/gsc/scripts/opt/passed-unit-tests'
    );

    return @snapshot_paths;
}

sub reference_sequence_directory {
    return join('/', Genome::Config::root_directory(), 'reference_sequences');
}

sub root_directory {
    $ENV{GENOME_MODEL_ROOT} || '/gscmnt/sata420/info/symlinks';
}

sub data_directory {
     $ENV{GENOME_MODEL_DATA} || '/gscmnt/sata835/info/medseq';
}

# links

sub alignment_links_directory {
    return shift->root_directory . '/alignment_links';
}

sub model_comparison_link_directory {
    return shift->root_directory . '/model_comparison_links';
}

# data

sub model_data_directory {
    my $self = shift;
    if (defined($ENV{'GENOME_MODEL_TESTDIR'}) &&
        -e $ENV{'GENOME_MODEL_TESTDIR'}
    ) {
            return $ENV{'GENOME_MODEL_TESTDIR'};
    } else {
            return $self->data_directory .'/model_data';
    }   
}

sub alignment_data_directory {
    return shift->data_directory . '/alignment_data';
}

sub model_comparison_data_directory {
    return shift->data_directory . '/model_comparison_data';
}

# reflection of the different types of models, and their related processing profiles and builds

sub type_names {
    return 
        map { s/\-/ /g; $_ }
        map { Command->_command_name_for_class_word($_) }
        map { s/^Genome\::Model:://; $_ } 
        shift->model_subclass_names;
}

my $use_model_subclasses = 0;
sub _use_model_subclasses {
    # We follow a naming convention which allows us to dynamically list all sub-classes of model.
    # There is some flexibility loss by enforcing the naming convention, but the benefit is reflection.
    # A different config could make a different choice if necessary...
    
    unless ($use_model_subclasses) {
        require Genome::Model;
        my $path = $INC{'Genome/Model.pm'};
        unless ($path) {
            die "failed to find the path for Genome/Model.pm in %INC???";
        }
        $path =~ s/.pm\s*$// or die "no pm on $path?";
        unless (-d $path) {
            die "$path is not a directory?";
        }
        my @possible_subclass_modules = glob("$path/*.pm");
        for my $possible_module (@possible_subclass_modules) {
            my $class = $possible_module;
            $class =~ s/.pm$//;
            $class =~ s/\//\:\:/g;
            $class =~ s/^.*(Genome::Model::[^\:]+)/$1/;
            eval "use $class";
            die "Error using module $class ($possible_module): $@" if $@;
            unless ($class->isa("Genome::Model")) {
                next;
            }
            my $suffix = $class;
            $suffix =~ s/^Genome\::Model:://;
            #$model_subclass_names, $class;
        }
        $use_model_subclasses = 1;
    }
    return 1;
}

1;

=pod

=head1 NAME

Genome::Config - environmental configuration for the genome modeling tools

=head1 DESCRIPTION

The methods in this module are undergoing heavy refactoring and should be ignored until a later release.

=head1 AUTHORS

This software is developed by the analysis and engineering teams at 
The Genome Center at Washington Univiersity in St. Louis, with funding from 
the National Human Genome Research Institute.

=head1 LICENSE

This software is copyright Washington University in St. Louis.  It is released under
the Lesser GNU Public License (LGPL) version 3.  See the associated LICENSE file in
this distribution.

=head1 BUGS

For defects with any software in the genome namespace,
contact genome-dev@genome.wustl.edu.

=cut

