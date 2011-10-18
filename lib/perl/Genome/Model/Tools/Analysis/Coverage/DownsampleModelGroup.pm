package Genome::Model::Tools::Analysis::Coverage::DownsampleModelGroup;
use strict;
use warnings;
use FileHandle;
use Genome;

my %stats = ();

class Genome::Model::Tools::Analysis::Coverage::DownsampleModelGroup {
	is => 'Command',                       
	has => [
		group_id => {
                    is => 'Text',
                    doc => "ID of model group",
                    is_optional => 0
                },
		output_directory => {
                    is => 'Text',
                    doc => "Directory into which all results will be placed",
                    is_optional => 0
                },
        coverage_in_gb => {
            is => 'Text',
            doc => "Comma-delimited set to pass to downsampling script, in GB. 1.5 = 1,500,000,000 bases. Set this or ratio, not both.",
            is_optional => 1,
            is_input => 1,
        },
        coverage_ratio => {
            is => 'Text',
            doc => "Comma-delimited set to pass to downsampling script, units should be 0 to 1, where 1 = 100% = whole bam. Set this or gb, not both.",
            is_optional => 1,
            is_input => 1,
        },
        random_seed => {
            is => 'Text',
            doc => 'Set this equal to the reported random seed to reproduce previous results',
            is_optional => 1,
        },
        processing_profile_id => {
            is => 'Text',
            doc => 'Set this equal to the reported random seed to reproduce previous results',
            is_optional => 1,
            default => 2646038,
        },
        skip_if_output_present => {
            is => 'Text',
            doc => 'Skip if there is already a file in place. This allows later steps to be run without re-running earlier ones.',
            is_optional => 1,
            default => 0,
        },
        skip_pooled => {
            is => 'Text',
            doc => 'Most model groups have this flowcell sequencing stuff that isnt assigned to a particular sample. Skip those models from this process.',
            is_optional => 1,
            default => 1,
        },
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Downsample a refalign model group -- copies models over, downsamples the instrument data, puts the models in a model group, and runs that model group"
}

sub help_synopsis {
    return help_brief()."\nEXAMPLE: gmt analysis coverage downsample-model-group --group-id 16988 --output-directory /gscmnt/sata424/info/medseq/Freimer-Boehnke/Resample_Coverage/testmodel/ --coverage-ratio 0.25 --skip-if-output-present 1 --skip-pooled 1";
}

sub execute {
    my $self = shift;

    unless($self->coverage_in_gb xor $self->coverage_ratio){
        $self->error_message("You must either specify coverage_in_gb or coverage_ratio, not both.");
        die $self->error_message;
    }

    my $outdir = $self->output_directory;
    my $processing_profile_id = $self->processing_profile_id;
    my $skip_if_output_present = $self->skip_if_output_present;
    my $skip_pooled = $self->skip_pooled;

    my @data_levels;
    if ($self->coverage_in_gb) {
        @data_levels = split(/,/,$self->coverage_in_gb);
    }
    elsif ($self->coverage_ratio) {
        @data_levels = split(/,/,$self->coverage_ratio);
    }

    my @lsf_jobs;
    my @errorfiles;
    for my $model_bridge (Genome::ModelGroup->get($self->group_id)->model_bridges) {
        my $model = $model_bridge->model;
        my $subject_name = $model->subject_name;
        if ($skip_pooled && $subject_name =~ m/Pooled/) {next;}
        if ($model->last_succeeded_build_directory) {
            my $build = $model->last_succeeded_build;
            my $last_build_dir = $model->last_succeeded_build_directory;
            my %metrics = map {$_->name => $_->value} $build->metrics; 
            my $data_available = $metrics{"instrument data total kb"} / 10**6;
            printf("%s\t%0.01f\n",$build->id, $data_available);
            my $model_id = $build->model_id;

            my $last_lsf_job;
            for my $level (@data_levels) {
                my $out_file = "$outdir/$model_id.$level.out";
                my $error_file = "$outdir/$model_id.$level.err";
                if($level < $data_available || $self->coverage_ratio) {
                    push(@errorfiles,$error_file);
                    #bsub command
                    unless( -e "$error_file" && $skip_if_output_present) {
                        if(-e "$error_file") {
                            unlink($error_file);
                        }
                        if(-e "$out_file") {
                            unlink($out_file);
                        }

                        my $lsf_dependency="";
                        if($last_lsf_job) {
                            $lsf_dependency = "-w 'ended($last_lsf_job)' "
                        }
                        my $cmd; 
                        my $user = Genome::Sys->username;
                        if ($self->coverage_in_gb) {
                            $cmd = "bsub -N -u $user\@genome.wustl.edu $lsf_dependency-oo $out_file -eo $error_file -R 'select[mem>4000] rusage[mem=4000]'  genome model reference-alignment downsample $model_id --coverage-in-gb $level";
                        }
                        elsif ($self->coverage_ratio) {
                            $cmd = "bsub -N -u $user\@genome.wustl.edu $lsf_dependency-oo $out_file -eo $error_file -R 'select[mem>4000] rusage[mem=4000]'  genome model reference-alignment downsample $model_id --coverage-in-ratio $level";
                        }
                        my ($line) = `$cmd`;
                        my ($lsf_jobid) = $line =~ /<(\d+)>/;
                        $last_lsf_job = $lsf_jobid;
                        push(@lsf_jobs,$lsf_jobid);
                    }
                }
            }
        }
        UR::Context->commit() or die 'commit failed';
        UR::Context->clear_cache(dont_unload => ['Genome::ModelGroup', 'Genome::ModelGroupBridge']);
    }

    sleep 30;
    #dont progress until all above jobs have finished (done or not found)
    my $not_done = 1;
    foreach my $current_jobid (@lsf_jobs) {
        while ($not_done){
            my $job_info = `bjobs $current_jobid`;
            if ($job_info =~ m/DONE/i || $job_info =~ m/found/) {
                $not_done = 0;
            }
            else {
                sleep 60;
            }
        }
        $not_done = 1;
    }

#    my @files = glob("$outdir/*.err");

    my %downsampled_to;# = ( 0.5 => [], 0.75 => [], 1 => [], 1.5 => [], 2 => [], 3 => [] );
#    my %group_for;# = ( 0.5 => 16722, 0.75 => 16723, 1 => 16710, 1.5 => 16711, 2 => 16712, 3 => 16733 );
#    foreach my $level (sort @data_levels) {
#        $downsampled_to{$level} => [];
#        $group_for{$level} => $model_groups{$level}; #HAVE YET TO DEFINE MODEL GROUPS
#    }

    for my $file (@errorfiles) {
        my ($model_id,$downsample_level) = $file =~ /^$outdir\/+(\d+?)\.(\d*?\.*?\d*?)\.err$/;
        print "$model_id\t$downsample_level\t";

        my $fh = Genome::Sys->open_file_for_reading($file);

        my ($instrument_data_line) = grep /Your new instrument-data id is/, ($fh->getlines);

        my ($instrument_data_id) = $instrument_data_line =~ /(\d+)$/;

        #genome model copy 123456789 "name=Copy of my Awesome Model" processing_profile="use this processing profile instead" auto_build_alignments=0
        my $model = Genome::Model->get($model_id);
        my $model_name = $model->name;
        my $obj;
        if ($self->coverage_in_gb) {
            $obj = Genome::Model::Command::Copy->execute( model => $model, overrides => [ "name='${model_name}.downsampled-to-$downsample_level-Gbp'", "processing_profile=$processing_profile_id", "auto_build_alignments=0", "instrument_data=$instrument_data_id"] );
        }
        elsif ($self->coverage_ratio) {
            $obj = Genome::Model::Command::Copy->execute( model => $model, overrides => [ "name='${model_name}.downsampled-to-$downsample_level-ratio'", "processing_profile=$processing_profile_id", "auto_build_alignments=0", "instrument_data=$instrument_data_id"] );
        }
        unless($obj) {
            die "Unable to copy $model_name with instrument data $instrument_data_id\n";
        }
        my $new_id = $obj->_new_model->id;
        unless($new_id) {
            die "Unable to grab new model id\n";
        }
        print "$new_id\n";
        push @{$downsampled_to{$downsample_level}}, $new_id;
    }
    UR::Context->commit;

    #make model groups
    my %model_groups;
    my $model_group_name = Genome::ModelGroup->get($self->group_id)->name;
    foreach my $level (@data_levels) {
        my $model_list = join(",",@{$downsampled_to{$level}});
        my $new_model_group_name = "$model_group_name.downsampled_to_$level";
        my $cmd = "genome model-group create --name $new_model_group_name --models $model_list";
        my $result  = Genome::Sys->shellcmd( cmd => $cmd );
        unless($result){
            die $self->error_message("Unable to create modelgroup for downsampling level $level");
        }
        UR::Context->reload("Genome::ModelGroup",name => $new_model_group_name);
        my $final_model_group = Genome::ModelGroup->get(name => $new_model_group_name);
        my $final_model_group_id = $final_model_group->id;
        my $cmd2 = "perl -I /gsc/scripts/opt/genome/current/pipeline/lib/perl/ `which genome` model build start $final_model_group_id";
        my $result2  = Genome::Sys->shellcmd( cmd => $cmd2 );
        unless($result2){
            die $self->error_message("Unable to start builds on modelgroup for downsampling level $level");
        }


#        my $new_model_group_obj = Genome::ModelGroup->create(
#            name => "$model_group_name.downsampled_to_$level",
#            models => \@{$downsampled_to{$level}},
#        );
#        unless($new_model_group_obj) {
#            die $self->error_message("Unable to create modelgroup for downsampling level $level");
#        }
#        my $new_group_id = $new_model_group_obj->id;
#        my $new_model_group = Genome::ModelGroup->get(
#            id => "$new_group_id",
#        );
#        $new_model_group->assign_models(map { Genome::Model->get($_) } @{$downsampled_to{$level}});
    } 

    return 1;
}

sub byChrPos {
    my ($chr_a, $pos_a) = split(/\t/, $a);
    my ($chr_b, $pos_b) = split(/\t/, $b);

    $chr_a cmp $chr_b
        or
    $pos_a <=> $pos_b;
}

1;
