package Genome::Model::Command::AddReads::AssignRun::454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Tools::454::SffInfo;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::AddReads::AssignRun::454 {
    is => 'Genome::Model::Command::AddReads::AssignRun',
    has => [ 
            model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
            sff_file => {
                         is => 'string',
                         doc => 'The path were the sff file will be dumped',
                         calculate_from => ['read_set_directory','read_set'],
                         calculate => q|
                           return $read_set_directory .'/'. $read_set->subset_name .'.sff';
                       |,
                     },
            _sff_path => {
                          calculate_from => ['read_set'],
                          calculate => q|
                              return $read_set->full_path . $read_set->subset_name .'.sff';
                          |,
                      },
            fasta_file => {
                           is => 'string',
                           doc => "The path were the fasta file will be dumped",
                           calculate_from => ['read_set_directory','read_set'],
                           calculate => q|
                               return $read_set_directory .'/'. $read_set->subset_name .'.fna';
                           |,
                       },
            _fasta_path => {
                            calculate_from => ['read_set'],
                            calculate => q|
                                return $read_set->full_path . $read_set->subset_name .'.fna';
                            |,
                        },
            qual_file => {
                          is => 'string',
                          doc => "The path were the quality file will be dumped",
                          calculate_from => ['read_set_directory','read_set'],
                          calculate => q|
                               return $read_set_directory .'/'. $read_set->subset_name .'.qual';
                           |,
                      },
            _qual_path => {
                           calculate_from => ['read_set'],
                           calculate => q|
                                return $read_set->full_path . $read_set->subset_name .'.qual';
                            |,
                       },
    ]
};

sub help_brief {
    "Creates the appropriate items on the filesystem for a new 454 run region"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run 454 --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<EOS 
    This command is launched automatically by "add-reads assign-run"
    when it is determined that the run is from a 454.
EOS
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $read_set = $self->read_set;

    unless ($read_set) {
        $self->error_message("Did not find read_set info for seq_id ". $self->seq_id);
        return;
    }

    unless (-d $model->model_links_directory) {
        eval { mkpath $model->model_links_directory };
        if ($@) {
            $self->error_message('Could not create read_set directory path '. $model->model_links_directory .": $@");
            return;
        }
        unless(-d $model->model_links_directory) {
            $self->error_message('Failed to create data parent directory: '. $model->model_links_directory .": $!");
            return;
        }
    }

    my $read_set_dir = $self->read_set_directory;
    unless (-d $read_set_dir) {
        eval { mkpath($read_set_dir) };
        if ($@) {
            $self->error_message("Couldn't create read_set directory path $read_set_dir: $@");
            return;
        }
    }

    # Create the sample_data directory for this run and seq_id if it doesn't already exist
    my $sample_data_dir = $self->read_set->full_path;
    unless (-d $sample_data_dir) {
        eval { mkpath($sample_data_dir) };
        if ($@) {
            $self->error_message("Couldn't create sample_data directory path $sample_data_dir: $@");
            return;
        }
    }

    # Dump the sff file(if it doesn't already exist)
    unless (-s $self->_sff_path) {
        unless ($read_set->_run_region_454->dump_sff('filename' => $self->_sff_path)) {
            $self->error_message('Could not dump sff file to '.  $self->_sff_path
                                 .' for read set '. $read_set->id);
            return;
        }
    }
    # the sample_data is not in the correct location for it to be used by other models
    if (-e $self->sff_file) {
        $self->error_message('sff file already exists under model_data '. $self->sff_file);
        return;
    }
    # symlink the sample_data to the model_data
    unless(symlink($self->_sff_path,$self->sff_file)) {
        $self->error_message('Failed to create symlink '. $self->sff_file
                             .' => '. $self->_sff_path);
        return;
    }

    # Create the fasta file from the sff file (if it doesn't already exist)
    unless (-s $self->_fasta_path) {
        my $sffinfo_fasta = Genome::Model::Tools::454::SffInfo->create(
                                                                       sff_file => $self->_sff_path,
                                                                       params => '-s',
                                                                       output_file => $self->_fasta_path,
                                                                   );
        unless ($sffinfo_fasta->execute) {
            $self->error_message('Can not convert sff '. $self->_sff_path .' to fasta '. $self->_fasta_path);
            return;
        }
    }
    # the sample_data is not in the correct location for it to be used by other models
    if (-e $self->fasta_file) {
        $self->error_message('fasta file already exists under model_data '. $self->fasta_file);
        return;
    }
    # symlink the sample_data to the model_data
    unless(symlink($self->_fasta_path,$self->fasta_file)) {
        $self->error_message('Failed to create symlink '. $self->fasta_file
                             .' => '. $self->_fasta_path);
        return;
    }


    # Create the quality file from the sff file (if it doesn't already exist)
    unless (-s $self->_qual_path) {
        my $sffinfo_qual = Genome::Model::Tools::454::SffInfo->create(
                                                                      sff_file => $self->_sff_path,
                                                                      params => '-q',
                                                                      output_file => $self->_qual_path,
                                                                  );
        unless ($sffinfo_qual->execute) {
            $self->error_message('Can not convert sff '. $self->_sff_path .' to quality '. $self->_qual_path);
            return;
        }
    }
    # the sample_data is not in the correct location for it to be used by other models
    if (-e $self->qual_file) {
        $self->error_message('qual file already exists under model_data '. $self->qual_file);
        return;
    }
    # symlink the sample_data to the model_data
    unless(symlink($self->_qual_path,$self->qual_file)) {
        $self->error_message('Failed to create symlink '. $self->qual_file
                             .' => '. $self->_qual_path);
        return;
    }

    return 1;
}


1;

