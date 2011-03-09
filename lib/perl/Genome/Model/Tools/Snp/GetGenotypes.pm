package Genome::Model::Tools::Snp::GetGenotypes;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# GetGenotypes - Given a list of samples, output genotype files and optionally the cn file
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	02/28/2011 by W.S.
#	MODIFIED:	02/28/2011 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;
use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

## Declare global statistics hash ##

my %stats = ();

class Genome::Model::Tools::Snp::GetGenotypes {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		sample_list	=> { is => 'Text', doc => "List of samples as input" , is_optional => 0},
		data_directory	=> { is => 'Text', doc => "Output data directory" , is_optional => 0},
		reference	=> { is => 'Text', doc => "reference (build36) or GRCh37 (build37)" , is_optional => 0, default => 'GRCh37'},
		dbsnp_build	=> { is => 'Text', doc => "130 or 132" , is_optional => 0, default => '132'},
		data_source	=> { is => 'Text', doc => "iscan or external" , is_optional => 0, default => 'iscan'},
		cn_file		=> { is => 'Text', doc => "Do you also want to print out a cn file?" , is_optional => 1, default => 0},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Given a list of samples, output genotype files and optionally the cn file"                 
}

sub help_synopsis {
    return <<EOS
Given a list of samples, output genotype files and optionally the cn file
EXAMPLE:	gmt snp get-genotypes
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 

EOS
}



################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.
	my $self = shift;

	my $sample_list = $self->sample_list;
	my $data_directory = $self->data_directory;
	my $reference = $self->reference;
	my $db_snp_build = $self->dbsnp_build;
	my $cn_file = $self->cn_file;

	my $db_snp_info = GSC::SNP::DB::Info->get( snp_db_build => $db_snp_build );

	my $input = new FileHandle ($sample_list);

	while (<$input>) {
		chomp;
		my $line = $_;
		my $sample = $line;

		# Get the sample
		my $organism_sample = GSC::Organism::Sample->get( sample_name => $sample );
	 
		if($organism_sample) {
			print "Exporting for $sample\n";
			
			# Get all external genotypes for this sample
			if ($self->data_source eq 'iscan') {
				foreach my $genotype ( $organism_sample->get_genotype ) {
					#LSF: For Affymetrix, this will be the birdseed file.
					my $ab_file = $genotype->get_genotype_file_ab;
					
					# Get the data adapter (DataAdapter::GSGMFinalReport class object)
					my $filter       = DataAdapter::Result::Filter::Nathan->new();
					my $data_adapter = $genotype->get_genotype_data_adapter(
						genome_build => $db_snp_info->genome_build,
						snp_db_build => $db_snp_info->snp_db_build,
						filter       => $filter,
						( $reference ? ( type => $reference ) : () ),
					);
					
					# Next if there is no genotype data.
					next unless($data_adapter);
			
					## Open the output file ##
					my $outfile = "$data_directory/$sample.genotypes";
					open(OUTFILE, ">$outfile") or die "Can't open output file: $!\n";
				
					my $cn_outfile;
					if ($self->cn_file) {
						$cn_outfile = "$data_directory/$sample.cn";
						open(OUTFILE2, ">$cn_outfile") or die "Can't open output file: $!\n";
					}
					# Loop through the result row (DataAdapter::Result::GSGMFinalReport class object)
					while ( my $result = $data_adapter->next_result )
					{
						print OUTFILE join "\t", ( $result->chromosome, $result->position, $result->alleles );
						#$result->snp_name
						print OUTFILE "\n";
						if ($self->cn_file) {
							print OUTFILE2 join "\t", ( $result->chromosome, $result->position, $result->log_r_ratio );
						}
					}
					close(OUTFILE);
					if ($self->cn_file) {
						close(OUTFILE2);
					}
				}
			}
			elsif ($self->data_source eq 'external') {
				foreach my $genotype ( $organism_sample->get_external_genotype ) {
					#LSF: For Affymetrix, this will be the birdseed file.
					my $ab_file = $genotype->get_genotype_file_ab;
					
					# Get the data adapter (DataAdapter::GSGMFinalReport class object)
					my $filter       = DataAdapter::Result::Filter::Nathan->new();
					my $data_adapter = $genotype->get_genotype_data_adapter(
						genome_build => $db_snp_info->genome_build,
						snp_db_build => $db_snp_info->snp_db_build,
						filter       => $filter,
						( $reference ? ( type => $reference ) : () ),
					);
					
					# Next if there is no genotype data.
					next unless($data_adapter);
			
					## Open the output file ##
					my $outfile = "$data_directory/$sample.genotypes";
					open(OUTFILE, ">$outfile") or die "Can't open output file: $!\n";
				
					my $cn_outfile;
					if ($self->cn_file) {
						$cn_outfile = "$data_directory/$sample.cn";
						open(OUTFILE2, ">$cn_outfile") or die "Can't open output file: $!\n";
					}
					# Loop through the result row (DataAdapter::Result::GSGMFinalReport class object)
					while ( my $result = $data_adapter->next_result )
					{
						print OUTFILE join "\t", ( $result->chromosome, $result->position, $result->alleles );
						#$result->snp_name
						print OUTFILE "\n";
						if ($self->cn_file) {
							print OUTFILE2 join "\t", ( $result->chromosome, $result->position, $result->log_r_ratio );
						}
					}
				
					close(OUTFILE);
					if ($self->cn_file) {
						close(OUTFILE2);
					}
				}
			}
		}
		else {
			warn "No genotypes found for sample $sample\n";
		}
	}

	close($input);
}

1;

