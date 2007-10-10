package Genome::Model::Command::PostprocessAlignments::MergeAlignments::Maq;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model;
use File::Path;
use File::Basename;
use Data::Dumper;
use Date::Calc;
use File::stat;

use App::Lock;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
);

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads maq --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);
    my $model_data_directory = $model->data_directory;


    my $lanes;
    
    $DB::single = 1;
    
    my @input_alignments = glob($model->data_directory . "/alignments_to_merge_*.map");
    
    my @successfully_locked_inputs;
    
    foreach my $path (@input_alignments) {
        my ($bn) = fileparse($path);
        if ($model->lock_resource(resource_id=>$bn, block_sleep=>1, max_try=>1)) {
            push @successfully_locked_inputs, $path;
        }
    }
    
    my $accumulated_alignments_filename = $model_data_directory . "/alignments";
  
    my $accum_tmp = $accumulated_alignments_filename . "." . $$;

    unless ($model->lock_resource(resource_id=>'alignments')) {
        $self->error_message("Can't get lock for master accumulated alignment");
        return undef;
    }
    
    # the master alignment file that we're merging into is an input, too!
    
    if (-e $accumulated_alignments_filename) {
        unshift @successfully_locked_inputs, $accumulated_alignments_filename;
    }

    my $cmdline = "maq mapmerge $accum_tmp " . join(' ', @successfully_locked_inputs);
    my $rv = system($cmdline);
    if ($rv) {
        $self->error_message("exit code from maq merge was nonzero; something went wrong.  command line was $cmdline");
        return;
    }
    
    rename($accum_tmp, $accumulated_alignments_filename);
         
    unlink foreach @successfully_locked_inputs;
        
    return 1;
}

1;

