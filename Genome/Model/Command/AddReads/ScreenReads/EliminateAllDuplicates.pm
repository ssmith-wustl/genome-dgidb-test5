package Genome::Model::Command::AddReads::ScreenReads::EliminateAllDuplicates;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;
use File::Path;
use Data::Dumper;
use Date::Calc;
use File::stat;

use IO::File;


use App::Lock;

class Genome::Model::Command::AddReads::ScreenReads::EliminateAllDuplicates {
    is => 'Genome::Model::Event',
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
    my $self = shift;
    
    my $model = Genome::Model->get(id => $self->model_id);

$DB::single=1;
    unless ($model->lock_resource(resource_id => $model->genome_model_id)) {
        $self->error_message("Can't aquire lock for model id ".$model->genome_model_id);
        return;
    }

    my $sql = "select * from GENOME_MODEL_EVENT event
               join GENOME_MODEL_EVENT next_event on next_event.model_id = event.model_id
                                  and next_event.run_id = event.run_id
                                  and next_event.event_type = 'genome-model add-reads screen-reads eliminate-all-duplicates'
               where event.event_type = 'genome-model add-reads assign-run solexa'
                 and next_event.event_status is not null
                 and next_Event.event_status = 'Succeeded'
    ";



    my @events = Genome::Model::Event->get(sql => $sql);

    my @fastq_files = map { $_->sorted_screened_fastq_file_for_lane() } @events;

    my %handles = map { $_ => IO::File->new($_) } @fastq_files;

    my $this_fastq = IO::File->new($self->sorted_fastq_file_for_lane);

    my $screened_fastq_pathname = $self->sorted_screened_fastq_file_for_lane;
    my $screened_fastq = IO::File->new(">$screened_fastq_pathname");
    unless($screened_fastq) {
        $self->error_message("Can't create $screened_fastq_pathname for writing: $!");
        return;
    }

    my %buffers;
    foreach my $fastq ( @fastq_files ) {
        $buffers{$fastq} = $self->_get_fastq_record($handles{$fastq});
    }

    my $last_sequence_seen = '';
    while(my $this_record = $self->_get_fastq_record($this_fastq)) {
        if ($this_record->{'sequence'} eq $last_sequence_seen) {
            next;
        }

        my $keep = 1;
        foreach my $fastq ( @fastq_files ) {

            # fast forward to the first record that's less than our sequence
            while ($this_record->{'sequence'} gt $buffers{$fastq}->{'sequence'}) {
                $buffers{$fastq} = $self->_get_fastq_record($handles{$fastq});
                unless (defined ($buffers{$fastq})) {
                    # we're at the end of that file.  Don't check it any more
                    $handles{$fastq}->close();
                    delete $buffers{$fastq};
                }
            }

            if ($this_record->{'sequence'} eq $buffers{$fastq}->{'sequence'}) {
                $keep = 0;
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

    return 1;
}


sub _get_fastq_record {
    my($self,$fh) = @_;

    my %node;
    chomp($node{'read_name'} = $fh->getline);
    return unless $node{'read_name'};


    chomp($node{'sequence'} = $fh->getline);
    $fh->getline;  # This should be the read name again
    chomp($node{'quality'} = $fh->getline);

    return \%node;
}


1;

