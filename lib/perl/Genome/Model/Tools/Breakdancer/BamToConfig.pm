package Genome::Model::Tools::Breakdancer::BamToConfig;

use strict;
use Genome;
use File::Basename;
use File::Path;

class Genome::Model::Tools::Breakdancer::BamToConfig {
    is  => 'Genome::Model::Tools::Breakdancer',
    has => [
        normal_bam => {
            is  => 'String',
            doc => 'input normal bam file',
            is_input => 1,
        },
        tumor_bam  => {
            is  => 'String',
            is_input => 1,
            doc => 'input tumor bam file',
        },
        params     => {
            is  => 'String',
            doc => 'bam2cfg parameters',
            default_value => '-g -h',
            is_input      => 1,
            is_optional   => 1,
        },
        output_file => {
            is  => 'String',
            doc => 'The output breakdancer config file',
            is_output => 1,
            is_input  => 1,
        },
    ],
};

sub help_brief {
    'Tool to create breakdancer config file';
}

sub help_detail {
    return <<EOS
    Tool to create breakdancer config file
EOS
}

sub execute {
    my $self = shift;

    my $out_file = $self->output_file;
    my $out_dir  = dirname $out_file;

    if (-s $out_file) {
        $self->status_message("breakdancer config file $out_file existing. Skip this step");
        return 1;
    }

    unless (-d $out_dir) {
        $self->warning_message("output dir $out_dir not existing. Now try to make it");
        File::Path::make_path($out_dir);
        die "Failed to make out_dir $out_dir\n" unless -d $out_dir;
    }

    unless (Genome::Sys->validate_file_for_writing($out_file)) {
        die "output file $out_file can not be written\n";
    }

    #my $cfg_cmd = $self->breakdancer_config_command; 
    my $cfg_cmd = '/gscuser/fdu/bin/bam2cfg.pl';
    $cfg_cmd .= ' ' . $self->params . ' ' . $self->tumor_bam . ' ' . $self->normal_bam . ' > '. $out_file;
    $self->status_message("Breakdancer command: $cfg_cmd");
=cut
    my $rv = Genome::Sys->shellcmd(
        cmd => $cfg_cmd,
        input_files  => [$self->tumor_bam, $self->normal_bam],
        output_files => [$self->output_file],
    );
=cut
    my $rv = system $cfg_cmd;
    print "rv is $rv\n";
    print "config file is\n$out_file\n";
=cut
    unless ($rv) {
        $self->error_message("Running breakdancer config failed using command: $cfg_cmd");
        die;
    }
=cut

    return 1;
}


1;

