package Genome::Model::Command::AddReads::MergeAlignments::Maq;

use strict;
use warnings;

use above "Genome";
use Command;
use File::Basename;
use Genome::Model;
use IO::File;


class Genome::Model::Command::AddReads::MergeAlignments::Maq {
    is => ['Genome::Model::Command::AddReads::MergeAlignments', 'Genome::Model::Command::MaqSubclasser'],
    has => [ 
        ref_seq_id   => { is => 'Integer', is_optional => 0, doc => 'the refseq on which to operate' },
    ]
};

sub help_brief {
    "Use maq to align reads";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads postprocess-alignments merge-alignments maq --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {                           
    return <<EOS 
This command is usually called as part of the add-reads process
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";

}

sub should_bsub { 1;}


sub execute {
    my $self = shift;

    $DB::single = 1;

    my $now = UR::Time->now;
    my $model = Genome::Model->get(id => $self->model_id);
    my $maplist_dir = $model->alignments_directory;
    unless (-e $maplist_dir) {
        unless (mkdir $maplist_dir) {
            $self->error_message("Failed to create directory '$maplist_dir':  $!");
        }
    } else {
        unless (-d $maplist_dir) {
            $self->error_message("File already exist for directory '$maplist_dir':  $!");
            return;
        }
    }
   
    
    my %library_alignments;

    if($model->id == 2667602812) {
        # This is the hack which allows the v0b AML nature tumor model to work with old map files.
        # Note that the database's c & d libraries were treated as a single library "c".
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308a'}}, glob('/gscmnt/sata182/info/medseq/aml1/submaps/amll1t71_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308b'}}, glob('/gscmnt/sata182/info/medseq/aml1/submaps/amll2t12_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308c'}}, glob('/gscmnt/sata182/info/medseq/aml1/submaps/amll3t15_chr' . $self->ref_seq_id . ".map");
    }
    elsif($model->id == '2667602813') {
        # This is the hack which allows the v0b AML nature skin model to work with old map files.
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308a'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/submaps/amlsking18_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308b'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin2/submaps/amll2skin10_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308c'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin3/submaps/amll3skin6_chr' . $self->ref_seq_id . ".map");
    }
    else {
        # Normal code to get the map files. 
        my @run_events = 
            grep { my $m = $_->metrics(name => 'read set pass fail'); (!$m or $m->value eq 'pass') }
            Genome::Model::Event->get(
                event_type => 'genome-model add-reads accept-reads maq',
                model_id => $model->id,
                event_status => 'Succeeded'
            );


        my @run_ids = map {$_->run_id} @run_events;
        my @runs = Genome::RunChunk->get(
                                         genome_model_run_id => \@run_ids,
                                     );
        my @seq_ids = map {$_->seq_id} @runs;

        my @rc = Genome::RunChunk->get(seq_id => \@seq_ids);

        # pre-cache the lanes
        my @sls = GSC::RunLaneSolexa->get(seq_id => \@seq_ids);
        
        for my $run_event (@run_events) {
            ## find the align-reads prior to this event, by model_id and run_id
            my $align_reads = Genome::Model::Command::AddReads::AlignReads::Maq->get(
                model_id   => $model->id,
                run_id     => $run_event->run_id,
                event_type => 'genome-model add-reads align-reads maq'
            );

            # new way
            my @map_files = $align_reads->alignment_file_paths;
            my $ref_seq_id = $self->ref_seq_id;
            @map_files = grep { basename($_) =~ /^$ref_seq_id\_/ } @map_files;

            my $run = Genome::RunChunk->is_loaded(
                                                  genome_model_run_id => $align_reads->run_id,
                                              );
            my $sls = GSC::RunLaneSolexa->is_loaded(
                                                    seq_id => $run,
                                                );
            my $library = $sls->library_name;
            push @{$library_alignments{$library}}, @map_files;
        }
    }    
    
    for my $library (keys %library_alignments) {
        my $library_maplist = $maplist_dir .'/' . $library . '_' . $self->ref_seq_id . '.maplist';
        my $fh = IO::File->new($library_maplist,'w');
        unless ($fh) {
            $self->error_message("Failed to create filehandle for '$library_maplist':  $!");
            return;
        }
        for my $input_alignment (@{$library_alignments{$library}}) {
            unless(-f $input_alignment) {
                $self->error_message("Expected $input_alignment not found");
                return
            }
            print $fh $input_alignment ."\n";
        }
        $fh->close;
    }

    # For efficiency, make all subsequent jobs in this path run on this machine.
    # This effectively moves the processing to the data, instead of the other way around.
    # Note that, if jobs fail, and are re-run later on other machine's they'll scp the
    # map files from /tmp -> /tmp and resume normally, just with a touch more overhead.
    my $next_event= Genome::Model::Event->get(prior_event_id=> $self->id);
    while($next_event) { 
        my $lsf_job_id = $next_event->lsf_job_id;
        if($lsf_job_id) {
            my $rv = system("bmod -m " .  $ENV{HOSTNAME} . " $lsf_job_id");
            if($rv && ($rv != 0)) {
                $self->error_message("unable to change host to " . $ENV{HOSTNAME} . " for job $lsf_job_id");
            }
        }
        $next_event= Genome::Model::Event->get(prior_event_id=> $next_event->id); 
    }
    
    $self->date_scheduled($now);
    $self->date_completed(UR::Time->now());
    $self->event_status('Succeeded');
    $self->event_type($self->command_name);
    $self->user_name($ENV{USER});

    return 1;
}

1;

