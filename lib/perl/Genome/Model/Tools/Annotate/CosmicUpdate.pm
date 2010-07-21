package Genome::Model::Tools::Annotate::CosmicUpdate;

########################################################################################################################
# CosmicUpdate.pm - A module for updating the local COSMIC database to reflect the current COSMIC database.
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	3/09/2010 by W.S.
#	MODIFIED:	3/09/2010 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

   use warnings;
   use strict;
   use Net::FTP;
   use Cwd;
   use Getopt::Long;

class Genome::Model::Tools::Annotate::CosmicUpdate {

	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		cosmic_folder	=> { is => 'Text', doc => "Path to the current local COSMIC files", is_optional => 1 , default => '/gscmnt/sata180/info/medseq/biodb/shared/cosmic/cosmic_will/' },
		cosmic_url	=> { is => 'Text', doc => "URL to the online COSMIC repository", is_optional => 1 , default => 'ftp://ftp.sanger.ac.uk/pub/CGP/cosmic/data_export/genes/' },
		output_file	=> { is => 'Text', doc => "Output file name for flatfile of amino acid changes" , is_optional => 1 , default => 'Cosmic_Database.tsv' },
	],
};

sub help_brief {                            # keep this to just a few words <---
    "Update Local COSMIC database"
}

sub help_synopsis {
    return <<EOS
A module for updating the downloaded COSMIC database to reflect the current COSMIC database.
EXAMPLE:	gmt annotate cosmic-update ...
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
A module for updating the downloaded COSMIC database to reflect the current COSMIC database.
EOS
}


################################################################################################
# Execute - the main program logic
#
################################################################################################

sub execute {                               # replace with real execution logic.

my $self = shift;
my $URL = $self->cosmic_url;
my $cosmicdir = $self->cosmic_folder;
my $cosmicdb = $self->output_file;

chdir ($cosmicdir);
my $dir = getcwd;
print "Working Directory: $dir";

print "Retrieving File(s) from COSMIC\n";

#directory on COSMIC server with all GENE folders
system ( wget, "\-r" , "\-A.csv" , "\-nd" , "\-N" , "\-l2" , $URL);

print "Finished Downloading COSMIC File(s), Moving on to Writing COSMIC Flatfile\n";

opendir(IMD, $cosmicdir) || die("Cannot open directory"); 

my @cosmicdirfiles= readdir(IMD);
closedir(IMD);
my @cosmiccsvfiles;

foreach my $file (@cosmicdirfiles) {
  unless ( ($file eq ".") || ($file eq "..") ) {
    if ( $file =~ m/.csv/ ) {
       push (@cosmiccsvfiles,$file);
    }
  }
}


unless (open(COSMIC_DB,">$cosmicdb")) {
    die "Could not open output file '$cosmicdb' for writing";
}
print COSMIC_DB "Gene\tChromosome\tGenome Start\tGenome Stop\tAmino Acid\tNucleotide\tSomatic Status\n";
my $i = 0;
foreach my $genefile (@cosmiccsvfiles) {
	print ".";
	my $gene = $genefile;
	$gene =~ s/.csv//g;
	chomp ($gene);
	unless (open(GENE_FILE,"<$genefile")) {
	    die "Could not open output file '$genefile' for writing";
	}
	my $firstline = 0;
	my $chr_col;
	my $start_col;
	my $stop_col;
	my $amino_col;
	my $nucleo_col;
	my $somatic_col;
	my $chr;
	my $start;
	my $stop;
	my $amino;
	my $nucleo;
	my $somatic;
	while (my $line = <GENE_FILE>) {
		if ($line =~ m/(Amino Acid)/ ) {
			$firstline = 1;
			my @parser = split(/\t/, $line);
			my $parsecount = 0;
			my %parsehash;
			foreach my $item (@parser) {
				$parsehash{$item} = $parsecount;
				$parsecount++;
			}
			$chr_col = $parsehash{'Chromosome'};
			$start_col = $parsehash{'Genome Start'};
			$stop_col = $parsehash{'Genome Stop'};
			$amino_col = $parsehash{'Amino Acid'};
			$nucleo_col = $parsehash{'Nucleotide'};
			$somatic_col = $parsehash{'Somatic Status'};
			unless (defined($chr_col) && defined($start_col) && defined($stop_col) && defined($amino_col) && defined($nucleo_col) && defined($somatic_col)) {
			    die "Line: $line\nAbove line could not be parsed for gene: $gene";
			}
			next;
		}
		unless ($firstline == 1) {
			next;
		}
		my @parser = split(/\t/, $line);
		chomp($parser[$chr_col],$parser[$start_col],$parser[$stop_col],$parser[$amino_col],$parser[$nucleo_col],$parser[$somatic_col]);
		unless ($parser[$chr_col] ne ' ' || $parser[$start_col] ne ' ' || $parser[$stop_col] ne ' ' || $parser[$amino_col] ne ' ' || $parser[$nucleo_col] ne ' ' || $parser[$somatic_col] ne ' ') {
		    next;
		}
		$chr = $parser[$chr_col];
		$start = $parser[$start_col];
		$stop = $parser[$stop_col];
		$amino = $parser[$amino_col];
		$nucleo = $parser[$nucleo_col];
		$somatic = $parser[$somatic_col];
		chomp($chr,$start,$stop,$amino,$nucleo,$somatic);
		print COSMIC_DB "$gene\t$chr\t$start\t$stop\t$amino\t$nucleo\t$somatic\n";
	}
}


	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}
