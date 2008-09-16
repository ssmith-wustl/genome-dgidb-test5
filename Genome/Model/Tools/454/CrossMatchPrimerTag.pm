package Genome::Model::Tools::454::CrossMatchPrimerTag;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::Model::Tools::454::CrossMatchPrimerTag {
    is => ['Genome::Model::Tools::454'],
    has => [
            in_sff_file => {
                            is => 'String',
                            doc => 'The sff file to operate',
                        },
            out_sff_file => {
                             is => 'String',
                             doc => 'The output file path',
                         },
            primer_fasta => {
                             is => 'String',
                             doc => 'A fasta file of primer sequences',
                         },
        ],
};

sub help_brief {
    "isolate the the sequence primer from a set of reads"
}

sub help_detail {
    return <<EOS
create a new sff file with first n(default=20) base pair were the expected primer should be found
EOS
}

sub execute {
    my $self = shift;

    unless (-e $self->in_sff_file) {
        die ('Failed to find file '. $self->in_sff_file ."\n");
    }

    my $basename = basename($self->in_sff_file);
    #my $tmp_fasta_file = $self->_tmp_dir . '/'. $basename .'.fasta';

    #for testing
    my $tmp_fasta_file = $self->in_sff_file .'.fasta';
    my $tmp_cm_file = $tmp_fasta_file .'.cm';
    my $fasta_sffinfo = Genome::Model::Tools::454::Sffinfo->create(
                                                                   sff_file => $self->in_sff_file,
                                                                   output_file => $tmp_fasta_file,
                                                                   params => '-s',
                                                               );
    unless ($fasta_sffinfo->execute) {
        die('Failed to dump fasta data from '. $self->in_sff_file);
    }

    my $tmp_qual_file = $tmp_fasta_file .'.qual';
    my $qual_sffinfo = Genome::Model::Tools::454::Sffinfo->create(
                                                                  sff_file => $self->in_sff_file,
                                                                  output_file => $tmp_fasta_file .'.qual',
                                                                  params => '-q',
                                                              );
    unless ($qual_sffinfo->execute) {
        die('Failed to dump fasta data from '. $self->in_sff_file);
    }
    
    my $cmd = 'cross_match.test -tags -masklevel 0 -gap1_only -minmatch 6 -minscore 6 '. $tmp_fasta_file
        .' > '. $tmp_cm_file;
    my $rv = system($cmd);
    unless ($rv == 0) {
        die ("Failed to run command $cmd");
    }
    return 1;
}

1;


