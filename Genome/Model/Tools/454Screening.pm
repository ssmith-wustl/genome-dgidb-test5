package Genome::Model::Tools::454Screening;

use strict;
use warnings;

use Genome;
use Command;
use Workflow::Simple;
use Data::Dumper;


UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
            input_file => 
            {
                           doc => 'file of reads to be checked for contamination',
                           is => 'String',
                           is_input => 1,
            },
            filter_list => 
            {
                           doc => 'file of id\'s produced from screening, to remove from original fasta',
                           is => 'String',
                           is_input => 1,
                           is_optional => 1,
            },
            filtered_file => 
            {
                           doc => 'fasta file produced after running crossmatch, by screening id\'s from filter_list',
                           is => 'String',
                           is_input => 1,
                           is_optional => 1,
            },
            deduplicated_file => 
            {
                           doc => 'fasta file produced after deduplication',
                           is => 'String',
                           is_input => 1,
                           is_optional => 1,
            },
            database =>     
            {
                           doc => 'alignment database', 
                           is => 'String',
                           is_input => 1,
            },
            percent => 
            {
                           doc => 'percent identity of alignment',
                           is => 'Number',
                           is_input => 1,
                           default => 90,
            },
            query_length => 
            {
                           doc => 'length of query side of alignment',
                           is => 'Number',
                           is_input => 1, 
                           default => 50,
            },
            chunk_size  => 
            { 
                           doc => 'number of sequences per output file', 
                           is => 'SCALAR', 
                           default => 5000,
            },  
            tmp_dir     => 
            { 
                          doc => 'directory for saving temporary file chunks', 
                          is => 'SCALAR', 
                          default => Genome::Utility::FileSystem->create_temp_directory,
            }, 
            delete_derivatives => 
            {
                          doc => 'delete any files derived from items in original list',
                          is => 'Boolean',
                          is_optional => 1,
                          default => 0,
            },
            force_overwrite => 
            {
                         doc         => 'overwrite merged file if exists',
                         is          => 'Integer',
                         is_input    => 1,
                         default     => 0,
            },
            filter_only =>
            {
                         doc         => 'Run filter on original fasta and deduplicate, or just stop after crossmatch',
                         is          => 'Boolean',
                         is_input    => 1,
                         default     => 0,
            },
            job_suffix =>
            {
                         doc         => 'Suffix to append to each job name run by the workflow',
                         is          => 'String',
                         is_input    => 1,
                         is_optional => 1
            },
            workflow_log_dir =>
            {
                         doc         => 'override the location of logging',
                         is          => 'String',
                         is_input    => 1,
                         is_optional => 1
            },
    ]
);

sub help_brief
{
    "Runs Hmp 454 contamination screening workflow";
}

sub help_synopsis
{
    return <<"EOS"
    genome-model tools human 454 screening... 
EOS
}

sub help_detail
{
    return <<"EOS"
    Runs the HMP 454 screening pipeline.  Takes input file and database, with optional params  
EOS
}

sub execute
{
    my $self = shift;
    my ($input_file, $database, $percent, $query_length, $chunk_size, $tmp_dir, $delete_derivatives, $force_overwrite) = 
       ($self->input_file, $self->database, $self->percent, $self->query_length, $self->chunk_size, $self->tmp_dir, $self->delete_derivatives, $self->force_overwrite);
    my $filter_list = $self->filter_list ? $self->filter_list : $input_file . "_FILTER_LIST.txt";

    unless ($self->filter_only)
    {
        my $filtered_file = $self->filtered_file ? $self->filtered_file : $input_file . "FILTERED.fasta";
        my $deduplicated_file = $self->deduplicated_file ? $self->deduplicated_file : $input_file . "DEDUP.fasta";

        my $workflow_object = $self->load_workflow_apply_suffix('/gsc/var/cache/testsuite/data/Genome-Model-Tools-454Screening/crossmatch_wrapper.xml');
        
        $workflow_object->log_dir = $self->workflow_log_dir if ($self->workflow_log_dir);

        my $output = run_workflow_lsf(
                              $workflow_object,
                              'input_file'          => $input_file,
                              'filter_list'         => $filter_list,
                              'filtered_file'       => $filtered_file,
                              'deduplicated_file'   => $deduplicated_file,
                              'database'            => $database,
                              'percent'             => $percent,
                              'query_length'        => $query_length,
                              'chunk_size'          => $chunk_size, 
                              'tmp_dir'             => $tmp_dir, 
                              'force_overwrite'     => $force_overwrite,
                              'delete_derivatives'  => $delete_derivatives,
                          );
    }
    else
    {

        my $workflow_object = $self->load_workflow_apply_suffix('/gsc/var/cache/testsuite/data/Genome-Model-Tools-454Screening/crossmatch_screen.xml');

        $workflow_object->log_dir($self->workflow_log_dir) if ($self->workflow_log_dir);

        my $output = run_workflow_lsf(
                              $workflow_object,
                              'input_file'          => $input_file,
                              'filter_list'         => $filter_list,
                              'database'            => $database,
                              'percent'             => $percent,
                              'query_length'        => $query_length,
                              'chunk_size'          => $chunk_size, 
                              'tmp_dir'             => $tmp_dir, 
                              'force_overwrite'     => $force_overwrite,
                              'delete_derivatives'  => $delete_derivatives,
                          );
    }
    return 1;
}

sub load_workflow_apply_suffix {
    my ($self, $workflow_xml) = @_;

    my $w = Workflow::Operation->create_from_xml($workflow_xml);
    $self->_apply_suffix($w) if (defined $self->job_suffix);

    return $w;
}

sub _apply_suffix {
    my ($self, $w) = @_;

    $w->name($w->name . '_' . $self->job_suffix)
        unless($w->name eq 'input connector' || $w->name eq 'output connector');

    if ($w->can('operations')) {
        foreach my $op ($w->operations) {
            $self->_apply_suffix($op);
        }
    }
}

