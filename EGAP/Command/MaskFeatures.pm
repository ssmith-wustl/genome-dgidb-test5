package EGAP::Command::MaskFeatures;

use strict;
use warnings;

use Workflow;

use Bio::SeqIO;
use Bio::SeqFeature::Generic;

use File::Temp;

class EGAP::Command::MaskFeatures {
    is => ['EGAP::Command'],
    has => [
        fasta_file => { 
                       is  => 'TEXT',
                       doc => 'single fasta file', 
                      },
        bio_seq_feature => { 
                            is  => 'ARRAY', 
                            doc => 'array of Bio::Seq::Feature', 
                           },
        masked_fasta_file => {
                              is          => 'TEXT',
                              is_optional => 1,
                              doc         => 'single masked fasta file',
                             }
    ],
};

operation_io EGAP::Command::MaskFeatures {
    input  => [ 'fasta_file', 'bio_seq_feature' ],
    output => [ 'masked_fasta_file' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Write a set of fasta files for an assembly";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my ($self) = @_;


    my $output_fh = File::Temp->new(
                                    'DIR'      => '/gscmnt/temp212/info/annotation/EGAP_tmp',
                                    'SUFFIX'   => '.tmp',
                                    'TEMPLATE' => 'EGAP_XXXXXXXX',
                                    'UNLINK'   => 0,
                                   );
    
    my $seq_in  = Bio::SeqIO->new(-format => 'Fasta', -file => $self->fasta_file());
    my $seq_out = Bio::SeqIO->new(-format => 'Fasta', -fh => $output_fh);
    
    my $seq        = $seq_in->next_seq();
    my $display_id = $seq->display_id(); 
    my $seq_string = $seq->seq();
   
    foreach my $feature (@{$self->bio_seq_feature()}) {

        my $seq_id = $feature->seq_id();
        my $length = $feature->length();
        my $start  = $feature->start();
        my $end    = $feature->end();
        
        unless ($display_id eq $seq_id) {
            die "got feature relative to sequence other than input fasta"
        }

        foreach my $coord ($start, $end) {
            if ($coord < 1) {
                $coord = 1;
            }
            if ($coord > $seq->length()) {
                $coord = $seq->length();
            }
        }
        
        unless ($start <= $end) { 
            ($start, $end) = ($end, $start); 
        }
       
        $length = ($end - $start) + 1;
        
        substr($seq_string, $start - 1, $length, 'N' x $length);
        
    }

    my $masked_seq = Bio::Seq->new(-display_id => $display_id, -seq => $seq_string);
    
    $seq_out->write_seq($masked_seq);
    
    $self->masked_fasta_file($output_fh->filename());
    
    return 1;

}

1;
