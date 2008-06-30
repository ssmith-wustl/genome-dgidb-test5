package Genome::Model::Command::AddReads::AssignRun::454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use Genome::Model::Tools::Reads::454::SffInfo;
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
            fasta_file => {
                           is => 'string',
                           doc => "The path were the fasta file will be dumped",
                           calculate_from => ['read_set_directory','read_set'],
                           calculate => q|
                               return $read_set_directory .'/'. $read_set->subset_name .'.fna';
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

    unless (-d $model->data_parent_directory) {
        eval { mkpath $model->data_parent_directory };
        if ($@) {
            $self->error_message('Could not create read_set directory path '. $model->data_parent_directory .": $@");
            return;
        }
        unless(-d $model->data_parent_directory) {
            $self->error_message('Failed to create data parent directory: '. $model->data_parent_directory .": $!");
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
    my $sff_file = $self->sff_file;
    unless (-e $sff_file) {
        unless ($read_set->_run_region_454->dump_sff('filename' => $sff_file)) {
            $self->error_message("Could not dump sff file to $sff_file for read set ". $read_set->id);
            return;
        }
    }

    my $sffinfo_fasta = Genome::Model::Tools::Reads::454::SffInfo->create(
                                                                          sff_file => $sff_file,
                                                                          params => '-s',
                                                                          output_file => $self->fasta_file,
                                                                      );
    unless ($sffinfo_fasta->execute) {
        $self->error_message('Can not convert sff '. $sff_file .' to fasta '. $self->fasta_file);
        return;
    }

    my $sffinfo_qual = Genome::Model::Tools::Reads::454::SffInfo->create(
                                                                         sff_file => $sff_file,
                                                                         params => '-q',
                                                                         output_file => $self->qual_file,
                                                                );
    unless ($sffinfo_qual->execute) {
        $self->error_message('Can not convert sff '. $sff_file .' to fasta '. $self->qual_file);
        return;
    }

    return 1;
}

# old logic goes here and needs cleaning up
sub Xexecute {
    my $self = shift;
    $DB::single=1;
    Genome::Model->add_run_info( 
        run_number => $self->run,
        lanes => $self->lanes,
        bustard_path => $self->bustard_path,
        sample_path => $self->sample_path
    );
    # make path
    my $sample_path = $self->sample_path . '/runs/solexa/aml' . $self->run;
    mkpath $sample_path;
    my $base_dir = '/gscmnt/sata114/info/medseq/aml';
    # make symbolic link to path
    my $base_run_dir = $base_dir . '/aml' .$self->run;
    if (-e $base_run_dir) {
            $self->error_message("$base_run_dir already exists");
            return;
    }
    # make symbolic link to bustard
    my $bustard_dir = $self->bustard_path;
    if (-e "$sample_path/prb_src") {
            $self->error_message("$sample_path/prb_src already exists");
            return;
    }
    system("ln -s $sample_path $base_run_dir");
    system("ln -s $bustard_dir $sample_path/prb_src");
    return 1;
}
1;

