package Genome::Model::Tools::MetagenomicCompositionShotgun::ParallelRefCov;

use strict;
use warnings;
use Cwd;

use Genome;
use Workflow;

class Genome::Model::Tools::MetagenomicCompositionShotgun::ParallelRefCov {
    is  => ['Workflow::Operation::Command'],
    workflow => sub {
        my $rmapper = Workflow::Operation->create(
            name => 'parallel hmp-shotgun ref-cov',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::MetagenomicCompositionShotgun::RefCovTool')
        );
        $rmapper->parallel_by('regions_file');
        return $rmapper;
    },
    has_optional => [
        regions => {
            is => 'Number',
            doc => 'The number of regions to include in each instance. default_value=100000',
            default_value => 15000,
        },
        _final_file => {
            is => 'String',
            doc => 'The final output.',
            default_value => 10,
        },

        _output_basename => { },
    ],
};


sub pre_execute {
    my $self = shift;

    $self->status_message(">>>Running ParallelRefCov");
    $self->status_message("Report file:".$self->report_file);
    print("ParallelRefCov Report file:".$self->report_file);
    $self->_final_file($self->report_file);   
 
    #create a temp dir in the working directory
    my $tmp_dir = File::Temp::tempdir( DIR => $self->working_directory, CLEANUP => 1 );
    Genome::Sys->create_directory($self->working_directory."/reports");
  
    my $number_of_lines;
    my $split_val;
    my $line_count; 
    if ( defined($self->regions) ) { 
        $number_of_lines = $self->regions;
        $self->status_message("Using provided value.  Regions file split into: ".$number_of_lines);
    } else {
        my $regions_file = $self->regions_file;
        $line_count = `wc -l <$regions_file`;
        if ( !defined($line_count) ) {
            $number_of_lines = 50000;
            $self->status_message("Could not count number of lines in regions file. Defaulting to: ".$number_of_lines);
        } else { 
            $self->status_message("Number of lines counted in regions file: ".$line_count);
            $split_val = $line_count / 20;
            if ($split_val > 50000) {
                $number_of_lines = 50000;
                $self->status_message("Defaulting to: $number_of_lines"); 
            } elsif ($split_val < 1000) {
                $number_of_lines = 1000;
                $self->status_message("Defaulting to: $number_of_lines"); 
            } else {
                $number_of_lines = $split_val; 
                $self->status_message("Splitting with: $number_of_lines"); 
            }
        }
    } 


    my $current_dir = getcwd; 
    chdir($tmp_dir);
    my $prefix = "refcov-";
    my $cmd_split = "split -l ".$number_of_lines." ".$self->regions_file." $prefix"; 
    
    my $rv_split = Genome::Sys->shellcmd(
        cmd => $cmd_split,
        input_files => [$self->regions_file],
    );
    chdir($current_dir);

    unless ($rv_split) {
        die('Failed to execute split command');
    }
    my @split_file = <$tmp_dir/*>;  
    $self->regions_file(\@split_file);
    return 1;
}

sub post_execute {
    my $self = shift;
    my @files_to_unlink;

    $self->status_message(Data::Dumper->new([$self])->Dump);

    my @ref_cov_results = @{$self->report_file};
    #my $merged_refcov_file = $self->working_directory .'/reports/final_refcov_report.txt';
    my $merged_refcov_file = $self->_final_file;
    $self->report_file($merged_refcov_file);

    my $rv_cat = Genome::Sys->cat(input_files=>\@ref_cov_results,output_file=>$merged_refcov_file);
                if ($rv_cat != 1) {
                    $self->error_message("<<<Failed to merge ref cov files on cat.  Return value: $rv_cat");
                }
    push @files_to_unlink, @ref_cov_results;

    #REMOVE INTERMEDIATE FILES
    for my $file (@files_to_unlink) {
        unless (unlink $file) {
            $self->error_message('Failed to remove file '. $file .":  $!");
        }
        unless (unlink $file.".ok") {
            $self->error_message('Failed to remove file '. $file.".ok:  $!");
        }

    }

    return 1;
}

1;
