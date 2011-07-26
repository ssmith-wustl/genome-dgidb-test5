package Genome::Model::Tools::Maq::LsfBatchGatherMetrics;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Maq::LsfBatchGatherMetrics {
    is => 'Command',
    has => [
    snp_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "list of snps to gather metrics on",
    },
    ref_bfa =>
    {
        type => 'String',
        is_optional => 0,
        doc => "reference bfa used for mapfiles",
    },
    map_file_prefix =>
    {
        type => 'String',
        is_optional => 0,
        doc => 'Path and file prefix used to start all mapfile names to be found by the script',
    },
    'snpfilter_file' => {
        type => 'String',
        is_optional => 1,
        default => q{},
        doc => 'File of locations that passed Maq SNPFilter',
    },
    'output_file_prefix' => {
        type => 'String',
        is_optional => 0,
        doc => 'Path and file name prefix in which to write output',
    },
    'minq' => {
        type => 'Integer',
        is_optional => 1,
        doc => 'Minimum mapping quality of reads to be included in the counts',
    },
    'max_read' => {
        type => 'Integer',
        is_optional => 1,
        doc => 'Artifical read-length cutoff to calculate high quality sites',
    },
    'window_size' => {
        type => 'String',
        is_optional => 1,
        default => 2,
        doc => 'Number of bases on either side of each SNP to generate metrics for',
    },
    'long_read' => {
        type => 'Flag',
        is_optional => 1,
        default => 0,
        doc => 'Whether the map file was generated using a long reads version of maq (0.7 and up)',
    }

    ]
};


sub execute {
    my $self=shift;
    $DB::single = 1;
    
    my $bash_script = <<'CHR_TRANSLATE';
#!/gsc/bin/bash
if [ -z "$LSB_JOBINDEX" ] ; then
                if [ -n "$1" ] ; then
                                LSB_JOBINDEX=$1
                                export LSB_JOBINDEX
                else
                                LSB_JOBINDEX=1
                                export LSB_JOBINDEX
                fi
fi
echo $LSB_JOBINDEX
case $LSB_JOBINDEX in
                23)
                CHROMOSOME='X'
                export CHROMOSOME
                ;;
                24)
                CHROMOSOME='Y'
                export CHROMOSOME
                ;;
                *)
                CHROMOSOME=$LSB_JOBINDEX
                export CHROMOSOME
                ;;
esac
CHR_TRANSLATE

$bash_script .= sprintf('gmt maq create-experimental-metrics-file --ref-name ${CHROMOSOME} --location-file %s --output-file %s${CHROMOSOME}.csv --map-file %s${CHROMOSOME}.map --ref-bfa %s --snpfilter-file %s',$self->snp_file, $self->output_file_prefix, $self->map_file_prefix,$self->ref_bfa, $self->snpfilter_file ? $self->snpfilter_file : $self->snp_file);

#now add optional parameters
$bash_script .= sprintf " --minq %s", $self->minq if defined($self->minq);
$bash_script .= sprintf " --max-read %s", $self->max_read if defined($self->max_read);
$bash_script .= sprintf " --window-size %s", $self->window_size if defined($self->window_size);
$bash_script .= sprintf " --long-read %s", $self->long_read if defined($self->long_read);


#now we have all the files, send out the job
system(sprintf "bsub -N -u \${USER}\@watson.wustl.edu -R 'select[type==LINUX64]' -J '%s[1-24]' -oo 'stdout.\%\%I' -eo 'stderr.\%\%I' '$bash_script'",$self->output_file_prefix);

    return 1;
}


1;

sub help_brief {
    "Gathers Experimental Metrics on all chromosomes using per chromosome map files"
}

sub help_detail {
    <<'HELP';
    This script submits a job array of gmt create-experimental-metrics-file scripts. It expects the _prefix options to refer to directories and file prefixes for files of the form /path/to/submaps/prefixref-name.map. It will produce output files of conforming to this same pattern but with .csv extensions and using the output_file_prefix.
HELP
}
