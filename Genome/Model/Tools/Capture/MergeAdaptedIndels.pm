
package Genome::Model::Tools::Capture::MergeAdaptedIndels;     # rename this when you give the module file a different name <--

#####################################################################################################################################
# MergeAdaptedIndels - Merge Indel Calls from VarScan and Somatic Sniper
#					
#	AUTHOR:		Will Schierding (wschierd@genome.wustl.edu)
#
#	CREATED:	1/13/2009 by W.S.
#	MODIFIED:	1/13/2009 by W.S.
#
#	NOTES:	
#			
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;                                 # using the namespace authorizes Class::Autouse to lazy-load modules under it

class Genome::Model::Tools::Capture::MergeAdaptedIndels {
	is => 'Command',                       
	
	has => [                                # specify the command's single-value properties (parameters) <--- 
		glfSomaticindels	=> { is => 'Text', doc => "Somatic Sniper Adapted Indel Input File", is_optional => 0, is_input => 1 },
		varScanindels	=> { is => 'Text', doc => "VarScan Adapted Indel Input File", is_optional => 0, is_input => 1 },
		out_file	=> { is => 'Text', doc => "Merged Indel Output File" , is_optional => 0, is_input => 1, is_output => 1},
	],
};

sub sub_command_sort_position { 12 }

sub help_brief {                            # keep this to just a few words <---
    "Merge Indel Calls from VarScan and Somatic Sniper"                 
}

sub help_synopsis {
    return <<EOS
This file was created to merge Indel Calls from VarScan and Somatic Sniper.
This requires inputs of ADAPTED files with chr pos pos ref var as first 5 columns.
EXAMPLE:	gt capture merge-adapted-indels ...
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

	## Get required parameters ##
	my $glfSomaticindels = $self->glfSomaticindels;
	my $varScanindels = $self->varScanindels;
	my $out_file = $self->out_file;

	my $glfinput = new FileHandle ($glfSomaticindels);
	my $varscaninput = new FileHandle ($varScanindels);

unless (open(OUT_FILE,">$out_file")) {
   die "Could not open input file '$out_file' for writing";
  }

my %columns;
my %columns_vs;
while( my $additions = <$varscaninput> ) {
   my ($Chromosome,$Start_position,$End_position,$Reference_Allele,$Tumor_Seq_Allele1,@other) = split(/\t/, $additions);
   my $string = join("\t", @other);
   $string =~ s/\t0\t/\t-\t/g;
   my $merger = "$Chromosome\t$Start_position\t$End_position\t$Reference_Allele\t$Tumor_Seq_Allele1";
   $columns_vs{$merger} = "varscan\t$string";
}

close $varscaninput;

%columns = %columns_vs;

my %columns_glf;
while( my $additions = <$glfinput> ) {
   my ($Chromosome,$Start_position,$End_position,$Reference_Allele,$Tumor_Seq_Allele1,@other) = split(/\t/, $additions);
   my $string = join("\t", @other);
   $string =~ s/\t0\t/\t-\t/g;
   my $merger = "$Chromosome\t$Start_position\t$End_position\t$Reference_Allele\t$Tumor_Seq_Allele1";
   $columns_glf{$merger} = "SomaticSniper\t$string";
   if (exists($columns_vs{$merger})) {
	$columns{$merger} = "$columns_vs{$merger}\t$columns_glf{$merger}";
   }
   else {
	$columns{$merger} = "$columns_glf{$merger}";
   }
}

close $glfinput;

foreach my $keys (sort keys %columns) {
   print OUT_FILE "$keys\t$columns{$keys}";
}	
	return 1;                               # exits 0 for true, exits 1 for false (retval/exit code mapping is overridable)
}


1;

