package Genome::Model::Command::AddReads::AssignRun::Solexa;

use strict;
use warnings;

use above "Genome";
use File::Path;
use GSC;

use GDBM_File;
use File::Temp;

use IO::File;

class Genome::Model::Command::AddReads::AssignRun::Solexa {
    is => 'Genome::Model::Event',
    has => [ 
        model_id   => { is => 'Integer', is_optional => 0, doc => 'the genome model on which to operate' },
    ]
};

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads assign-run solexa --model-id 5 --run-id 10
EOS
}

sub help_brief {
    "Creates the appropriate items on the filesystem for a new Solexa run"
}

sub help_detail {                           
    return <<EOS 
This command is normally run automatically as part of "add-reads assign-run"
when it is determined that the run is from Solexa.  
EOS
}

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";

}


sub execute {
    my $self = shift;

    $DB::single=1;

    my $model = Genome::Model->get(id => $self->model_id);

    my $run = Genome::RunChunk->get(id => $self->run_id);
    unless ($run) {
        $self->error_message("Did not find run info for run_id " . $self->run_id);
        return 0;
    }

    unless (-d $model->data_parent_directory) {
        eval { mkpath $model->data_parent_directory };
				if ($@) {
					$self->error_message("Couldn't create run directory path $model->data_parent_directory: $@");
					return;
				}
        unless(-d $model->data_parent_directory) {
            $self->error_message("Failed to create data parent directory: ".$model->data_parent_directory. ": $!");
            return;
        }
    }

    my $run_dir = $self->resolve_run_directory;
    unless (-d $run_dir) {
        eval { mkpath($run_dir) };
        if ($@) {
            $self->error_message("Couldn't create run directory path $run_dir: $@");
            return;
        }
    }

    # Convert the original solexa sequence files into maq-usable files
    my $lanes = $self->run->limit_regions;
    unless ($lanes) {
        $lanes = '12345678';
        $self->run->limit_regions($lanes);
    }

    my $gerald_dir = $self->run->full_path;
    my @geraldfiles = glob($gerald_dir . '/s_[' . $lanes . ']_sequence.txt*');
    foreach my $seqfile (@geraldfiles) {

        my($lane) = ($seqfile =~ m/s_(\d+)_sequence.txt/);

        # convert quality values
        my $fastq_file = $self->fastq_file_for_lane();
        system("maq sol2sanger $seqfile $fastq_file");

        ## Convert the reads to the binary fastq format
        ## We're doing this in align-reads now
        #my $bfq_file = $self->bfq_file_for_lane();
        #system("maq fastq2bfq $fastq_file $bfq_file");

        # We also need a sorted/indexed fastq file 
        unless ($self->_make_sorted_fastq_and_index_file()) {
            return;
        }

    }

    

    return 1;
}


sub _make_sorted_fastq_and_index_file {
    my($self) = @_;

    my $fastq_file = $self->fastq_file_for_lane();
    my $fastq = IO::File->new($fastq_file);
    unless ($fastq) {
        $self->error_message("can't open $fastq_file: $!");
        return;
    }

    my $presorted_pathname = $fastq_file . ".presorted";
    my $presorted = IO::File->new(">$presorted_pathname");
    unless ($presorted) {
        $self->error_message("Can't open $presorted_pathname for writing: $!");
        return;
    }

    my $postsorted_pathname = $fastq_file . ".postsorted";

    while(1) {
        my $read_name = $fastq->getline;
        last unless $read_name;
        chomp $read_name;
        last unless $read_name;

        my $sequence = $fastq->getline;
        chomp $sequence;
        
        my $throwaway = $fastq->getline;  # This line should just be "+"

        my $quality = $fastq->getline;
        chomp $quality;

        unless ($sequence && $quality) {
            $self->error_message("Malformed data in fastq file, no sequence or quality found for read $read_name line ".$fastq->input_line_number);
            return;
        }

        $presorted->print(join("\t", $sequence, $read_name, $quality),"\n");
    }

    $presorted->close();
    $fastq->close();

    my $rv = system("sort $presorted_pathname > $postsorted_pathname");
    if ($rv) {
        $self->error_message("Get a non-zero return value from sorting $presorted_pathname into $postsorted_pathname");
        return;
    }

    unless (-f $postsorted_pathname and -s $postsorted_pathname) {
        $self->error_message("Sorted sequence file $postsorted_pathname has no info");
        return;
    }

    my $postsorted = IO::File->new($postsorted_pathname);

    my $sorted_pathname = $self->sorted_fastq_file_for_lane();
    my $sorted = IO::File->new(">$sorted_pathname");
    unless ($sorted) {
        $self->error_message("Can't create $sorted_pathname for writing: $!");
        return;
    }

#    my %read_index;
#    # Create the DBM file in /tmp initially  because it's faster
#    my $model = Genome::Model->get(id => $self->model_id);
#    my $run = Genome::RunChunk->get(id => $self->run_id);
#    my $temp_dbm_file = sprintf("/tmp/fastq_index_%s_%s_%d.dbm", $model->genome_model_id, $run->limit_regions, $$);
#    unless (tie(%read_index, 'GDBM_File', $temp_dbm_file, &GDBM_WRCREAT, 0666)) {
#        $self->error_message("Failed to tie to DBM file $temp_dbm_file");
#        return;
#    }

#    my $file_offset = 0;
    while(<$postsorted>) {
        chomp;
        my($sequence,$read_name,$quality) = split;
        my $record = "$read_name\n$sequence\n+\n$quality\n";
        $sorted->print($record);

#        $read_index{$read_name} = $file_offset;
#        $file_offset += length($record);
    }

#    untie %read_index;
    $postsorted->close();
    $sorted->close();

#    my $dbm_file = $self->read_index_dbm_file_for_lane();
#    `mv $temp_dbm_file $dbm_file`;
#    if ($?) {
#        $self->error_message("Failed to move $temp_dbm_file $dbm_file");
#        return;
#    }

    unlink($presorted_pathname,$postsorted_pathname);
        
    return 1;
}

         



1;

