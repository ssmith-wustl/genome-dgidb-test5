#!/gsc/bin/perl

use strict;
use warnings;

use FileHandle;
use MPSampleData::DBI;
use MPSampleData::Chromosome;
use Text::CSV_XS;
#read in the annotated file
#find Watson or Venter dbSNP status

MPSampleData::DBI::myinit("dbi:Oracle:dwrac","mguser_prd");

MPSampleData::Chromosome->columns(Essential => qw{ chrom_id chromosome_name });

#Set up a chromosome look-up table
my %chromosome_id_for;

my @db_chromosomes = MPSampleData::Chromosome->retrieve_all;
for my $chromosome (@db_chromosomes) {
    $chromosome_id_for{$chromosome->chromosome_name} = $chromosome->chrom_id;
}

my $file = shift; #really crummy way to get the file name
my $handle = new FileHandle;
$handle->open($file, "r") or die "Couldn't open annotation file\n";

my $header_line = $handle->getline; #ignore header
chomp($header_line);
my $output_handle = new FileHandle;
$output_handle->open("$file.worv","w") or die "Couldn't open output file\n";

my $cin = new Text::CSV_XS;
my $cout = new Text::CSV_XS;
#print new header
$cin->parse($header_line);
my @header = $cin->fields();
#my @header = split q{,}, $header_line;
push @header, qq{Watson or Venter(0:no, Name:source(s))};
#print $output_handle join(q{,}, @header), "\n";
$cout->combine(@header);
print $output_handle $cout->string(), "\n";
my $append_line;
while($append_line = $handle->getline) {
    chomp $append_line;
    my (  $dbsnp,
          $gene,
          $chromosome,
          $start,
          $end,
          $al2,
          $al2_read_hg,
          $al2_read_cDNA,
          $al2_read_skin_dna,
          $al2_read_unique_dna_start,
          $al2_read_unique_dna_context,
          $al2_read_unique_cDNA_start,
          $al2_read_unique_cDNA_context,
          $al2_read_unique_skin_start,
          $al2_read_unique_skin_context,
          $al2_read_relapse_cDNA,
          $al1,
          $al1_read_hg,
          $al1_read_cDNA,
          $al1_read_skin_dna,
          $al1_read_unique_dna_start,
          $al1_read_unique_dna_context,
          $al1_read_unique_cDNA_start,
          $al1_read_unique_cDNA_context,
          $al1_read_unique_skin_start,
          $al1_read_unique_skin_context,
          $al1_read_relapse_cDNA,
          $gene_exp,
          $gene_det,
          $transcript,
          $strand,
          $trv_type,
          $c_position,
          $pro_str,
          $pph_prediction,
          $submit,
          $q_value,
       ) = split ",", $append_line;


    my $watson_or_venter = check_VorWsnp({
        type        => "SNP",
        chrom  => $chromosome_id_for{$chromosome},
        start       => "$start",
        end         =>  "$end",
        filter      =>  1,
    });

    my @fields = (   $dbsnp,
        $gene,
        $chromosome,
        $start,
        $end,
        $al2,
        $al2_read_hg,
        $al2_read_cDNA,
        $al2_read_skin_dna,
        $al2_read_unique_dna_start,
        $al2_read_unique_dna_context,
        $al2_read_unique_cDNA_start,
        $al2_read_unique_cDNA_context,
        $al2_read_unique_skin_start,
        $al2_read_unique_skin_context,
        $al2_read_relapse_cDNA,
        $al1,
        $al1_read_hg,
        $al1_read_cDNA,
        $al1_read_skin_dna,
        $al1_read_unique_dna_start,
        $al1_read_unique_dna_context,
        $al1_read_unique_cDNA_start,
        $al1_read_unique_cDNA_context,
        $al1_read_unique_skin_start,
        $al1_read_unique_skin_context,
        $al1_read_relapse_cDNA,
        $gene_exp,
        $gene_det,
        $transcript,
        $strand,
        $trv_type,
        $c_position,
        $pro_str,
        $pph_prediction,
        $submit,
        $q_value,
        $watson_or_venter,

    );
    
    print $output_handle join(q{,},@fields), "\n";    
    $output_handle->flush;
}



sub check_VorWsnp {
    #CHECK AGAINST SNPS FOUND IN THE Venter and Watson Genomes
    #select * from variation v, variation_instance vi, submitter s where
    #v.variation_id=vi.variation_id and vi.submitter_id=s.submitter_id and
    #(s.submitter_name='VENTER' or s.submitter_name='WATSON') and chrom_id=1
    #and start=231 and end=231 
	my ($self,$offset)=@_;
	$offset=10 unless(defined $offset);
    
    my $sql;
    if($self->{type} eq 'SNP') {
        $sql = <<EOS
select distinct s.submitter_name 
from variation v, variation_instance vi, submitter s
where v.variation_id=vi.variation_id and vi.submitter_id=s.submitter_id 
and (s.submitter_name='VENTER' or s.submitter_name='WATSON')
and chrom_id=? and start_=? and end=?
EOS
;    
    }
    else {
        $sql = <<EOS
select distinct s.submitter_name 
from variation v, variation_instance vi, submitter s
where v.variation_id=vi.variation_id and vi.submitter_id=s.submitter_id 
and (s.submitter_name='VENTER' or s.submitter_name='WATSON')
and chrom_id=? and start_<=? and start_>=? and end<=? and end>=? 
and v.allele_string like '%-%' 
EOS
;    
    } 
    
    my $X = MPSampleData::DBI->db_Main;
    my $sth;
    ($sth) = $X->prepare($sql);
    if($self->{type} eq 'SNP') {
        $sth->execute($self->{chrom},$self->{start},$self->{end});
    }
    else {
        $sth->execute( $self->{chrom},
                                $self->{start}+$offset,
                                $self->{start}-$offset,
                                $self->{end}+$offset,
                                $self->{end}-$offset,
                            );
    }
    my @submitters = @{$sth->fetchall_arrayref([0])};

	if(scalar(@submitters) > 0) {
        unless(scalar(@submitters) == 1) {
            my $return = '';
            foreach my $submitter_array (@submitters) {
                if($return ne '') {
                    $return .= '/';
                }
                $return .= $submitter_array->[0];
            }
            return $return;
        }
        else {
            return $submitters[0][0];
        }
    }
    else {
	    return 0;
    }
}
