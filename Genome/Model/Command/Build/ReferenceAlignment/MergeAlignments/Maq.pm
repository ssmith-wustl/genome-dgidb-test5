package Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Maq;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use IO::File;


class Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments::Maq {
    is => ['Genome::Model::Command::Build::ReferenceAlignment::MergeAlignments', 'Genome::Model::Command::MaqSubclasser'],
    has => [ ],
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
    return "-R 'select[model==Intel_Xeon360] span[hosts=1]'";
}

sub execute {
    my $self = shift;

$DB::single=1;
    $DB::single = $DB::stopper;

    my $now = UR::Time->now;
    my $model = $self->model; 
    my $maplist_dir = $model->accumulated_alignments_directory;
    unless (-e $maplist_dir) {
        unless (mkdir $maplist_dir) {
            #doesn't exist can't create it...quit
            $self->error_message("Failed to create directory '$maplist_dir':  $!");
            return;
        }
        chmod 02775, $maplist_dir;
    } else {
        unless (-d $maplist_dir) {
            #does exist, but is a file, not a directory? quit.
            $self->error_message("File already exists for directory '$maplist_dir':  $!");
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
    if($model->id == 2684264955) {
        # This is the hack which allows the v0c AML nature tumor model to work with old map files after start site deduplication.
        # Note that the database's c & d libraries were treated as a single library "c".
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308a'}}, glob('/gscmnt/sata182/info/medseq/aml1/ssdedup2/amll1t71_chr' . $self->ref_seq_id . ".map.keep");
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308b'}}, glob('/gscmnt/sata182/info/medseq/aml1/ssdedup2/amll2t12_chr' . $self->ref_seq_id . ".map.keep");
        push @{$library_alignments{'H_GV-933124G-tumor1-9043g-031308c'}}, glob('/gscmnt/sata182/info/medseq/aml1/ssdedup2/amll3t15_chr' . $self->ref_seq_id . ".map.keep");
    }
    elsif($model->id == 2667602813) {
        # This is the hack which allows the v0b AML nature skin model to work with old map files.
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308a'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin/submaps/amlsking18_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308b'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin2/submaps/amll2skin10_chr' . $self->ref_seq_id . ".map");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308c'}}, glob('/gscmnt/sata183/info/medseq/kchen/Hs_build36/maq6/analysis_skin3/submaps/amll3skin6_chr' . $self->ref_seq_id . ".map");
    }
    elsif($model->id == 2684267448) {
        # This is the hack which allows the v0b AML nature skin model to work with old map files after start site deduplication.
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308a'}}, glob('/gscmnt/sata203/info/medseq/aml_tmp/v0_skin_dedup_maps/amlsking18_chr' . $self->ref_seq_id . ".map.keep");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308b'}}, glob('/gscmnt/sata203/info/medseq/aml_tmp/v0_skin_dedup_maps/amll2skin10_chr' . $self->ref_seq_id . ".map.keep");
        push @{$library_alignments{'H_GV-933124G-skin1-9017g-031308c'}}, glob('/gscmnt/sata203/info/medseq/aml_tmp/v0_skin_dedup_maps/amll3skin6_chr' . $self->ref_seq_id . ".map.keep");
    }
    else {
        # Normal code to get the map files. 
        my @read_sets = $model->read_sets;
        unless(@read_sets) {
            $self->error_message("Model: " . $model->id .  " has no read sets?");
            return;
        }
        # pre-cache the data we'll grab individually below
        my @read_set_ids = map {$_->read_set_id} @read_sets;
        my @rc = $model->run_chunks;
        my @sls = GSC::RunLaneSolexa->get(seq_id => \@read_set_ids);
        
        my $align_dist_threshold = $model->align_dist_threshold;
        if ($align_dist_threshold) {
            $self->status_message("alignment distribution threshold is set to $align_dist_threshold");
        }
        else {
            $self->status_message("no alignment distribution threshold is set.  accepting all read sets");
        }
        
        my @missing_maps;
        my @found_maps;
$DB::single=1;
        for my $read_set_link (@read_sets) {
            unless(defined $read_set_link->first_build_id) {
                $read_set_link->first_build_id($self->parent_event_id);
            }
            
            my $read_set = $read_set_link->read_set;
            my $library = $read_set->library_name;
            my $read_set_desc = $read_set->full_name . ' (library ' . $library . ')';

            #if ($align_dist_threshold) {
            #    my $evenness_metric = $align_reads->metric(name => 'evenness');
            #     if ($evenness_metric) {
            #      my $evenness = $evenness_metric->value;
            #     if ($evenness < $align_dist_threshold) {
            #          $self->warning_message("SKIPPING read set $read_set_desc which has evenness $evenness");
            #       }
            #  else {
            #      $self->status_message("ADDING read set $read_set_desc with evenness $evenness");
            #      }
            #       }
            #   else {
            #   $self->warning_message("no evenness metric on read set $read_set_desc");
            #    $self->status_message("ADDING read set $read_set_desc");
            #           }
            #        }
            
            my @map_files = $read_set_link->read_set_alignment_files_for_refseq($self->ref_seq_id);
            unless (@map_files) {
                #$DB::single = 1;
                @map_files = $read_set_link->read_set_alignment_files_for_refseq($self->ref_seq_id);
                my $msg = 
                    "Failed to find map files for read set "
                    . $read_set_link->read_set_id
                    . "(" . $read_set->full_name . ")";
                     $self->error_message($msg);
                push @missing_maps, $msg;
            }
            $self->status_message("Found map files:\n" . join("\n\t",@map_files));
            
            push @{$library_alignments{$library}}, @map_files;
        }
        if (@missing_maps) {
            $self->error_message(join("\n",@missing_maps));
            #$self->error_message("Looked in directory: $maplist_dir);
            $self->error_message("Map files are missing!");
            return; 
        }
    }
    
    for my $library (keys %library_alignments) {
        my $library_maplist = $maplist_dir .'/' . $library . '_' . $self->ref_seq_id . '.maplist';
        my $fh = IO::File->new($library_maplist,'w');
        unless ($fh) {
            $self->error_message("Failed to create filehandle for '$library_maplist':  $!");
            return;
        }
        my $cnt=0;
        for my $input_alignment (@{$library_alignments{$library}}) {
            unless(-f $input_alignment) {
                $self->error_message("Expected $input_alignment not found");
                return
            }
            print $fh $input_alignment ."\n";
        }
        $self->status_message("library $library has $cnt map files");
        $fh->close;
    }

    # For efficiency, make all subsequent jobs in this path run on this machine.
    # This effectively moves the processing to the data, instead of the other way around.
    # Note that, if jobs fail, and are re-run later on other machine's they'll scp the
    # map files from /tmp -> /tmp and resume normally, just with a touch more overhead.
    #my $next_event= Genome::Model::Event->get(prior_event_id=> $self->id);
    #while($next_event) { 
    #    my $lsf_job_id = $next_event->lsf_job_id;
    #    if($lsf_job_id) {
    #        my $rv = system("bmod -m " .  $ENV{HOSTNAME} . " $lsf_job_id");
    #        if($rv && ($rv != 0)) {
    #            $self->error_message("unable to change host to " . $ENV{HOSTNAME} . " for job $lsf_job_id");
    #        }
    #    }
    #    $next_event= Genome::Model::Event->get(prior_event_id=> $next_event->id); 
    #}
    
    $self->date_scheduled($now);
    $self->date_completed(UR::Time->now());
    $self->event_status('Succeeded');
    $self->event_type($self->command_name);
    $self->user_name($ENV{USER});

    return 1;
}

1;

