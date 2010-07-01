#boberkfe: code should actually use some paths here rather than hardcoding stuff everywhere!
#eclark: Probably shouldn't contain complicated methods here either.  Just configuration (or configuration reading) logic.

package Genome::Config;

use strict;
use warnings;

use UR;

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
    qw/abrummet boberkfe eclark jeldred jlolofie ssmith apipe-run/;
}

# operating directories

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


=pod

=head1 NAME

Genome::Config - environmental configuration for the genome modeling tools

=head1 DESCRIPTION

This module currently just contains global, hard-coded paths.

For portability, it should use an instance of Genome::Config loadable from an environment variable.

=head1 METHODS

=head2 root_directory 

This is the directory under which all other data is symlinked.
It can be changed with the GENOME_MODEL_ROOT environment variable.

This value is typically constant for one site.  It changes only for testing.

=head2 data_directory 

This is the directory under which new data is actually placed.
It can be changed with the GENOME_MODEL_DATA environment variable.

This value changes over time, as disk fills, and new space is made for
new data.

=head2 model_data_directory

The default directory into which new models are placed.  Builds go into 
sub-directories here unless otherwise specified.

By default the $data_directory/model_data.

=head2 alignment_links_directory

All alignment linked under this directory.

By default the $root_directory/alignment_links.

=head2 alignment_data_directory

New alignment data is stored or under this directory.

By default the $data_directory/alignment_data.

=head2 comparison_links_directory

Cross-model comparisons are linked here.

By default $current_links_directory/model_comparisons.

=head2 comparison_data_directory

New cross-model comparisons are stored here.

By default $data_directory/model_comparisons.

=cut

1;

