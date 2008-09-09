package Genome::Model::Command::Annotate::GetGeneExpression;

warn __PACKAGE__ . " is broken";
1;
__END__

use strict;
use warnings;

use Carp;
use Data::Dumper;
#use MPSampleData::DBI;
use MPSampleData::ExternalGeneId;
use MG::Analysis::VariantAnnotation;

use Genome;

class Genome::Model::Command::Annotate::GetGeneExpression {
    is  => 'Command',
    has => [
    #dev    => { type => 'String', doc => "The database to use" },
        infile => { type => 'String', doc => "The infile (full report file so far)" },
        outfile => { type => 'String', doc => "The outfile" },
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "This command adds the gene expression information to the report file."
}

sub help_synopsis {
    return <<EOS
genome-model Annotate GetGeneExpression--dev=std_test --infile=~xshi/temp_1/AML_SNP/amll123t92_q1r07t096/TEMP --outfile=base_file_name
EOS
}

sub help_detail {
    return <<EOS
This command adds the gene expression information to the report file.
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
=pod
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

=cut
    my $gene_hash;

#MPSampleData::DBI::myinit("dbi:Oracle:dwdev","mguser_dev"); #dev
    #MPSampleData::DBI::myinit("dbi:Oracle:dwrac","mguser_prd"); #prod
    
	#to connect:
	my $db_name = 'mg_prod';
	MPSampleData::DBI->connect($db_name); # mg_dev, mg_prod, sd_test, sample_data; stored in
	#Get the dbh:
	my $dbh = MPSampleData::DBI->db_Main; 

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
        
        # Replaced the gene exp query w/ class relationships
        #$gene_hash->{$gene} = MG::Analysis::VariantAnnotation->get_gene_expression( $sth, $gene ) unless ( defined $gene_hash->{$gene} );
        $gene_hash->{$gene} = $self->_get_gene_expression($gene) unless exists $gene_hash->{$gene};

        #check whether submitted or not
        my $submit;
        if ( exists $submitted->{"$chromosome,$start,$end"} && $submitted->{"$chromosome,$start,$end"} == 1 ) {
            $submit = 1;
        }
        else { 
			$submit = 0; 
		}

        print "\n\n# ".scalar(split(/,/, $line))," #\n\n";
        # print Dumper($line) unless defined $rgg_id;
        print OUT
"$dbsnp,$gene,$chromosome,$start,$end,$al1,$al1_read1,$al1_read2,$al2,$al2_read1,$al2_read2,",
          $gene_hash->{$gene}->{exp}, ",", $gene_hash->{$gene}->{det},
",$transcript,$strand,$trv_type,$c_position,$pro_str,$pph_prediction,$submit,$rgg_id\n";
    }

    print "final finished!\n";

    close(IN);
    close(OUT);

    #subroutine

    # FIXME This sub is not used...
    # check if submitted or -+20bp
    sub check_submitted {
        my %options;
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
    return 0;
}

sub _get_gene_expression
{
    my ($self, $name) = @_;
    
    my $gene_expression;
    if ( my ($gene) = MPSampleData::Gene->search(hugo_gene_name => $name) )
    {
        $gene_expression = $gene->expressions->first;
    }
    else 
    {
        my ($eig) = MPSampleData::ExternalGeneId->search(id_value => $name);
        die "can't find $name\n" unless $eig;
        $gene_expression = $eig->gene_id->expressions->first;
    }

    return ( $gene_expression )
    ? { 'exp' => $gene_expression->expression_intensity, det => $gene_expression->detection }
    : { 'exp' => 'NULL', det => 'NULL' };
}

1;

