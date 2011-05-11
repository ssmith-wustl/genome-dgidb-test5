package Genome::Model::Tools::Snp::GetGenotypes;     # rename this when you give the module file a different name

#####################################################################################################################################
# GetGenotypes - Given a list of samples, output genotype files
#
#  AUTHOR:   Will Schierding (wschierd@genome.wustl.edu)
#
#  CREATED:  02/28/2011 by wschierd
#  MODIFIED: 04/20/2011 by ckandoth
#
#  NOTES:
#
#####################################################################################################################################

use strict;
use warnings;

use IO::File;
use Genome;
# GSCApp & App->init cause compile errors and don't appear to be used
#use GSCApp;

class Genome::Model::Tools::Snp::GetGenotypes {
  is => 'Command',

  has => [ # specify the command's single-value properties (parameters)
    sample_list => { is => 'Text', doc => "Input file listing one sample name per line" , is_optional => 0 },
    data_directory => { is => 'Text', doc => "Output directory for genotype files" , is_optional => 0 },
    reference => { is => 'Text', doc => "Reference build: NCBI36 or GRCh37 " , is_optional => 1, default => 'GRCh37' },
    dbsnp_build => { is => 'Text', doc => "dbSNP Version: 130 (for NCBI36) or 132 (for GRCh37)" , is_optional => 1, default => '132' },
    data_source => { is => 'Text', doc => "iscan or external" , is_optional => 1, default => 'iscan' },
  ],
};

sub help_brief { # keep this to just a few words
  "Given a list of samples, output imported genotype files for each"
}

sub help_detail { # this is what the user will see with the longer version of help
  return <<EOS
Given a list of samples, this script queries the database for genotype files for each sample. If
found, genotype files are generated and written to the specified output directory.

Note: The input file sample-list can also be a tab-delimited file with multiple columns, but it is
assumed that the first column contains the sample names to query.
EOS
}

################################################################################################
# Execute - the main program logic
################################################################################################

sub execute {
  my $self = shift;

  unless(App::Init->initialized) {  
    App::DB->db_access_level('rw');
    App->init;
  }
  
  my $sample_list = $self->sample_list;
  my $data_directory = $self->data_directory;
  my $reference = $self->reference;
  my $dbsnp_build = $self->dbsnp_build;
  my $data_source = $self->data_source;

  # Correct the reference build name to what the database recognizes
  $reference = 'reference' if( $reference eq 'NCBI36' );

  # Check arguments for valid values
  ( $reference eq 'reference' or $reference eq 'GRCh37' ) or die "Invalid reference specified!\n";
  ( $dbsnp_build eq '130' or $dbsnp_build eq '132' ) or die "Invalid dbsnp-build specified!\n";
  ( $data_source eq 'iscan' or $data_source eq 'external' ) or die "Invalid data-source specified!\n";

  my $dbsnp_info = GSC::SNP::DB::Info->get( snp_db_build => $dbsnp_build );

  my $inFh = IO::File->new( $sample_list ) or die "Cannot open $sample_list. $!\n";
  while( my $line = $inFh->getline )
  {
    chomp( $line );
    my ( $sample ) = split( /\t/, $line ); # In case the user was kind enough to read the --help

    # Query the sample name in the database
    my $organism_sample = GSC::Organism::Sample->get( sample_name => $sample );

    unless( defined $organism_sample )
    {
      warn "Skipping unrecognized sample name: $sample\n";
      next;
    }

    print "Exporting data for $sample... ";

    # Get all external genotypes for this sample
    my @genotypes;
    if( $data_source eq 'iscan' )
    {
      @genotypes = $organism_sample->get_genotype;
    }
    elsif( $data_source eq 'external' )
    {
      @genotypes = $organism_sample->get_external_genotype;
    }

    my $file_cnt = 0;
    foreach my $genotype ( @genotypes )
    {
      # Get the data adapter (DataAdapter::GSGMFinalReport class object)
      my $filter = DataAdapter::Result::Filter::Nathan->new();
      my $data_adapter = $genotype->get_genotype_data_adapter(
        genome_build => $dbsnp_info->genome_build,
        snp_db_build => $dbsnp_info->snp_db_build,
        filter       => $filter,
        ( $reference ? ( type => $reference ) : () ),
      );

      # Next if there is no genotype data.
      next unless( $data_adapter );

      ++$file_cnt;
      my $genotype_file = "$data_directory/$sample.genotype";
      my $genFh = IO::File->new( ">$genotype_file" ) or die "Cannot open $genotype_file. $!\n";

      # Loop through the result row (DataAdapter::Result::GSGMFinalReport class object)
      while ( my $result = $data_adapter->next_result )
      {
        $genFh->print( join( "\t", ( $result->chromosome, $result->position, $result->alleles )), "\n" );
      }
      $genFh->close;
    }
    print "Done\n" if( $file_cnt == 1 );
    print "No genotypes found\n" if( $file_cnt == 0 );
    print "Multiple genotypes found. Fetched only one.\n" if( $file_cnt > 1 );
  }

  $inFh->close;
}

1;
