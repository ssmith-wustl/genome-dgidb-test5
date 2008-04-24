package Genome::Model::Command::Annotate::GetQualityValues;

use strict;
use warnings;
use Carp;
use Data::Dumper;
#use MPSampleData::DBI;
use MG::Analysis::VariantAnnotation;
use FileHandle;
use IO::File;
use MPSampleData::RggInfo;
use Text::CSV_XS;
use above "Genome";

class Genome::Model::Command::Annotate::GetQualityValues {
    is  => 'Command',
    has => [
    #dev    => { type => 'String', doc => "The database to use" },
        infile => { type => 'String', doc => "The infile (full report file so far)" },
        outfile => { type => 'String', doc => "The outfile" },
        dumpfile => { type => 'String', doc => "dump from database" },

    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "This command adds the quality values to the report file."
}

sub help_synopsis {
    return <<EOS
genome-model Annotate GetQualityValues  --infile=~xshi/temp_1/AML_SNP/amll123t92_q1r07t096/TEMP --dumpfile dumpfile --outfile=base_file_name
EOS
}

sub help_detail {
    return <<EOS
This command adds the quality values to the report file.
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


#read in dump file
#grab rgg_id
#query_db and get the quality values
#write out the result

#change to database
#PSampleData::DBI->set_sql(change_db => qq{use sample_data});
#PSampleData::DBI->sql_change_db->execute;

    MPSampleData::RggInfo->columns(Essential => qw{ rgg_id info_type info_value });

    my $file = $self->dumpfile; #really crummy way to get the file name
    my $handle = new FileHandle;
    $handle->open($file, "r") or die "Couldn't open dump file\n";

    my $quality_for =  $self->build_qual_hash($handle);
  
    
    my $end_file = shift;
    my $ef_file = new FileHandle;
    $ef_file->open("$end_file","r") or die "Couldn't open annotation file\n";
    my $header_line = $ef_file->getline; #ignore header
    chomp($header_line);
    my $output_handle = new FileHandle;
    $output_handle->open("$end_file.quals","w") or die "Couldn't open output file\n";

#print new header
    my @header = split q{,}, $header_line;
    push @header, q{"SNP q-value"};
    print $output_handle join(q{,}, @header), "\n";
    my $append_line;
    while($append_line = $ef_file->getline) {
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
              ) = split ",", $append_line;
        my $real_qscore; 
        if( exists($quality_for->{$chromosome}{$start}{$end})) {
            $real_qscore =$quality_for->{$chromosome}{$start}{$end} ;
        }
        else {
            warn "SNP not found\n";
            $real_qscore = "NULL";
        }
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
                         $real_qscore,
                         );
        print $output_handle join(q{,},@fields), "\n";    
        $output_handle->flush;
    }
    return 0;
}

sub build_qual_hash {
    my $self = shift;
    my $fh = shift;
    my %return_hash;
    while(my $line = $fh->getline) {
        chomp($line);
        my
        ($chromosome,$start,$end,
         $allele1,$allele2,$allele1_type,
         $allele2_type,$num_reads1,
         $num_reads2,$rgg_id) = split "\t", $line;
        my @quality_score = MPSampleData::RggInfo->search(
                                                          rgg_id => $rgg_id,
                                                          info_type => 'confidence',
                                                          );
        my $real_qscore; 
        unless(scalar(@quality_score) == 1 && defined($quality_score[0])) {
            warn "Unable to find a single quality score for rgg_id: $rgg_id.\n";
            next;
        }
        if($quality_score[0]->info_value() =~ /^.* reads .*/xs) {
            $real_qscore = "NULL";
        }
        else {
            $real_qscore = $quality_score[0]->info_value;
        }
        $return_hash{$chromosome}{$start}{$end} = $real_qscore;
    }
    return \%return_hash;
}

sub query_rggid {
    my ($self) = @_;
    my $query = qq/select chr.chromosome_name chrom_name,
                          rgg1.start_ beginpos, rgg1.end endpos,
                          rgg1.allele1 allele1, rgg1.allele2 allele2,
                          rgg1.allele1_type type1, rgg1.allele2_type type2,
                          rgg1.num_reads1 num_reads1, 
                          rgg1.num_reads2 num_reads2,
                          rgg1.rgg_id rgg_id
                from  read_group_genotype rgg1 
                join chromosome chr on chr.chrom_id=rgg1.chrom_id
                where chr.chromosome_name = ?
                  and rgg1.start_ = ?
                  and rgg1.end = ?
                  and rgg1.read_group_id=(select rg1.read_group_id
                                            from read_group rg1
                                           where rg1.pp_id=( select pp1.pp_id 
                                                     from process_profile pp1
                     where pp1.concatenated_string_id=?)) /;

    my $dbhandle = MPSampleData::DBI->db_Main();


    return;
}


#sub _get_quality_values
#{
#    my ($self, $name) = @_;
#    
#    my $gene_expression;
#    if ( my ($gene) = MPSampleData::Gene->search(hugo_gene_name => $name) )
#    {
#        $gene_expression = $gene->expressions->first;
#    }
#    else 
#    {
#        my ($eig) = MPSampleData::ExternalGeneId->search(id_value => $name);
#        die "can't find $name\n" unless $eig;
#        $gene_expression = $eig->gene_id->expressions->first;
#    }
#
#    return ( $gene_expression )
#    ? { 'exp' => $gene_expression->expression_intensity, det => $gene_expression->detection }
#    : { 'exp' => 'NULL', det => 'NULL' };
#}



1;

# $Id$
