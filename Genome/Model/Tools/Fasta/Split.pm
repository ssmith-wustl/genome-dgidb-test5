package Genome::Model::Tools::Fasta::Split;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Fasta::Split {
    is => 'Command',
    has => [
        fasta_file => { is => 'Text', },
        kb_sequence => {
            is => 'Number',
            doc => 'The number of kb sequence to include in each instance. default_value=10000',
            default_value => 10000,
        },
        fasta_files => {
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    my @fasta_files;

    my $file_counter = 1;
    my ($fasta_basename,$fasta_dirname) = File::Basename::fileparse($self->fasta_file);
    unless (Genome::Utility::FileSystem->validate_directory_for_read_write_access($fasta_dirname)) {
        $self->error_message('Failed to validate directory '. $fasta_dirname ." for read/write access:  $!");
        die($self->error_message);
    }
    my $output_file = $fasta_dirname .'/'. $fasta_basename .'_'. $file_counter;

    #Divide fasta files by kb_sequence
    my $output_fh = Genome::Utility::FileSystem->open_file_for_writing($output_file);
    unless ($output_fh) {
        $self->error_message('Failed to open output file '. $output_file);
        die($self->error_message);
    }
    push @fasta_files, $output_file;
    my $fasta_reader = Genome::Utility::FileSystem->open_file_for_reading($self->fasta_file);
    unless ($fasta_reader) {
        $self->error_message('Failed to open fasta file '. $self->fasta_file);
        die($self->error_message);
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
                $output_file = $fasta_dirname .'/'. $fasta_basename .'_'. $file_counter;
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
    $self->fasta_files(\@fasta_files);
    return 1;
}

1;
