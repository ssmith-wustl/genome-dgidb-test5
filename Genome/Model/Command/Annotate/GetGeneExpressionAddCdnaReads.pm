
package Genome::Model::Command::Annotate::GetGeneExpressionAddCdnaReads;

use strict;
use warnings;
use Getopt::Long;
use Carp;
use MPSampleData::DBI;
use MPSampleData::ExternalGeneId;
use MG::Analysis::VariantAnnotation;

use above "Genome";

class Genome::Model::Command::Annotate::GetGeneExpressionAddCdnaReads {
    is  => 'Command',
    has => [
        dev    => { type => 'String', doc => "The database to use" },
        infile => { type => 'String', doc => "The infile (full report file so far)" },
        outfile => { type => 'String', doc => "The outfile" },
        read_hash_unique_dna    => { type => 'String', doc => "ARGV[1]" },
        read_hash_cdna          => { type => 'String', doc => "ARGV[2]" },
        read_hash_unique_cdna   => { type => 'String', doc => "ARGV[3]" },
        read_hash_relapse_cdna  => { type => 'String', doc => "ARGV[4]" },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "This command is does both the GetGeneExpression stuff and the AddCdnaReads stuff."
}

sub help_synopsis {
    return <<EOS
genome-model Annotate GetGeneExpression--dev=std_test --infile=~xshi/temp_1/AML_SNP/amll123t92_q1r07t096/TEMP --outfile=base_file_name
EOS
}

sub help_detail {
    return <<EOS
This command is does both the GetGeneExpression stuff and the AddCdnaReads stuff
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
    my %options = ( 'dev' => $self->dev, );
    #GetOptions( 'devel=s' => \$options{'dev'}, );

    unless ( defined( $options{'dev'} ) ) {
        croak "usage $0 --dev <database sample_data/sd_test..>";
    }
    MG::Analysis::VariantAnnotation->change_db( $options{dev} );

    my ($Srv)      = 'mysql2';
    my ($Uid)      = "sample_data";
    my ($Pwd)      = q{Zl0*rCh};
    my ($database) = "sd_test";
    my $gene_hash;
    my ($X);

    #$X cannot have 'my($X)' or else it will close every time.
    ( $X = DBI->connect( "DBI:mysql:$database:$Srv", $Uid, $Pwd ) ) or ( die "fail to connect to database \n" );

    my $sql = qq{
        select expression_intensity, detection from gene_expression ge 
        join gene_gene_expression gge on gge.expression_id=ge.expression_id
        join gene g on g.gene_id=gge.gene_id 
        join external_gene_id egi on egi.gene_id=g.gene_id 
        where (g.hugo_gene_name=?  or egi.id_value=?)  
        order by expression_intensity desc limit 1; };
    my ($sth) = $X->prepare($sql);
    my $submitted;

    open( SUB, "</gscuser/xshi/work/AML_SNP/Gene_to_check/AMP_SNP_set3.submit.091507.results.8oct2007.csv") or die "Can't open  $!";
    while (<SUB>) {
        next if (/dbSNP/);
        my ( $dbsnp, $chrom, $start, $end, $a1, $g1, $g2, $a2 ) = split(/,/);
        $submitted->{"$chrom,$start,$end"} = 1;
    }
    close(SUB);
    open( IN, "<", $self->infile ) or die "Can't open " . $self->infile . " $!";
    open( OUT, ">", $self->outfile ) or die "Can't open " . $self->outfile . " $!";
    print OUT
qq{"dbSNP(0:no; 1:yes)",Gene_name,Chromosome,"Start_position (B36)","End_position (B36)",Variant_allele,"# of genomic reads supporting variant allele","# of cDNA reads supporting variant allele",Reference_allele,"# of genomic reads supporting reference allele","# of cDNA reads supporting reference allele",Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction,"submit(0:no; 1:yes)"
};

#print OUT "dbSNP(0:no; 1:yes),Gene_name,Chromosome,Start_position (B36),End_position (B36),Reference_allele,Variant_allele,# of genomic reads supporting reference allele,# of cDNA reads supporting reference allele,# of genomic reads supporting variant allele,# of cDNA reads supporting variant allele,Gene_expression,Detection,Ensembl_transcript_id,Transcript_stranding,Variant_type,Transcript_position,Amino_acid_change,Polyphen_prediction\n";
    while (<IN>) {
        next if (/dbSNP/);
        chomp();
        my $line           = $_;
        my $pph_prediction = "NULL";
        my (
            $dbsnp,     $chromosome, $start,    $end,       $al1,
            $al1_read1, $al1_read2,  $al2,      $al2_read1, $al2_read2,
            $gene,      $transcript, $strand,   $trv_type,  $c_position,
            $pro_str,   $polyphen,   $gene_exp, $gene_det,  $rgg_id
          )
          = split(/,/);
        print "check  $chromosome,$start,$end,$al1,$al2,$transcript...............\n";

        #only check flanking region as 10k bp
        if ( $trv_type =~ /flank/ ) {
            my ($tr) = MPSampleData::Transcript->search( "transcript_name" => $transcript );
            next unless ( ( $tr->transcript_start > $start && $start >= $tr->transcript_start - 10000) || (   $tr->transcript_stop < $start && $start <= $tr->transcript_stop + 10000 ));
        }
        $gene_hash->{$gene} = MG::Analysis::VariantAnnotation->get_gene_expression( $sth, $gene ) unless ( defined $gene_hash->{$gene} );

        #check whether submitted or not
        my $submit;
        if ( exists $submitted->{"$chromosome,$start,$end"} && $submitted->{"$chromosome,$start,$end"} == 1 ) {
            $submit = 1;
        }
        else { 
			$submit = 0; 
		}
        print OUT
"$dbsnp,$gene,$chromosome,$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,",
          $gene_hash->{$gene}->{exp}, ",", $gene_hash->{$gene}->{det},
",$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id\n";
    }

    print "final finished!\n";

    close(IN);
    close(OUT);

    #subroutine

    # check if submitted or -+20bp
    sub check_submitted {
        open( FILTER, ">$options{'file'}.filted" ) or die "Can't open $options{'file'}.filted. $!";
        open( IN, "<$options{'file'}.prioritized" ) or die "Can't open $options{'file'}.prioritized. $!";
        while (<IN>) { print FILTER $_; last; }
        while (<IN>) {
            my $grep = 0;
            chomp();
            my @sp = split(/,/);
            open( CHECK, "</gscuser/xshi/work/AML_SNP/AML_SNP_set.091507.txt" ) or die "Can't open /gscuser/xshi/work/AML_SNP/AML_SNP_set.091507.txt. $!";
            while (<CHECK>) { last; }
            while (<CHECK>) {
                chomp();
                my @fi = split(/,/);
                if ( lc( $fi[1] ) eq lc( $sp[1] ) && ( $sp[2] >= $fi[2] - 20 && $sp[3] <= $fi[3] + 20 ) ) {
                    { $grep = 1; last; }
                }
            }
            close(CHECK);
            print FILTER join( ",", @sp ), "\n" if ( $grep == 0 );
        }
        close(IN);
        close(FILTER);

    }
	
	
	# begin addCdnaReads stuff
    my $read_hash_unique_dna = MG::Analysis::VariantAnnotation->add_unique_reads_count( $self->read_hash_unique_dna );
    my $read_hash_cDNA = MG::Analysis::VariantAnnotation->add_reads_count( $self->read_hash_cdna );
    my $read_hash_unique_cDNA = MG::Analysis::VariantAnnotation->add_unique_reads_count( $self->read_hash_unique_cdna );
    my $read_hash_relapse_cDNA = MG::Analysis::VariantAnnotation->add_reads_count( $self->read_hash_relapse_dna );

    open( IN, "<", $self->outfile ) or die "Can't open " . $self->outfile . "$!";
    open( OUT, ">", $self->outfile."read" ) or die "Can't open " . $self->outfile."read" . "$!";

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

