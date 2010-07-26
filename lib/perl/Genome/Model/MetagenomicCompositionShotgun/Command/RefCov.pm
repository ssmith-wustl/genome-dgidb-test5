package Genome::Model::MetagenomicCompositionShotgun::Command::RefCov;

use strict;
use warnings;
use Genome;
use Genome::Model::InstrumentDataAssignment;
use File::Path;
use File::Find;

class Genome::Model::MetagenomicCompositionShotgun::Command::RefCov{
    is => 'Genome::Command::OO',
    has_input => [
        build => {
            is => 'Genome::Model::Build::MetagenomicCompositionShotgun', 
            id_by => ['build_id'],
            shell_args_position => 1,
            doc => 'the model/build for which to generate reference coverage'
        },
        #_log_path => {
        #    is_transient => 1,
        #    is => 'Text',
        #},
    ],
    doc => 'generate refcov for the metagenomic reference alignments',
};

my $base_output_dir = "/gscmnt/sata881/research/mmitreva/adukes";

sub execute {
    my ($self) = @_;
    local $|=1;

    my $build = $self->build;
    my $model = $build->model;
    my $dir = $build->data_directory;
    my $report_path = $dir . '/refcov/';

    # temp code to redirect to dir outside of the build for now
    my $sample_name = $model->subject_name;
    my ($hmp, $patient, $site) = split(/-/, $sample_name);
    $patient = $hmp . '-' . $patient;
    my $build_id = $build->id;
    my $output_dir = $base_output_dir . "/" . $patient . "/" . $site . "/" . $build_id;
    mkpath $output_dir unless -d $output_dir;
    $report_path = $output_dir;
    
    $self->_log_path($report_path . '/log');
    $self->_log("RefCov path: " . $report_path);
    
    my ($contamination_bam, $contamination_flagstat, $meta1_bam, $meta1_flagstat, $meta2_bam, $meta2_flagstat) = map{ $dir ."/$_"}(
        "contamination_screen.bam",
        "contamination_screen.bam.flagstat",
        "metagenomic_alignment1.bam",
        "metagenomic_alignment1.bam.flagstat",
        "metagenomic_alignment2.bam",
        "metagenomic_alignment2.bam.flagstat",
    );

    $self->_log('Model: ' . $model->name);
    $self->_log('Build: ' . $build->id);
    $self->_log('RefCov Data: ' . $report_path . '/data');
}

sub _log {
	my $self = shift;
    my $str = shift;
    my @time_data = localtime(time);

    $time_data[1] = '0' . $time_data[1] if (length($time_data[1]) == 1);
    $time_data[2] = '0' . $time_data[2] if (length($time_data[2]) == 1);

    my $time = join(":", @time_data[2, 1]);

    print STDERR $time . " - $str\n";
	my $log_fh = IO::File->new('>>' . $self->_log_path);
	print $log_fh $time . " - $str\n";
}


1;

