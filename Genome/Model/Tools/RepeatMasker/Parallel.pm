package Genome::Model::Tools::RepeatMasker::Parallel;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::RepeatMasker::Parallel {
    is => ['Workflow::Operation::Command'],
    workflow => sub {
        my $run = Workflow::Operation->create(
            name => 'run',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::RepeatMasker::Run')
        );
        $run->parallel_by('fasta_file');
        return $run;
    },
    has => [
            kb_sequence => {
                is => 'Number',
                doc => 'The number of snapshots to create. defalut_value=100',
                default_value => 10000,
            },
            #output_directory => {
            #                     calculate_from => ['base_output_directory','unique_subdirectory'],
            #                     calculate => q|
            #                         return $base_output_directory . $unique_subdirectory;
            #                     |
            #                 },
            #unique_subdirectory => {
            #                calculate_from => ['fasta_file'],
            #                calculate => q|
            #                                   my $fasta_basename = File::Basename::basename($fasta_file);
            #                                   if ($fasta_basename =~ /(\d+)$/) {
            #                                       return '/'. $1;
            #                                   } else {
            #                                       return '';
            #                                   }
            #                               |,
            #            },
        ],
};

sub pre_execute {
    my $self = shift;

    my @fasta_files;
    
    my $file_counter = 1;
    my $fasta_basename = File::Basename::basename($self->fasta_file);
    my $output_file = $self->base_output_directory .'/'. $fasta_basename .'_'. $file_counter;
    #Divide fasta files by kb_sequence
    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $output_file);
        return;
    }
    push @fasta_files, $output_file;
    
    my $fasta_reader = Genome::Utility::FileSystem->open_file_for_reading($self->fasta_file);
    unless ($fasta_reader) {
        $self->error_message('Failed to open fasta file '. $self->fasta_file);
        return;
    }
    local $/ = "\n>";
    my $total_seq = 0;
    while (<$fasta_reader>) {
        if ($_) {
            chomp;
            if ($_ =~ /^>/) { $_ =~ s/\>//g }
            my $myFASTA = FASTAParse->new();
            $myFASTA->load_FASTA( fasta => '>' . $_ );
            my $seqlen = length( $myFASTA->sequence() );
            $total_seq += $seqlen;
            if ($total_seq >= ($self->kb_sequence * 1000)) {
                $file_counter++;
                $output_fh->close;
                $output_file = $self->base_output_directory .'/'. $fasta_basename .'_'. $file_counter;
                $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output_file);
                unless ($output_fh) {
                    $self->error_message('Failed to open fasta output file '. $output_file);
                    return;
                }
                push @fasta_files, $output_file;
                $total_seq = 0;
            }
            print $output_fh '>'. $myFASTA->id() ."\n". $myFASTA->sequence() . "\n";
        }
    }
    $fasta_reader->close;
    $output_fh->close;
    $self->fasta_file(\@fasta_files);
    return 1;
}

sub post_execute {
    my $self = shift;

    print Data::Dumper->new([$self])->Dump;

    # merge the RepeatMasker tables
    return 1;
}


1;
