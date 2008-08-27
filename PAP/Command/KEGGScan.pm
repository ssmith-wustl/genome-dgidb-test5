#$Id$

package PAP::Command::KEGGScan;

use strict;
use warnings;

use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;

use English;
use File::Basename;
use File::chdir;
use File::Temp;
use IO::File;
use IPC::Run;


class PAP::Command::KEGGScan {
    is  => ['PAP::Command'],
    has => [
        fasta_file        => { 
                              is  => 'SCALAR', 
                              doc => 'fasta file name',            
                             },
        working_directory => {
                              is          => 'SCALAR',
                              is_optional => 1,
                              doc         => 'analysis program working directory',
                             },
        bio_seq_feature   => { 
                              is          => 'ARRAY',  
                              is_optional => 1,
                              doc         => 'array of Bio::Seq::Feature', 
                           },
    ],
};

operation PAP::Command::KEGGScan {
    input  => [ 'fasta_file'      ],
    output => [ 'bio_seq_feature' ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run KEGGscan";
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


    ##FIXME:  This should not be hardcoded.  At least not here.  
    my @keggscan_command = (
                            '/gsc/scripts/gsc/annotation/KEGGscan_KO.new.070125',
                           );
    
    my ($kegg_stdout, $kegg_stderr);
    
    $self->working_directory(
                             File::Temp::tempdir(
                                                 'PAP_keggscan_XXXXXXXX',
                                                 DIR     => '/gscmnt/temp212/info/annotation/PAP_tmp',
                                                 CLEANUP => 1,
                                             )
                         );

    my $fasta_file = $self->fasta_file();

    ## We're about to screw with the current working directory.
    ## Thusly, we must fixup the fasta_file property if it 
    ## contains a relative path.  
    unless ($fasta_file =~ /^\//) {
        $fasta_file = join('/', $CWD, $fasta_file);
        $self->fasta_file($fasta_file);
    }
    
    $self->write_config_file();

    {
    
        local $CWD = $self->working_directory();

        IPC::Run::run(
                     \@keggscan_command,
                     \undef,
                     '>',
                     \$kegg_stdout,
                     '2>',
                     \$kegg_stderr,
                     );
                     
    }
    
    $self->parse_result();

    return 1;

}

=head1 create_kscfg

KEGGscan needs a configuration file with these items:

 SpeciesName\t"species"
 QueryFastaPath\t"path/to/peptides"
 SubjectFastaPath\t"path/to/KEGGrelease"
 QuerySeqType\t"CONTIG"
 Queue\t"long"
 BladeLoad\t"40"
 KeggRelease\t"RELEASE-41"

=cut

sub write_config_file {

    my $self = shift;


    ##FIXME:  This probably should not be undef.  This should probably be an input property.
    my $species = undef;

    ##FIXME:  Hardcoded path.
    my $subjectpath = "/gscmnt/233/analysis/sequence_analysis/species_independant/jmartin/hgm.website/KEGG/KEGG_release_41/genes.v41.faa";
    
    my $query_fasta = $self->fasta_file();
    my $working_dir = $self->working_directory();

    my $bladeload  = 40;
    my $keggrel    = "RELEASE-41";

    my @config = (
                  qq(SpeciesName\t"default"\n),
                  qq(QueryFastaPath\t"$query_fasta"\n),
                  qq(SubjectFastaPath\t"$subjectpath"\n),
                  qq(QuerySeqType\t"CONTIG"\n),
                  qq(Queue\t"long"\n),
                  qq(BladeLoad\t"$bladeload"\n),
                  qq(KeggRelease\t"$keggrel"\n),
                 );

    my $cfg_fh = IO::File->new();
    $cfg_fh->open(">$working_dir/KS.cfg") or die "Can't open '$working_dir/KS.cfg': $OS_ERROR";

    print $cfg_fh @config;

    $cfg_fh->close();
    
    return;
    
}

sub parse_result {

    my $self = shift;


    my $output_fn = join('.', 'KS-OUTPUT', File::Basename::basename($self->fasta_file()));
    $output_fn = join('/', $self->working_directory(), $output_fn, 'REPORT-top.ks');
    
    my $output_fh = IO::File->new();
    
    $output_fh->open("$output_fn") or die "Can't open '$output_fn': $OS_ERROR";

    my @features = ( );
    
    while (my $line = <$output_fh>) {

        my @fields = split /\t/, $line;
        
        my (
            $ec_number,
            $gene_name,
            $hit_name,
            $e_value,
            $description,
            $orthology
           ) = @fields[1,2,3,4,6,8];

        ## The values in the third column should be in this form:
        ## gene_name (N letters; record M)
        ($gene_name) = split /\s+/, $gene_name; 

        ## Some descriptions have EC numbers embedded in them.
        ## Prat's original pipeline removed them.
        ## The present goal is to match the output of that pipeline.
        ## Thus, remove the EC numbers.
        $description =~ s/\(EC .+\)//;
        
        my $feature = new Bio::SeqFeature::Generic(-display_name => $gene_name);

        $feature->add_tag_value('kegg_evalue', $e_value);
        $feature->add_tag_value('kegg_description', $description);
        
        my $gene_dblink = Bio::Annotation::DBLink->new(
                                                       -database   => 'KEGG',
                                                       -primary_id => $hit_name,
                                                   );
        
        $feature->annotation->add_Annotation('dblink', $gene_dblink);

        ## Sometimes there is no orthology identifier (value is literally 'none').
        ## It is not unforseeable that it might also be blank/undefined.  
        if (defined($orthology) && ($orthology ne 'none')) {
        
            my $orthology_dblink = Bio::Annotation::DBLink->new(
                                                                -database   => 'KEGG',
                                                                -primary_id => $orthology,
                                                            );
            
            $feature->annotation->add_Annotation('dblink', $orthology_dblink);
                
        }
        
        push @features, $feature;
        
    }

    $output_fh->close();
    
    $self->bio_seq_feature( \@features );

    return;
    
}
 
1;
