package Genome::Model::Tools::QuerryDBSNP128;

use strict;
use warnings;

use above "Genome";                         # >above< ensures this copy is used

class Genome::Model::Tools::QuerryDBSNP128 {
    is => 'Command',                    
    has => [                                # specify the command's properties (parameters) <--- 
        chr     => { type => 'String',      doc => "give the chromosome name ie; 3 7 X" },
        coord     => { type => 'String',      doc => "give the NCBI Build 36 genomic coordinate" },
    ], 
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "provide the chromosome and NCBI Build 36 coordinate and get dbsnp 128 info in return"                 
}

sub help_synopsis {                         # replace the text below with real examples <---
    return <<EOS
genome-model QuerryDBSNP128 --chr=7 --coord=106311925
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

	please provide the chromosome and NCBI Build 36 coordinate 
	for example --chr=7 --coord=106311925
	should result in rs2230460,'C/T',1 
	where the dbsnp is rs2230460 its alleles are C/T and 1 means its validated 
	0 inplace of 1 would indicate that it was not validated.

EOS
}

#sub create {                               # rarely implemented.  Initialize things before execute.  Delete unless you use it. <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

use GSCApp;
my $dw = GSC::Sequence::Item->dbh;
sub execute {                               # replace with real execution logic.
    my $self = shift;
    my $chr = $self->chr;
    my $coord = $self->coord;
    unless ($chr && $coord) { sub help_detail; }

    print "Running QuerryDBSNP128 command:\n";

    #my $dw = GSC::Sequence::Item->dbh;
    my $chrom_id = $dw->prepare(qq/
				select seq_id from sequence_item si
				where sequence_item_type = 'chromosome sequence'
				and sequence_item_name = ?
				/);

    $chrom_id->execute('NCBI-human-build36-chrom' . $chr);
    
    
    my ($seq_id) = $chrom_id->fetchrow_array;
    
#---  statement handles allow you to deal with your results incrementally
    my $variation_exists = $dw->prepare(qq/
					select ref_id,allele_description,is_validated from variation_sequence_tag vs
					join sequence_item si on si.seq_id=vs.vstag_id
					join sequence_tag st on st.stag_id = vs.vstag_id
					join sequence_correspondence scr on scr.scrr_id = vs.vstag_id
					join sequence_collaborator sc on sc.seq_id = vs.vstag_id
					where sc.collaborator_name = 'dbSNP'
					and sc.role_detail = '128'
					and seq2_start = ?
					and seq2_id = ? 
					/);
    
#$variation_exists->execute($your_coord, $seq_id_from_above);
    $variation_exists->execute($coord, $seq_id);
    
    my ($rs_id,$allele_description,$is_validated) = $variation_exists->fetchrow_array;
    
    if ($rs_id) {
	print qq($rs_id,$allele_description,$is_validated\n);
    } else {
	print qq(no dbSNP-128 found on NCBI-human-build36-chrom $chr at $coord\n);
    }
    

    return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}

1;

