package Genome::Model::Tools::SmrtAnalysis::Base;

use strict;
use warnings;

use Genome;

my $SEYMOUR_HOME = '/gscmnt/pacbio/production/smrtanalysis';
my $SH_SETUP = $SEYMOUR_HOME .'/etc/setup.sh';

my $DEFAULT_LSF_QUEUE = 'pacbio';
my $DEFAULT_LSF_RESOURCE = "-g /pacbio/smrtanalysis -M 4000000 -R 'select[type==LINUX64 && mem>=4000 && tmp>=40000] rusage[mem=4000,tmp=20000]'";

class Genome::Model::Tools::SmrtAnalysis::Base {
    is  => 'Command::V2',
    is_abstract => 1,
    has => [
        seymour_home => {
            is => 'Text',
            doc => 'The base directory for the SMRT Analysis install',
            is_optional => 1,
            default_value => Genome::Model::Tools::SmrtAnalysis::Base->default_seymour_home,
        },
        sh_setup => {
            is => 'Text',
            doc => 'The sh script that is sourced before running each command',
            is_optional => 1,
            default_value => $SH_SETUP,
        },
        analysis_bin => {
            is_calculated => 1,
            calculate_from => ['seymour_home',],
            calculate => q{ $seymour_home .'/analysis/bin'; },
        },
    ],
    has_optional_param => [
        lsf_queue => { default_value => $DEFAULT_LSF_QUEUE },
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
};

sub default_seymour_home {
    return $SEYMOUR_HOME;
}

sub shellcmd {
    my $self = shift;
    my %params = @_;
    #unless ($params{cmd}) {
    #    die('Failed to provide command in cmd param!');
    #}
    #my $cmd = delete($params{cmd});
    #TODO: Figure out how this will work from tcsh, csh, etc.
    #my $new_cmd = '. '. $self->sh_setup .' && '. $cmd;
    #$params{cmd} = $new_cmd;
    Genome::Sys->shellcmd(%params);
    return 1;
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    # TODO: Remove this once tests have been created and run successfully as any UNIX user
    # There are problems with sourcing the right setup.sh for environment variables necessary for running smrtanalyis software using the correct login shell(bash only)
    my $user = $ENV{USER};
    unless ($user eq 'smrtanalysis') {
        die('Currently running the SMRT Analysis package is limited to the smrtanalysis user!');
    }

    #TODO: Check for proper environment variables
    #my $setup = $self->sh_setup;
    $ENV{SEYMOUR_HOME} = $self->seymour_home;
    $ENV{SEYMOUR_JAVA_CP} = '';

    return $self;
}
