#$Id$

package PAP::Command::InterProScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqFeature::Generic;
use Bio::SeqIO;

use English;
use File::Temp;
use IO::File;
use IPC::Run;


class PAP::Command::InterProScan {
    is => ['PAP::Command'],
    has => [
        fasta_file      => {  
                            is  => 'SCALAR', 
                            doc => 'fasta file name',
                           },
        iprscan_output => {
                           is            => 'SCALAR',
                           is_optional   => 1,
                           doc           => 'instance of File::Temp pointing to raw iprscan output',
                          },
        bio_seq_feature => { 
                            is          => 'ARRAY',
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature' 
                           },
    ],
};

operation PAP::Command::InterProScan {
    input        => [ 'fasta_file'      ],
    output       => [ 'bio_seq_feature' ],
    lsf_queue    => 'long',
    lsf_resource => 'rusage[tmp=100]',
    
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run iprscan";
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

    my $self = shift;


    my $fasta_file  = $self->fasta_file();

    my $tmp_fh = File::Temp->new();
    my $tmp_fn = $tmp_fh->filename();

    $self->iprscan_output($tmp_fh);
    
    my @iprscan_command = (
                           '/gscmnt/974/analysis/iprscan16.1/iprscan/bin/iprscan.hacked',
                           '-cli',
                           '-appl',
                           'hmmpfam',
                           '-goterms',
                           '-verbose',
                           '-iprlookup',
                           '-seqtype',
                           'p',
                           '-format',
                           'raw',
                           '-i',
                           $fasta_file,
                           '-o',
                           $tmp_fn,
                       );

    my ($iprscan_stdout, $iprscan_stderr);
    
    IPC::Run::run(
                  \@iprscan_command, 
                  \undef, 
                  '>', 
                  \$iprscan_stdout, 
                  '2>', 
                  \$iprscan_stderr, 
                 ) || die "iprscan failed: $CHILD_ERROR";

    $self->parse_result();

    ## Be Kind, Rewind.  Somebody will surely assume we've done this, 
    ## so let's not surprise them.  
    $tmp_fh->seek(0, SEEK_SET);
    
    return 1;

}

sub parse_result {

    my $self = shift;


    my $iprscan_fh = $self->iprscan_output();

    my @features = ( );
    
    while (my $line = <$iprscan_fh>) {

        chomp $line;
        
        ## iprscan raw format is described here:
        ## ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/README.html#3
        my (
            $protein_name,
            $checksum,
            $length,
            $analysis_method,
            $database_entry,
            $database_member,
            $start,
            $end,
            $evalue,
            $status,
            $run_date,
            $ipr_number,
            $ipr_description,
            $go_description,
        ) = split /\t/, $line;

        if ($ipr_number ne 'NULL') {

            my $feature = Bio::SeqFeature::Generic->new(
                                                        -display_name => $protein_name,
                                                    );

            $feature->add_tag_value('interpro_analysis',    $analysis_method);
            $feature->add_tag_value('interpro_evalue',      $evalue);
            $feature->add_tag_value('interpro_description', $ipr_description);

            my $dblink = Bio::Annotation::DBLink->new(
                                                      -database   => 'InterPro',
                                                      -primary_id => $ipr_number,
                                                  );

            $feature->annotation->add_Annotation('dblink', $dblink);
    
            push @features, $feature;
    
        }

    }

    $self->bio_seq_feature(\@features);
    
}

1;
