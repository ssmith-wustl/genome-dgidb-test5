package Genome::Model::Somatic::Command::RunOnBams; 

class Genome::Model::Somatic::Command::RunOnBams {
    is => 'Genome::Command::Base',
    has => [
        cmd     => { shell_args_position => 1, is => 'Text', doc => 'command to run per $model_id or @bams' },
        models  => { shell_args_position => 2, is => 'Genome::Model', is_many => 1 },
    ],
    doc => 'run a command on everything somatic model which has bams ready'
};

sub help_synopsis {
    return <<'EOS'
genome model somatic run-on-bams 'mytool -m $model_id -o /some/$model_id/ 'TCGA Nov 17 Marathon - bwa somatic' 

EOS
}

sub help_detail {
    return <<EOS

EOS
}

sub execute {
    my $self = shift;
    my @models = $self->models;
    $self->status_message("running on " . scalar(@models) . " models");
    
    my @model_ids = map { $_->id } @models;
    my @links = Genome::Model::Link->get(to_model_id => \@model_ids);
    my @builds = Genome::Model::Build->get(model_id => \@model_ids);

    for my $model (@models) {
        my @from = $model->from_models();
        if (@from == 0) {
            $self->warning_message("no underlying models?!? for " . $model->__display_name__);
            next;
        }
        if (@from == 1) {
            $self->warning_message("only one underlying models?!? for " . $model->__display_name__);
            next;
        } 
        if (@from > 2) {
            $self->warning_message("more than two underlying models?!? for " . $model->__display_name__);
            next;
        } 
        print $model->__display_name__ . " has:\n";
        my @bams;
        for my $refalign (@from) {
            my @builds = $refalign->builds("status ne" => "Abandoned");
            my $complete = $refalign->last_complete_build;
            my $last = $builds[-1];
            print "\t" . $from[0]->__display_name__ . " has :" . scalar(@builds) . " builds\n";
            for my $build (@builds) {
                print "\t\t" . $build->id . "\t" . $build->status . "\n";
            }
            my $best = $complete || $last;
            unless ($best) {
                print "\t\tNO BUILD\n";
                next;
            }
            my $dir = $best->data_directory;
            my @refalign_bams = glob("$dir/alignments/*rmdup.bam");
            unless (@refalign_bams) {
                print "\t\tNO BAM: " . $best->id . "\t" . $best->status . " : $dir\n";
                next;
            }
            if (@refalign_bams > 1) {
                print "\t\tMULTIPLE refalign_bams: " . $best->id . "\t" . $best->status . " : @refalign_bams\n";
            }
            
            print "\t\tBEST: " . $best->id . "\t" . $best->status . " : @refalign_bams\n";
            $ready++;
            push @bams, @refalign_bams;
        }

        if (@bams != 2) {
            print "\tNOT READY: $ready bams available\n";
            next;
        }
        
        my $model_id = $model->id;
        my $cmd = $self->cmd;
        my $cmd_translated = eval "no strict; no warnings; \"$cmd\";";
        Genome::Utility::FileSystem->shellcmd(cmd => $cmd_translated);
    }

    return 1;
}

1;

