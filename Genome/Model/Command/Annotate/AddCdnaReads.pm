
package Genome::Model::Command::Annotate::AddCdnaReads;

use strict;
use warnings;
use lib '/gscuser/xshi/svn/mp';
use MG::Analysis::VariantAnnotation;

use above "Genome";

class Genome::Model::Command::Annotate::AddCdnaReads {
    is  => 'Command',
    has => [
        outfile => { type => 'String', doc => "ARGV[0], the outfile" },
        read_hash_unique_dna    => { type => 'String', doc => "ARGV[1]" },
        read_hash_cdna          => { type => 'String', doc => "ARGV[2]" },
        read_hash_unique_cdna   => { type => 'String', doc => "ARGV[3]" },
        read_hash_relapse_cdna  => { type => 'String', doc => "ARGV[4]" },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "WRITE A ONE-LINE DESCRIPTION HERE"
}

sub help_synopsis {
    return <<EOS
genome-model example1 --foo=hello
genome-model example1 --foo=goodbye --bar
genome-model example1 --foo=hello barearg1 barearg2 barearg3
EOS
}

sub help_detail {
    return <<EOS
This is a dummy command.  Copy, paste and modify the module! 
CHANGE THIS BLOCK OF TEXT IN THE MODULE TO CHANGE THE HELP OUTPUT.
EOS
}

#sub create {                               # rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # pre-execute checking.  Not requiried.  Delete unless you use it. <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {
    my $self = shift;

    my $read_hash_unique_dna = MG::Analysis::VariantAnnotation->add_unique_reads_count( $self->read_hash_unique_dna );
    my $read_hash_cDNA = MG::Analysis::VariantAnnotation->add_reads_count( $self->read_hash_cdna );
    my $read_hash_unique_cDNA = MG::Analysis::VariantAnnotation->add_unique_reads_count( $self->read_hash_unique_cdna );
    my $read_hash_relapse_cDNA = MG::Analysis::VariantAnnotation->add_reads_count( $self->read_hash_relapse_cdna );

    open( IN, "<", $self->outfile ) or die "Can't open " . $self->outfile . "$!";
    open( OUT, ">", $self->outfile.".read" ) or die "Can't open " . $self->outfile."read" . "$!";

    print OUT
qq{"dbSNP(0:no; 1:yes)",Gene_name,Chromosome,"Start_position (B36)","End_position (B36)",Variant_allele,"# of genomic reads supporting variant allele","# of cDNA reads supporting variant allele","# of unique genomic reads supporting variant allele(starting point)","# of unique genomic reads supporting variant allele(context)","# of unique cDNA reads supporting variant allele(starting point)","# of unique cDNA reads supporting variant allele(context)","# of relapse cDNA reads supporting variant allele",Reference_allele,"# of genomic reads supporting reference allele","# of cDNA reads supporting reference allele","# of unique genomic reads supporting reference allele(starting point)","# of unique genomic reads supporting reference allele(context)","# of unique cDNA reads supporting reference allele(starting point)","# of unique cDNA reads supporting reference allele(context)","# of relapse cDNA reads supporting reference allele",Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,"submit(0:no; 1:yes)"\n};

    while (<IN>) {
        chomp();
        my $line = $_;
        next if ( $line =~ /dbSNP/ );
        my (
            $dbsnp,      $gene,        $chromosome,     $start,
            $end,        $al1,         $al1_read_hg,    $al1_read_cDNA,
            $al2,        $al2_read_hg, $al2_read_cDNA,  $gene_exp,
            $gene_det,   $transcript,  $strand,         $trv_type,
            $c_position, $pro_str,     $pph_prediction, $submit,
            $rgg_id
          )
          = split(/,/);
        my ( $al1_read_unique_dna_start,   $al2_read_unique_dna_start,
            $al1_read_unique_dna_context, $al2_read_unique_dna_context
        );
        my (
            $al1_read_relapse_cDNA,        $al2_read_relapse_cDNA,
            $al1_read_unique_cDNA_start,   $al2_read_unique_cDNA_start,
            $al1_read_unique_cDNA_context, $al2_read_unique_cDNA_context
        );

        my $read_unique_dna   = $read_hash_unique_dna->{$chromosome}->{$start};
        my $read_cDNA         = $read_hash_cDNA->{$chromosome}->{$start};
        my $read_unique_cDNA  = $read_hash_unique_cDNA->{$chromosome}->{$start};
        my $read_relapse_cDNA = $read_hash_relapse_cDNA->{$chromosome}->{$start};

        if ( defined $read_unique_dna ) {
            $al1_read_unique_dna_start   = $read_unique_dna->{$al1}->{start};
            $al2_read_unique_dna_start   = $read_unique_dna->{$al2}->{start};
            $al1_read_unique_dna_context = $read_unique_dna->{$al1}->{context};
            $al2_read_unique_dna_context = $read_unique_dna->{$al2}->{context};
        }
        else {
            $al1_read_unique_dna_start   = 0;
            $al2_read_unique_dna_start   = 0;
            $al1_read_unique_dna_context = 0;
            $al2_read_unique_dna_context = 0;
        }

        if ( defined $read_cDNA ) {
            $al1_read_cDNA = $read_cDNA->{$al1};
            $al2_read_cDNA = $read_cDNA->{$al2};
        }
        else {
            $al1_read_cDNA = 0;
            $al2_read_cDNA = 0;
        }

        if ( defined $read_unique_cDNA ) {
            $al1_read_unique_cDNA_start   = $read_unique_cDNA->{$al1}->{start};
            $al2_read_unique_cDNA_start   = $read_unique_cDNA->{$al2}->{start};
            $al1_read_unique_cDNA_context = $read_unique_cDNA->{$al1}->{context};
            $al2_read_unique_cDNA_context = $read_unique_cDNA->{$al2}->{context};
        }
        else {
            $al1_read_unique_cDNA_start   = 0;
            $al2_read_unique_cDNA_start   = 0;
            $al1_read_unique_cDNA_context = 0;
            $al2_read_unique_cDNA_context = 0;
        }

        if ( defined $read_relapse_cDNA ) {
            $al1_read_relapse_cDNA = $read_relapse_cDNA->{$al1};
            $al2_read_relapse_cDNA = $read_relapse_cDNA->{$al2};
        }
        else {
            $al1_read_relapse_cDNA = 0;
            $al2_read_relapse_cDNA = 0;
        }
        print OUT
"$dbsnp,$gene,$chromosome,$start,$end,$al2,$al2_read_hg,$al2_read_cDNA,$al2_read_unique_dna_start,$al2_read_unique_dna_context,$al2_read_unique_cDNA_start,$al2_read_unique_cDNA_context,$al2_read_relapse_cDNA,$al1,$al1_read_hg,$al1_read_cDNA,$al1_read_unique_dna_start,$al1_read_unique_dna_context,$al1_read_unique_cDNA_start,$al1_read_unique_cDNA_context,$al1_read_relapse_cDNA,$gene_exp,$gene_det,$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id\n";
    }
    print "final finished!\n";

    close(IN);
    close(OUT);

    return 0;
}

1;

