package Genome::Model::Command::Build::ReferenceAlignment::ScreenReads::EliminateAllDuplicates;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Date::Calc;
use File::stat;

use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::ScreenReads::EliminateAllDuplicates {
    is => 'Genome::Model::Event',
    has => [
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
        run_id => { is => 'Integer', is_optional => 0, doc => 'the genome_model_run on which to operate' },
    ],

};

sub help_brief {
    "Only pass along reads which have a unique sequence"
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads screen-reads eliminate-all-suplicates --model-id 5 --run-id 10
EOS
}

sub help_detail {                           
    return <<EOS 
Look at all the prior runs' fastq files and write a new fastq file for this run-id
containing only reads with sequences that do not exist in any prior run, and are
not duplicated in this run
EOS
}


sub execute {
    1;
}

# This functionality has been moved into the ConvertQualityAndDeduplicateReads PSE
sub _old_execute {
    my $self = shift;
    
sleep 120;

    my $model = Genome::Model->get(id => $self->model_id);
    my $model_id = $model->genome_model_id;

$DB::single = $DB::stopper;
    # This is in here because the catch_up_screen_reads script may have
    # done the work for us already.  Files smaller than 10k are probably broken anyway...
    my $test_screened_fastq_pathname = $self->sorted_screened_fastq_file_for_lane;
    if (-f $test_screened_fastq_pathname and (-s $test_screened_fastq_pathname > 10000)) {
        $self->status_message("screened file $$test_screened_fastq_pathname already exists, exiting!\n");
        return 1;
    }

    my $locked_resource_id = $model->genome_model_id;
    unless ($model->lock_resource(resource_id => $locked_resource_id)) {
        $self->error_message("Can't aquire lock for model id ".$model->genome_model_id);
        return;
    }

sleep 120;

    my $this_fastq_pathname = $self->sorted_fastq_file_for_lane;
    my $this_fastq = IO::File->new($this_fastq_pathname);

    # Find previously completed eliminate-all-duplicates steps
    # so we can look at their unique fastq files
    my $sql = "select * from GENOME_MODEL_EVENT event
               join GENOME_MODEL_EVENT next_event on next_event.model_id = event.model_id
                                  and next_event.run_id = event.run_id
                                  and next_event.event_type = 'genome-model add-reads screen-reads eliminate-all-duplicates'
               where event.event_type = 'genome-model add-reads assign-run solexa'
                 and next_event.date_completed is not null
                 and next_Event.event_status = 'Succeeded'
                 and event.model_id = $model_id
    ";


    my @events = Genome::Model::Event->get(sql => $sql);

    my @fastq_files = grep { $_ ne $this_fastq_pathname }
                      map { $_->sorted_screened_fastq_file_for_lane() }
                      @events;

    #my %handles = map { $_ => IO::File->new($_) } @fastq_files;
    my %handles;
    foreach my $file ( @fastq_files ) {
        my $fh = IO::File->new($file);
        unless ($fh) {
            $self->error_message("Can't open $file: $!");
            $model->unlock_resource(resource_id => $locked_resource_id);
            return;
        }
        $handles{$file} = $fh;
    }


    my $screened_fastq_pathname = $self->sorted_screened_fastq_file_for_lane;
    my $screened_fastq = IO::File->new(">$screened_fastq_pathname");
    unless($screened_fastq) {
        $self->error_message("Can't create $screened_fastq_pathname for writing: $!");
        $model->unlock_resource(resource_id => $locked_resource_id);
        return;
    }

    my %buffers;
    foreach my $fastq ( @fastq_files ) {
        $buffers{$fastq} = $self->_get_fastq_record($handles{$fastq});
    }

    my $last_sequence_seen = '';
    
    THIS_FASTQ_RECORD:
    while(my $this_record = $self->_get_fastq_record($this_fastq)) {
        if ($this_record->{'sequence'} eq $last_sequence_seen) {
            next;
        }

        my $keep = 1;
        foreach my $fastq ( @fastq_files ) {

            # fast forward to the first record that's less than our sequence
            OTHER_FASTQ_RECORDS:
            while ($buffers{$fastq} and ($this_record->{'sequence'} gt $buffers{$fastq}->{'sequence'})) {
                my $next_record = $self->_get_fastq_record($handles{$fastq});
                if ($next_record) {
                    $buffers{$fastq} = $next_record;
                } else {
                    # we're at the end of that file.  Don't check it any more
                    $handles{$fastq}->close();
                    last OTHER_FASTQ_RECORDS;
                }
            }

            if ($buffers{$fastq} and ($this_record->{'sequence'} eq $buffers{$fastq}->{'sequence'})) {
                $keep = 0;
                $last_sequence_seen = $this_record->{'sequence'};
                next THIS_FASTQ_RECORD;
            } 
        }

        if ($keep) {
            $screened_fastq->print( $this_record->{'read_name'} . "\n" .
                                    $this_record->{'sequence'} . "\n" .
                                    "+\n" .
                                    $this_record->{'quality'} . "\n");

            $last_sequence_seen = $this_record->{'sequence'};
        }
    }

    $screened_fastq->close();
    map { $_->close } values %handles;
    $this_fastq->close();

    $model->unlock_resource(resource_id => $locked_resource_id);
    return 1;
}


sub _get_fastq_record {
    my($self,$fh) = @_;

    my %node;
    my $read_name = $fh->getline;
    return unless $read_name;

    chomp($node{'read_name'} = $read_name);;

    chomp($node{'sequence'} = $fh->getline);
    $fh->getline;  # This should be the read name again, or just a '+'
    chomp($node{'quality'} = $fh->getline);

    return \%node;
}


1;

