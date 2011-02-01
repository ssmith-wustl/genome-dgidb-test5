package Genome::Model::Tools::Maq::UnalignedDataToFastq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Maq::UnalignedDataToFastq {
    is => 'Command',
    has => [
        in              => { is => 'Text', 
                            doc => "Pathname to a file generated from maq map's -u option", 
                            shell_args_position => 1 },
    ],
    has_optional => [
        fastq           => { is => 'Text', 
                            doc => 'the output pathname for "forward" reads (or all reads on a fragment run)', 
                            shell_args_position => 2 },

        reverse_fastq   => { is => 'Text', 
                            doc => 'the output pathname for "reverse" for paired-end data', 
                            shell_args_position => 3 },
    ],
    doc => "Create a new fastq-format file containing reads that aligned poorly in the prior align-reads step"
};

sub help_synopsis {
    return <<"EOS"
    gmt maq unaligned-data-to-fastq in.maq-unaligned out.fwd.fastq out.rev.fastq
    
    gmt maq unaligned-data-to-fastq -i /path/to/inputpathname.unaligned -f /path/to/forward.fastq -r /path/to/reverse.fastq
EOS
}

sub help_detail {                           
    return <<EOS 
As part of the aligmnent process, the -u option to maq will create a file containing 
reads that had low alignment quailty, or did not align at all.  This command
will take that file and create a fastq-formatted file containing those reads.

For paired-end data, this tool will make 2 files, and expect 2 outputs to be specified.

It will correct the error common in some maq unaligned files that read #2 is misnamed with the name of its mate.
EOS
}

sub execute {
    my $self = shift;
    
$DB::single = $DB::stopper;

    my $unaligned_file = $self->in();
    my $unaligned = IO::File->new($unaligned_file);
    unless ($unaligned) {
        $self->error_message("Unable to open $unaligned_file for reading: $!");
        return;
    }

    my $unaligned_fastq_file1 = $self->fastq();
    my $fastq1 = IO::File->new(">$unaligned_fastq_file1");
    unless ($fastq1) {
        $self->error_message("Unable to open $unaligned_fastq_file1 for writing: $!");
        return;
    }
  
    my $unaligned_fastq_file2 = $self->reverse_fastq();
    my $fastq2;

    if ($unaligned_fastq_file2) {
        $fastq2 = IO::File->new(">$unaligned_fastq_file2");
        unless ($fastq2) {
            $self->error_message("Unable to open $unaligned_fastq_file2 for writing: $!");
            return;
        }
    }

    my ($read_name,$alignment_quality,$sequence,$read_quality);
    my $last_read_name;
    my $warned;
    if ($fastq2) {
        while(<$unaligned>) {
            chomp;
            ($read_name,$alignment_quality,$sequence,$read_quality) = split;
            if ($read_name !~ /\/1\s*$/) {
                die "bad read name $read_name.  expected forward read to end in /1";
            }
            $fastq1->print("\@$read_name\n$sequence\n\+\n$read_quality\n");

            $last_read_name = $read_name;

            my $rev = <$unaligned>;
            chomp $rev;
            ($read_name,$alignment_quality,$sequence,$read_quality) = split(/\s+/,$rev);
            if ($read_name eq $last_read_name) {
                substr($read_name,length($read_name)-1,1) = '2';
                unless ($warned) {
                    $self->status_message("repairing the reverse read names in the unaligned reads file when producing a new fastq ($read_name)...");
                    $warned = 1;
                } 
            }
            elsif ($read_name !~ /\/2\s*$/) {
                die "bad read name $read_name.  expected reverse read to end in /2 (or to have a name matching its mate we can repair)";
            }
            $fastq2->print("\@$read_name\n$sequence\n\+\n$read_quality\n");
        }
        
    }
    else {
        while(<$unaligned>) {
            chomp;
            my($read_name,$alignment_quality,$sequence,$read_quality) = split;
            $fastq1->print("\@$read_name\n$sequence\n\+\n$read_quality\n");
        }
    }

    $unaligned->close();
    $fastq1->close();
    $fastq2->close() if $fastq2;
    return 1;
}

1;

